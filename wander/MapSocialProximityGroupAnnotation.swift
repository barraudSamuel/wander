//
//  MapSocialProximityGroupAnnotation.swift
//  wander
//

import CoreLocation
import MapKit

/// A stable, app-owned annotation representing social items at the same place.
///
/// MapKit owns `MKClusterAnnotation` instances, so geographic groups use this
/// annotation instead of trying to manufacture native visual clusters.
final class MapSocialProximityGroupAnnotation: NSObject, MKAnnotation {
    let identifier: String

    @objc dynamic private(set) var coordinate: CLLocationCoordinate2D
    private(set) var memberAnnotations: [any MKAnnotation]

    init(
        identifier: String = UUID().uuidString,
        memberAnnotations: [any MKAnnotation]
    ) {
        self.identifier = identifier
        self.memberAnnotations = memberAnnotations
        coordinate = Self.centerCoordinate(of: memberAnnotations)
        super.init()
    }

    func update(memberAnnotations: [any MKAnnotation]) {
        self.memberAnnotations = memberAnnotations
        coordinate = Self.centerCoordinate(of: memberAnnotations)
    }

    private static func centerCoordinate(
        of annotations: [any MKAnnotation]
    ) -> CLLocationCoordinate2D {
        guard !annotations.isEmpty else {
            return kCLLocationCoordinate2DInvalid
        }

        let latitude = annotations.reduce(0) {
            $0 + $1.coordinate.latitude
        } / Double(annotations.count)
        let longitudeVector = annotations.reduce(into: (x: 0.0, y: 0.0)) {
            result, annotation in
            let radians = annotation.coordinate.longitude * .pi / 180
            result.x += cos(radians)
            result.y += sin(radians)
        }
        let longitude = atan2(
            longitudeVector.y,
            longitudeVector.x
        ) * 180 / .pi
        return CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        )
    }
}
