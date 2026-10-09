//
//  MapSocialProximityController.swift
//  wander
//

import CoreLocation
import MapboxMaps
import UIKit

/// Owns the native lifecycle of social groups, including temporary member focus.
/// Mapbox callbacks return here so rendering never becomes a second source of truth.
@MainActor
final class MapSocialProximityController {
    private let annotationStore: MapAnnotationStore
    private let presentation: (MapSocialProximityGroupAnnotation) -> MapSocialClusterPresentation
    private let setFocusAppearance: (Bool, MapAnnotationView) -> Void
    private let onDeselectMember: (MapSocialClusterMemberID) -> Void
    private let visibleBounds: @MainActor (MapboxMaps.MapView) -> CGRect
    private let onRequestOwnProfile: (() -> Void)?
    private let onRequestFriendProfile: ((String) -> Void)?
    private var state = MapSocialProximityState()
    private var sources: [MapSocialClusterMemberID: MapAnnotation] = [:]
    private var memberIDsByAnnotation: [ObjectIdentifier: MapSocialClusterMemberID] = [:]
    private var groupsByID: [String: MapSocialProximityGroupAnnotation] = [:]
    private var managedAnnotations: [ObjectIdentifier: MapAnnotation] = [:]
    private var lastAppliedRevision: Int?
    private var expandedGroupID: String?
    private weak var expandedView: MapSocialClusterAnnotationView?
    private var pendingSelection: MapSocialClusterMemberID?
    private var pendingSelectionIsSilent = false
    private var selectionGeneration = 0
    private var scheduledSelectionGeneration: Int?
    private var isFittingExpandedGroup = false

    init(
        annotationStore: MapAnnotationStore,
        presentation: @escaping (MapSocialProximityGroupAnnotation) -> MapSocialClusterPresentation,
        setFocusAppearance: @escaping (Bool, MapAnnotationView) -> Void,
        onDeselectMember: @escaping (MapSocialClusterMemberID) -> Void = { _ in },
        onRequestOwnProfile: (() -> Void)? = nil,
        onRequestFriendProfile: ((String) -> Void)? = nil,
        visibleBounds: @escaping @MainActor (MapboxMaps.MapView) -> CGRect = {
            $0.bounds.inset(by: $0.safeAreaInsets)
        }
    ) {
        self.annotationStore = annotationStore
        self.presentation = presentation
        self.setFocusAppearance = setFocusAppearance
        self.onDeselectMember = onDeselectMember
        self.visibleBounds = visibleBounds
        self.onRequestOwnProfile = onRequestOwnProfile
        self.onRequestFriendProfile = onRequestFriendProfile
    }

    // Avoid synthesized isolated deinit on older Swift runtimes (swiftlang/swift#88036).
    // Native cleanup is performed explicitly by tearDown on the main actor.
    nonisolated deinit {}

    // MARK: - Sources and rendering

    func update(
        sources nextSources: [MapSocialClusterMemberID: MapAnnotation],
        on mapView: MapboxMaps.MapView
    ) {
        let previousFocus = focusedAnnotation
        let previousMemberID = state.focusedMemberID
        let nextObjectIDs = nextSources.mapValues { ObjectIdentifier($0) }
        let previousObjectIDs = sources.mapValues { ObjectIdentifier($0) }
        sources = nextSources
        memberIDsByAnnotation = Dictionary(uniqueKeysWithValues: sources.map {
            (ObjectIdentifier($0.value), $0.key)
        })
        state.update(sources: sources.map {
            MapSocialProximityState.Source(id: $0.key, coordinate: $0.value.coordinate)
        })
        if let pendingSelection, sources[pendingSelection] == nil {
            self.pendingSelection = nil
            selectionGeneration &+= 1
        }
        if let previousFocus, !isFocused(previousFocus) {
            selectionGeneration &+= 1
            pendingSelection = state.focusedMemberID
            if let view = annotationStore.view(for: previousFocus) {
                setFocusAppearance(false, view)
            }
            annotationStore.deselectAnnotation(previousFocus, animated: false)
        }
        if let previousMemberID, previousMemberID != state.focusedMemberID {
            onDeselectMember(previousMemberID)
        }
        if previousObjectIDs != nextObjectIDs {
            lastAppliedRevision = nil
        }
        synchronize()
        refreshViews(on: mapView)
        viewportDidChange(on: mapView)
        selectPendingAnnotationIfVisible(on: mapView)
    }

    func isFocused(_ annotation: MapAnnotation) -> Bool {
        guard let focusedAnnotation else { return false }
        return focusedAnnotation === annotation
    }

    var hasActivePresentation: Bool {
        state.focusedMemberID != nil || pendingSelection != nil || expandedGroupID != nil
    }

    /// Invalidates queued presentation work after a selection or teardown.
    var presentationRevision: Int { selectionGeneration }

    private var focusedAnnotation: (MapAnnotation)? {
        state.focusedMemberID.flatMap { sources[$0] }
    }

    private func memberID(for annotation: MapAnnotation) -> MapSocialClusterMemberID? {
        memberIDsByAnnotation[ObjectIdentifier(annotation)]
    }

    private func synchronize() {
        guard lastAppliedRevision != state.revision else { return }
        // Publish ownership before adding views can synchronously trigger selection.
        lastAppliedRevision = state.revision
        var desired: [MapAnnotation] = []
        var nextGroups: [String: MapSocialProximityGroupAnnotation] = [:]
        for group in state.groups {
            let members = group.memberIDs.compactMap { sources[$0] }
            guard members.count > 1 else {
                desired.append(contentsOf: members)
                continue
            }
            let annotation: MapSocialProximityGroupAnnotation
            if let existing = groupsByID[group.id] {
                existing.update(memberAnnotations: members)
                annotation = existing
            } else {
                annotation = MapSocialProximityGroupAnnotation(
                    identifier: group.id,
                    memberAnnotations: members
                )
            }
            nextGroups[group.id] = annotation
            desired.append(annotation)
        }
        if let focusedAnnotation {
            desired.append(focusedAnnotation)
        }
        let desiredByID = Dictionary(uniqueKeysWithValues: desired.map {
            (ObjectIdentifier($0), $0)
        })
        let removed = managedAnnotations.filter { desiredByID[$0.key] == nil }.map(\.value)
        groupsByID = nextGroups
        managedAnnotations = desiredByID
        if !removed.isEmpty {
            annotationStore.removeAnnotations(removed)
        }
        let attachedIDs = Set(annotationStore.annotations.map { ObjectIdentifier($0) })
        let added = desired.filter { !attachedIDs.contains(ObjectIdentifier($0)) }
        if !added.isEmpty {
            annotationStore.addAnnotations(added)
        }
        annotationStore.synchronizeCoordinates()
    }

    func refreshViews(on mapView: MapboxMaps.MapView) {
        for annotation in sources.values {
            if let view = annotationStore.view(for: annotation) {
                view.isAccessibilityElement = true
                setFocusAppearance(isFocused(annotation), view)
            }
        }
        if let expandedGroupID, groupsByID[expandedGroupID] == nil {
            collapseExpandedGroup(on: mapView, animated: false)
        }
        for group in groupsByID.values {
            guard let view = annotationStore.view(for: group) as? MapSocialClusterAnnotationView else {
                continue
            }
            configure(view, for: group, on: mapView)
        }
    }

    func configure(
        _ view: MapSocialClusterAnnotationView,
        for group: MapSocialProximityGroupAnnotation,
        on mapView: MapboxMaps.MapView
    ) {
        if let bounds = expandedGroupBounds(on: mapView) {
            view.setExpandedViewportSize(bounds.size)
        }
        view.configure(with: presentation(group))
        view.onSelectMember = { [weak self, weak mapView, weak group] memberID in
            guard let self, let mapView, let group else { return }
            guard group.memberAnnotations.contains(where: { self.memberID(for: $0) == memberID }) else {
                self.collapseExpandedGroup(on: mapView, animated: true)
                return
            }
            self.collapseExpandedGroup(on: mapView, animated: true)
            self.center(on: memberID, on: mapView)
        }
        view.onExpandedSizeChange = { [weak self, weak mapView] in
            guard let self, let mapView else { return }
            self.viewportDidChange(on: mapView)
        }
        view.setExpanded(expandedGroupID == group.identifier, animated: false)
        if expandedGroupID == group.identifier {
            expandedView = view
        }
    }

    // MARK: - Selection lifecycle

    /// Used by both the passive tap observer and native / accessible selection.
    /// The returned member routes the product action; groups are handled internally.
    @discardableResult
    func activate(
        _ annotation: MapAnnotation,
        view: MapAnnotationView,
        on mapView: MapboxMaps.MapView
    ) -> MapSocialClusterMemberID? {
        guard managedAnnotations[ObjectIdentifier(annotation)] != nil,
              annotationStore.view(for: annotation) === view else { return nil }
        if let group = annotation as? MapSocialProximityGroupAnnotation {
            expand(group, on: mapView)
            return nil
        }
        guard let memberID = memberID(for: annotation),
              CLLocationCoordinate2DIsValid(annotation.coordinate) else { return nil }
        if pendingSelection == memberID {
            pendingSelection = nil
        }
        let shouldRecenter = !isFocused(annotation)
        if shouldRecenter {
            selectionGeneration &+= 1
            pendingSelection = nil
            changeFocus(to: memberID, on: mapView)
        }
        mapView.viewport.idle()
        let usesProfileCamera: Bool
        switch memberID {
        case .friend: usesProfileCamera = onRequestFriendProfile != nil
        case .currentUser: usesProfileCamera = onRequestOwnProfile != nil
        case .outing: usesProfileCamera = false
        }
        if shouldRecenter && !usesProfileCamera {
            moveCamera(CameraOptions(center: annotation.coordinate), on: mapView)
        }
        return memberID
    }

    func didDeselect(_ annotation: MapAnnotation, on mapView: MapboxMaps.MapView) {
        let generation = selectionGeneration
        // Selection can deselect A just before selecting B. Let that handoff finish
        // before restoring a group that would remove B's visible annotation.
        DispatchQueue.main.async { [weak self, weak mapView] in
            guard let self, let mapView,
                  self.selectionGeneration == generation,
                  !self.isSelected(annotation) else { return }
            if let group = annotation as? MapSocialProximityGroupAnnotation {
                guard self.groupsByID[group.identifier] === group,
                      self.expandedGroupID == group.identifier else { return }
                self.collapseExpandedGroup(on: mapView, animated: true)
            } else if self.isFocused(annotation), self.pendingSelection == nil {
                self.changeFocus(to: nil, on: mapView)
            }
        }
    }

    func isSilentPendingSelection(_ annotation: MapAnnotation) -> Bool {
        guard let memberID = memberID(for: annotation) else { return false }
        return pendingSelection == memberID && pendingSelectionIsSilent
    }

    func select(_ memberID: MapSocialClusterMemberID, on mapView: MapboxMaps.MapView, silently: Bool = false) {
        guard let annotation = sources[memberID],
              CLLocationCoordinate2DIsValid(annotation.coordinate) else { return }
        if isFocused(annotation), isSelected(annotation) {
            return
        }
        pendingSelectionIsSilent = silently
        if pendingSelection == memberID {
            selectPendingAnnotationIfVisible(on: mapView)
            return
        }
        selectionGeneration &+= 1
        pendingSelection = memberID
        selectPendingAnnotationIfVisible(on: mapView)
    }

    func center(on memberID: MapSocialClusterMemberID, on mapView: MapboxMaps.MapView) {
        guard let annotation = sources[memberID],
              CLLocationCoordinate2DIsValid(annotation.coordinate) else { return }
        mapView.viewport.idle()
        select(memberID, on: mapView)
        if case .currentUser = memberID, let onRequestOwnProfile {
            onRequestOwnProfile()
            return
        }
        if case .friend(let userID) = memberID, let onRequestFriendProfile {
            // Open even when the annotation is offscreen; its camera request will
            // make it visible. Waiting for didSelect would create a dependency loop.
            onRequestFriendProfile(userID)
            return
        }
        moveCamera(
            MapUserCameraController.focusedCamera(at: annotation.coordinate, on: mapView),
            on: mapView
        )
    }

    private func moveCamera(_ camera: CameraOptions, on mapView: MapboxMaps.MapView) {
        if UIAccessibility.isReduceMotionEnabled {
            mapView.mapboxMap.setCamera(to: camera)
        } else {
            mapView.camera.ease(to: camera, duration: 0.3)
        }
    }

    func collapse(on mapView: MapboxMaps.MapView) {
        selectionGeneration &+= 1
        pendingSelection = nil
        scheduledSelectionGeneration = nil
        collapseExpandedGroup(on: mapView, animated: false)
        changeFocus(to: nil, on: mapView)
    }

    private func changeFocus(to memberID: MapSocialClusterMemberID?, on mapView: MapboxMaps.MapView) {
        if memberID != nil {
            collapseExpandedGroup(on: mapView, animated: false)
        }
        let previousMemberID = state.focusedMemberID
        let previousAnnotation = focusedAnnotation
        guard state.focus(memberID) else { return }
        // Publish the final focus before removal delivers deselection callbacks.
        // Rebuilding an intermediate unfocused group would detach the next member.
        if let previousAnnotation {
            if let view = annotationStore.view(for: previousAnnotation) {
                setFocusAppearance(false, view)
            }
            annotationStore.deselectAnnotation(previousAnnotation, animated: false)
        }
        synchronize()
        if let focusedAnnotation, let view = annotationStore.view(for: focusedAnnotation) {
            setFocusAppearance(true, view)
        }
        if let previousMemberID {
            onDeselectMember(previousMemberID)
        }
    }

    private func isSelected(_ annotation: MapAnnotation) -> Bool {
        annotationStore.selectedAnnotations.contains { ($0) === (annotation) }
    }

    private func selectPendingAnnotationIfVisible(on mapView: MapboxMaps.MapView) {
        guard let memberID = pendingSelection else { return }
        guard let annotation = sources[memberID],
              CLLocationCoordinate2DIsValid(annotation.coordinate) else {
            pendingSelection = nil
            return
        }
        if !isFocused(annotation) {
            changeFocus(to: memberID, on: mapView)
            // didAdd can consume this selection synchronously. A singleton may
            // already have a view and produce no didAdd callback at all.
            guard pendingSelection == memberID else { return }
        }
        guard annotationStore.view(for: annotation) != nil else { return }
        let generation = selectionGeneration
        guard scheduledSelectionGeneration != generation else { return }
        scheduledSelectionGeneration = generation
        DispatchQueue.main.async { [weak self, weak mapView] in
            guard let self, mapView != nil,
                  self.selectionGeneration == generation,
                  self.pendingSelection == memberID,
                  self.isFocused(annotation) else { return }
            self.scheduledSelectionGeneration = nil
            if self.isSelected(annotation) {
                self.pendingSelection = nil
                return
            }
            self.annotationStore.selectAnnotation(annotation, animated: true)
        }
    }

    private func expand(_ group: MapSocialProximityGroupAnnotation, on mapView: MapboxMaps.MapView) {
        guard groupsByID[group.identifier] === group,
              group.memberAnnotations.count > 1 else { return }
        guard expandedGroupID != group.identifier else { return }
        selectionGeneration &+= 1
        pendingSelection = nil
        scheduledSelectionGeneration = nil
        collapseExpandedGroup(on: mapView, animated: false)
        changeFocus(to: nil, on: mapView)
        // Restoring a focused member can change the group's native representative.
        guard let group = groupsByID[group.identifier],
              let view = annotationStore.view(for: group) as? MapSocialClusterAnnotationView else { return }
        configure(view, for: group, on: mapView)
        expandedGroupID = group.identifier
        expandedView = view
        view.setExpanded(true, animated: true)
        viewportDidChange(on: mapView)
    }

    /// A clipping-window change does not emit Mapbox camera callbacks.
    /// Keep the existing group and selection while exposing its list and anchor.
    func viewportDidChange(on mapView: MapboxMaps.MapView) {
        guard !isFittingExpandedGroup,
              let groupID = expandedGroupID,
              let group = groupsByID[groupID],
              let view = expandedView,
              let annotation = view.annotation,
              (annotation) === group,
              view.isExpanded,
              let bounds = expandedGroupBounds(on: mapView) else { return }
        isFittingExpandedGroup = true
        defer { isFittingExpandedGroup = false }

        view.setExpandedViewportSize(bounds.size)
        let anchor = mapView.mapboxMap.point(for: group.coordinate)
        guard anchor.x.isFinite, anchor.y.isFinite else { return }
        let listFrame = view.projectedExpandedFrame(at: anchor)
        let frame = CGRect(
            x: listFrame.minX,
            y: listFrame.minY,
            width: listFrame.width,
            height: max(anchor.y, listFrame.maxY) - listFrame.minY
        )
        let translation = CGPoint(
            x: max(0, bounds.minX - frame.minX) + min(0, bounds.maxX - frame.maxX),
            y: max(0, bounds.minY - frame.minY) + min(0, bounds.maxY - frame.maxY)
        )
        guard abs(translation.x) > 0.5 || abs(translation.y) > 0.5 else { return }

        let projectedCenter = mapView.mapboxMap.point(for: mapView.mapboxMap.cameraState.center)
        guard projectedCenter.x.isFinite, projectedCenter.y.isFinite else { return }
        let center = mapView.mapboxMap.coordinate(for: CGPoint(
            x: projectedCenter.x - translation.x,
            y: projectedCenter.y - translation.y
        ))
        guard CLLocationCoordinate2DIsValid(center) else { return }
        // A viewport drag can call this every frame. Do not queue camera animations.
        mapView.mapboxMap.setCamera(to: CameraOptions(center: center))
    }

    private func expandedGroupBounds(on mapView: MapboxMaps.MapView) -> CGRect? {
        let bounds = visibleBounds(mapView)
        guard bounds.minX.isFinite, bounds.minY.isFinite,
              bounds.width.isFinite, bounds.height.isFinite,
              bounds.width > 24, bounds.height > 32 else { return nil }
        return bounds.insetBy(dx: 12, dy: 12)
    }

    private func collapseExpandedGroup(on mapView: MapboxMaps.MapView, animated: Bool) {
        guard expandedGroupID != nil || expandedView != nil else { return }
        let group = expandedView?.annotation as? MapSocialProximityGroupAnnotation
        let view = expandedView
        expandedGroupID = nil
        expandedView = nil
        view?.setExpanded(false, animated: animated)
        if let group, isSelected(group) {
            annotationStore.deselectAnnotation(group, animated: false)
        }
    }

    // MARK: - Native lifecycle callbacks

    func visibleRegionDidChange(on mapView: MapboxMaps.MapView, userInitiated: Bool = false) {
        if userInitiated {
            collapse(on: mapView)
        }
        refreshViews(on: mapView)
        selectPendingAnnotationIfVisible(on: mapView)
    }

    func regionWillChange(on mapView: MapboxMaps.MapView, userInitiated: Bool = false) {
        if userInitiated {
            collapse(on: mapView)
        }
    }

    func regionDidChange(on mapView: MapboxMaps.MapView) {
        visibleRegionDidChange(on: mapView)
    }

    func didAddViews(on mapView: MapboxMaps.MapView) {
        DispatchQueue.main.async { [weak self, weak mapView] in
            guard let self, let mapView else { return }
            self.refreshViews(on: mapView)
        }
        selectPendingAnnotationIfVisible(on: mapView)
    }

    func tearDown() {
        expandedView?.setExpanded(false, animated: false)
        expandedGroupID = nil
        expandedView = nil
        pendingSelection = nil
        scheduledSelectionGeneration = nil
        selectionGeneration &+= 1
        sources.removeAll()
        memberIDsByAnnotation.removeAll()
        groupsByID.removeAll()
        managedAnnotations.removeAll()
        state.reset()
        lastAppliedRevision = nil
    }
}
