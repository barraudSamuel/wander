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
    private var isChangingRegion = false
    private var regionChangeReset: DispatchWorkItem?

    init(
        presentation: @escaping (MapSocialProximityGroupAnnotation) -> MapSocialClusterPresentation,
        setFocusAppearance: @escaping (Bool, MKAnnotationView) -> Void
    ) {
        self.presentation = presentation
        self.setFocusAppearance = setFocusAppearance
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
        if let previousFocus,
           focusedAnnotation.map({ ($0 as AnyObject) === (previousFocus as AnyObject) }) != true {
            selectionGeneration &+= 1
            if let view = mapView.view(for: previousFocus) {
                setFocusAppearance(false, view)
            }
            mapView.deselectAnnotation(previousFocus, animated: false)
        }
        if previousObjectIDs != nextObjectIDs {
            lastAppliedRevision = nil
        }
        synchronize(on: mapView)
        refreshViews(on: mapView)
    }

    func isFocused(_ annotation: any MKAnnotation) -> Bool {
        guard let focusedAnnotation else { return false }
        return (focusedAnnotation as AnyObject) === (annotation as AnyObject)
    }

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
        if !isChangingRegion, let expandedGroupID, groupsByID[expandedGroupID] == nil {
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
            restoreFocus(on: mapView)
            state.focus(memberID)
            setFocusAppearance(true, view)
            beginRegionChange()
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
        if let group = annotation as? MapSocialProximityGroupAnnotation {
            // A late callback for a replaced group must not close a newer one.
            if group.identifier == expandedGroupID {
                collapseExpandedGroup(on: mapView, animated: true)
            }
            return
        }
        if isFocused(annotation) {
            restoreFocus(on: mapView)
        }
    }

    func select(_ memberID: MapSocialClusterMemberID, on mapView: MKMapView) {
        selectionGeneration &+= 1
        pendingSelection = memberID
        selectPendingAnnotationIfVisible(on: mapView)
    }

    func center(on memberID: MapSocialClusterMemberID, on mapView: MKMapView) {
        guard let annotation = sources[memberID],
              CLLocationCoordinate2DIsValid(annotation.coordinate) else { return }
        mapView.setUserTrackingMode(.none, animated: false)
        selectionGeneration &+= 1
        pendingSelection = memberID
        beginRegionChange()
        mapView.setRegion(
            MKCoordinateRegion(center: annotation.coordinate, latitudinalMeters: 800, longitudinalMeters: 800),
            animated: !UIAccessibility.isReduceMotionEnabled
        )
        selectPendingAnnotationIfVisible(on: mapView)
    }

    func collapse(on mapView: MKMapView) {
        selectionGeneration &+= 1
        pendingSelection = nil
        collapseExpandedGroup(on: mapView, animated: false)
        restoreFocus(on: mapView)
    }

    private func restoreFocus(on mapView: MKMapView) {
        guard let annotation = focusedAnnotation else { return }
        state.focus(nil)
        if let view = mapView.view(for: annotation) {
            setFocusAppearance(false, view)
        }
        mapView.deselectAnnotation(annotation, animated: false)
        synchronize(on: mapView)
    }

    private func selectPendingAnnotationIfVisible(on mapView: MKMapView) {
        guard let memberID = pendingSelection else { return }
        guard let annotation = sources[memberID],
              CLLocationCoordinate2DIsValid(annotation.coordinate) else {
            pendingSelection = nil
            return
        }
        if !isFocused(annotation) {
            restoreFocus(on: mapView)
            state.focus(memberID)
            synchronize(on: mapView)
            // didAdd can consume this selection synchronously. A singleton may
            // already have a view and produce no didAdd callback at all.
            guard pendingSelection == memberID else { return }
        }
        guard let view = mapView.view(for: annotation), view.cluster == nil else { return }
        pendingSelection = nil
        let generation = selectionGeneration
        DispatchQueue.main.async { [weak self, weak mapView] in
            guard let self, let mapView,
                  self.selectionGeneration == generation,
                  self.isFocused(annotation) else { return }
            mapView.selectAnnotation(annotation, animated: true)
        }
    }

    private func expand(_ group: MapSocialProximityGroupAnnotation, on mapView: MKMapView) {
        guard groupsByID[group.identifier] === group,
              group.memberAnnotations.count > 1,
              let view = mapView.view(for: group) as? MapSocialClusterAnnotationView else { return }
        guard expandedGroupID != group.identifier else { return }
        collapseExpandedGroup(on: mapView, animated: false)
        configure(view, for: group, on: mapView)
        expandedGroupID = group.identifier
        expandedView = view
        let anchor = mapView.convert(group.coordinate, toPointTo: mapView)
        let safeBounds = mapView.bounds.inset(by: mapView.safeAreaInsets).insetBy(dx: 12, dy: 12)
        if !safeBounds.contains(view.projectedExpandedFrame(at: anchor)) {
            beginRegionChange()
            mapView.setCenter(group.coordinate, animated: !UIAccessibility.isReduceMotionEnabled)
        }
        view.setExpanded(true, animated: true)
    }

    private func collapseExpandedGroup(on mapView: MKMapView, animated: Bool) {
        guard expandedGroupID != nil || expandedView != nil else { return }
        let group = expandedView?.annotation as? MapSocialProximityGroupAnnotation
        let view = expandedView
        expandedGroupID = nil
        expandedView = nil
        view?.setExpanded(false, animated: animated)
        if let group, mapView.selectedAnnotations.contains(where: { ($0 as AnyObject) === group }) {
            mapView.deselectAnnotation(group, animated: false)
        }
    }

    // MARK: - Native lifecycle callbacks

    func visibleRegionDidChange(on mapView: MKMapView) {
        refreshViews(on: mapView)
        selectPendingAnnotationIfVisible(on: mapView)
    }

    func regionWillChange(on mapView: MKMapView) {
        guard !isChangingRegion else { return }
        collapse(on: mapView)
    }

    func regionDidChange(on mapView: MKMapView) {
        finishRegionChange()
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
        selectionGeneration &+= 1
        sources.removeAll()
        memberIDsByAnnotation.removeAll()
        groupsByID.removeAll()
        managedAnnotations.removeAll()
        state.reset()
        lastAppliedRevision = nil
        finishRegionChange()
    }

    private func beginRegionChange() {
        regionChangeReset?.cancel()
        isChangingRegion = true
        let workItem = DispatchWorkItem { [weak self] in
            self?.isChangingRegion = false
            self?.regionChangeReset = nil
        }
        regionChangeReset = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: workItem)
    }

    private func finishRegionChange() {
        regionChangeReset?.cancel()
        regionChangeReset = nil
        isChangingRegion = false
    }
}
