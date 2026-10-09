//
//  MapSocialProximityGroupAnnotation.swift
//  wander
//

import CoreLocation

/// A stable annotation representing social items at the same place.
final class MapSocialProximityGroupAnnotation: MapAnnotation {
    let identifier: String

    private(set) var memberAnnotations: [MapAnnotation]

    init(
        identifier: String = UUID().uuidString,
        memberAnnotations: [MapAnnotation]
    ) {
        self.identifier = identifier
        self.memberAnnotations = memberAnnotations
        super.init(coordinate: Self.centerCoordinate(of: memberAnnotations))
    }

    func update(memberAnnotations: [MapAnnotation]) {
        self.memberAnnotations = memberAnnotations
        coordinate = Self.centerCoordinate(of: memberAnnotations)
    }

    private static func centerCoordinate(
        of annotations: [MapAnnotation]
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
