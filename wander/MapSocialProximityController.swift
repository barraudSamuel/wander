//
//  MapSocialProximityController.swift
//  wander
//

import MapKit
import UIKit

/// Owns the native lifecycle of social groups, including temporary member focus.
/// MapKit callbacks return here so rendering never becomes a second source of truth.
@MainActor
final class MapSocialProximityController {
    private let presentation: (MapSocialProximityGroupAnnotation) -> MapSocialClusterPresentation
    private let setFocusAppearance: (Bool, MKAnnotationView) -> Void
    private let onDeselectMember: (MapSocialClusterMemberID) -> Void
    private let visibleBounds: @MainActor (MKMapView) -> CGRect
    private var state = MapSocialProximityState()
    private var sources: [MapSocialClusterMemberID: any MKAnnotation] = [:]
    private var memberIDsByAnnotation: [ObjectIdentifier: MapSocialClusterMemberID] = [:]
    private var groupsByID: [String: MapSocialProximityGroupAnnotation] = [:]
    private var managedAnnotations: [ObjectIdentifier: any MKAnnotation] = [:]
    private var lastAppliedRevision: Int?
    private var expandedGroupID: String?
    private weak var expandedView: MapSocialClusterAnnotationView?
    private var pendingSelection: MapSocialClusterMemberID?
    private var selectionGeneration = 0
    private var scheduledSelectionGeneration: Int?
    private var isFittingExpandedGroup = false

    init(
        presentation: @escaping (MapSocialProximityGroupAnnotation) -> MapSocialClusterPresentation,
        setFocusAppearance: @escaping (Bool, MKAnnotationView) -> Void,
        onDeselectMember: @escaping (MapSocialClusterMemberID) -> Void = { _ in },
        visibleBounds: @escaping @MainActor (MKMapView) -> CGRect = {
            $0.bounds.inset(by: $0.safeAreaInsets)
        }
    ) {
        self.presentation = presentation
        self.setFocusAppearance = setFocusAppearance
        self.onDeselectMember = onDeselectMember
        self.visibleBounds = visibleBounds
    }

    // Avoid synthesized isolated deinit on older Swift runtimes (swiftlang/swift#88036).
    // Native cleanup is performed explicitly by tearDown on the main actor.
    nonisolated deinit {}

    // MARK: - Sources and rendering

    func update(
        sources nextSources: [MapSocialClusterMemberID: any MKAnnotation],
        on mapView: MKMapView
    ) {
        let previousFocus = focusedAnnotation
        let previousMemberID = state.focusedMemberID
        let nextObjectIDs = nextSources.mapValues { ObjectIdentifier($0 as AnyObject) }
        let previousObjectIDs = sources.mapValues { ObjectIdentifier($0 as AnyObject) }
        sources = nextSources
        memberIDsByAnnotation = Dictionary(uniqueKeysWithValues: sources.map {
            (ObjectIdentifier($0.value as AnyObject), $0.key)
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
            if let view = mapView.view(for: previousFocus) {
                setFocusAppearance(false, view)
            }
            mapView.deselectAnnotation(previousFocus, animated: false)
        }
        if let previousMemberID, previousMemberID != state.focusedMemberID {
            onDeselectMember(previousMemberID)
        }
        if previousObjectIDs != nextObjectIDs {
            lastAppliedRevision = nil
        }
        synchronize(on: mapView)
        refreshViews(on: mapView)
        viewportDidChange(on: mapView)
        selectPendingAnnotationIfVisible(on: mapView)
    }

    func isFocused(_ annotation: any MKAnnotation) -> Bool {
        guard let focusedAnnotation else { return false }
        return (focusedAnnotation as AnyObject) === (annotation as AnyObject)
    }

    var hasActivePresentation: Bool {
        state.focusedMemberID != nil || pendingSelection != nil || expandedGroupID != nil
    }

    /// Invalidates queued presentation work after a selection or teardown.
    var presentationRevision: Int { selectionGeneration }

    private var focusedAnnotation: (any MKAnnotation)? {
        state.focusedMemberID.flatMap { sources[$0] }
    }

    private func memberID(for annotation: any MKAnnotation) -> MapSocialClusterMemberID? {
        memberIDsByAnnotation[ObjectIdentifier(annotation as AnyObject)]
    }

    private func synchronize(on mapView: MKMapView) {
        guard lastAppliedRevision != state.revision else { return }
        // Publish ownership before MapKit can synchronously call its delegate.
        lastAppliedRevision = state.revision
        var desired: [any MKAnnotation] = []
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
            (ObjectIdentifier($0 as AnyObject), $0)
        })
        let removed = managedAnnotations.filter { desiredByID[$0.key] == nil }.map(\.value)
        groupsByID = nextGroups
        managedAnnotations = desiredByID
        if !removed.isEmpty {
            mapView.removeAnnotations(removed)
        }
        let attachedIDs = Set(mapView.annotations.map { ObjectIdentifier($0 as AnyObject) })
        let added = desired.filter { !attachedIDs.contains(ObjectIdentifier($0 as AnyObject)) }
        if !added.isEmpty {
            mapView.addAnnotations(added)
        }
    }

    func refreshViews(on mapView: MKMapView) {
        for annotation in sources.values {
            if let view = mapView.view(for: annotation) {
                view.isAccessibilityElement = view.cluster == nil
                setFocusAppearance(isFocused(annotation), view)
            }
        }
        if let expandedGroupID, groupsByID[expandedGroupID] == nil {
            collapseExpandedGroup(on: mapView, animated: false)
        }
        for group in groupsByID.values {
            guard let view = mapView.view(for: group) as? MapSocialClusterAnnotationView else {
                continue
            }
            configure(view, for: group, on: mapView)
        }
    }

    func configure(
        _ view: MapSocialClusterAnnotationView,
        for group: MapSocialProximityGroupAnnotation,
        on mapView: MKMapView
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
        _ annotation: any MKAnnotation,
        view: MKAnnotationView,
        on mapView: MKMapView
    ) -> MapSocialClusterMemberID? {
        guard managedAnnotations[ObjectIdentifier(annotation as AnyObject)] != nil,
              mapView.view(for: annotation) === view else { return nil }
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
        if mapView.userTrackingMode != .none {
            mapView.setUserTrackingMode(.none, animated: false)
        }
        if shouldRecenter {
            mapView.setCenter(annotation.coordinate, animated: !UIAccessibility.isReduceMotionEnabled)
        }
        return memberID
    }

    func didDeselect(_ annotation: any MKAnnotation, on mapView: MKMapView) {
        let generation = selectionGeneration
        // MapKit may deselect A just before selecting B. Let that handoff finish
        // before restoring a group that would remove B's visible annotation.
        DispatchQueue.main.async { [weak self, weak mapView] in
            guard let self, let mapView,
                  self.selectionGeneration == generation,
                  !self.isSelected(annotation, on: mapView) else { return }
            if let group = annotation as? MapSocialProximityGroupAnnotation {
                guard self.groupsByID[group.identifier] === group,
                      self.expandedGroupID == group.identifier else { return }
                self.collapseExpandedGroup(on: mapView, animated: true)
            } else if self.isFocused(annotation), self.pendingSelection == nil {
                self.changeFocus(to: nil, on: mapView)
            }
        }
    }

    func select(_ memberID: MapSocialClusterMemberID, on mapView: MKMapView) {
        guard let annotation = sources[memberID],
              CLLocationCoordinate2DIsValid(annotation.coordinate) else { return }
        if isFocused(annotation), isSelected(annotation, on: mapView) {
            return
        }
        if pendingSelection == memberID {
            selectPendingAnnotationIfVisible(on: mapView)
            return
        }
        selectionGeneration &+= 1
        pendingSelection = memberID
        selectPendingAnnotationIfVisible(on: mapView)
    }

    func center(on memberID: MapSocialClusterMemberID, on mapView: MKMapView) {
        guard let annotation = sources[memberID],
              CLLocationCoordinate2DIsValid(annotation.coordinate) else { return }
        mapView.setUserTrackingMode(.none, animated: false)
        select(memberID, on: mapView)
        mapView.setRegion(
            MKCoordinateRegion(center: annotation.coordinate, latitudinalMeters: 800, longitudinalMeters: 800),
            animated: !UIAccessibility.isReduceMotionEnabled
        )
    }

    func collapse(on mapView: MKMapView) {
        selectionGeneration &+= 1
        pendingSelection = nil
        scheduledSelectionGeneration = nil
        collapseExpandedGroup(on: mapView, animated: false)
        changeFocus(to: nil, on: mapView)
    }

    private func changeFocus(to memberID: MapSocialClusterMemberID?, on mapView: MKMapView) {
        if memberID != nil {
            collapseExpandedGroup(on: mapView, animated: false)
        }
        let previousMemberID = state.focusedMemberID
        let previousAnnotation = focusedAnnotation
        guard state.focus(memberID) else { return }
        // Publish the final focus before MapKit can deliver deselection callbacks.
        // Rebuilding an intermediate unfocused group would detach the next member.
        if let previousAnnotation {
            if let view = mapView.view(for: previousAnnotation) {
                setFocusAppearance(false, view)
            }
            mapView.deselectAnnotation(previousAnnotation, animated: false)
        }
        synchronize(on: mapView)
        if let focusedAnnotation, let view = mapView.view(for: focusedAnnotation) {
            setFocusAppearance(true, view)
        }
        if let previousMemberID {
            onDeselectMember(previousMemberID)
        }
    }

    private func isSelected(_ annotation: any MKAnnotation, on mapView: MKMapView) -> Bool {
        mapView.selectedAnnotations.contains { ($0 as AnyObject) === (annotation as AnyObject) }
    }

    private func selectPendingAnnotationIfVisible(on mapView: MKMapView) {
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
        guard let view = mapView.view(for: annotation), view.cluster == nil else { return }
        let generation = selectionGeneration
        guard scheduledSelectionGeneration != generation else { return }
        scheduledSelectionGeneration = generation
        DispatchQueue.main.async { [weak self, weak mapView] in
            guard let self, let mapView,
                  self.selectionGeneration == generation,
                  self.pendingSelection == memberID,
                  self.isFocused(annotation) else { return }
            self.scheduledSelectionGeneration = nil
            if self.isSelected(annotation, on: mapView) {
                self.pendingSelection = nil
                return
            }
            mapView.selectAnnotation(annotation, animated: true)
        }
    }

    private func expand(_ group: MapSocialProximityGroupAnnotation, on mapView: MKMapView) {
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
              let view = mapView.view(for: group) as? MapSocialClusterAnnotationView else { return }
        configure(view, for: group, on: mapView)
        expandedGroupID = group.identifier
        expandedView = view
        view.setExpanded(true, animated: true)
        viewportDidChange(on: mapView)
    }

    /// A clipping-window change does not emit MapKit camera callbacks.
    /// Keep the existing group and selection while exposing its list and anchor.
    func viewportDidChange(on mapView: MKMapView) {
        guard !isFittingExpandedGroup,
              let groupID = expandedGroupID,
              let group = groupsByID[groupID],
              let view = expandedView,
              let annotation = view.annotation,
              (annotation as AnyObject) === group,
              view.isExpanded,
              let bounds = expandedGroupBounds(on: mapView) else { return }
        isFittingExpandedGroup = true
        defer { isFittingExpandedGroup = false }

        view.setExpandedViewportSize(bounds.size)
        let anchor = mapView.convert(group.coordinate, toPointTo: mapView)
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

        // MapKit centers inside its safe area, which can differ from bounds.midY.
        let projectedCenter = mapView.convert(mapView.centerCoordinate, toPointTo: mapView)
        guard projectedCenter.x.isFinite, projectedCenter.y.isFinite else { return }
        let center = mapView.convert(
            CGPoint(
                x: projectedCenter.x - translation.x,
                y: projectedCenter.y - translation.y
            ),
            toCoordinateFrom: mapView
        )
        guard CLLocationCoordinate2DIsValid(center) else { return }
        // A viewport drag can call this every frame. Do not queue camera animations.
        mapView.setCenter(center, animated: false)
    }

    private func expandedGroupBounds(on mapView: MKMapView) -> CGRect? {
        let bounds = visibleBounds(mapView)
        guard bounds.minX.isFinite, bounds.minY.isFinite,
              bounds.width.isFinite, bounds.height.isFinite,
              bounds.width > 24, bounds.height > 32 else { return nil }
        return bounds.insetBy(dx: 12, dy: 12)
    }

    private func collapseExpandedGroup(on mapView: MKMapView, animated: Bool) {
        guard expandedGroupID != nil || expandedView != nil else { return }
        let group = expandedView?.annotation as? MapSocialProximityGroupAnnotation
        let view = expandedView
        expandedGroupID = nil
        expandedView = nil
        view?.setExpanded(false, animated: animated)
        if let group, isSelected(group, on: mapView) {
            mapView.deselectAnnotation(group, animated: false)
        }
    }

    // MARK: - Native lifecycle callbacks

    func visibleRegionDidChange(on mapView: MKMapView, userInitiated: Bool = false) {
        if userInitiated {
            collapse(on: mapView)
        }
        refreshViews(on: mapView)
        selectPendingAnnotationIfVisible(on: mapView)
    }

    func regionWillChange(on mapView: MKMapView, userInitiated: Bool = false) {
        if userInitiated {
            collapse(on: mapView)
        }
    }

    func regionDidChange(on mapView: MKMapView) {
        visibleRegionDidChange(on: mapView)
    }

    func didAddViews(on mapView: MKMapView) {
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
