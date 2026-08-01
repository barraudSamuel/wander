//
//  HeatMapOverlay.swift
//  wander
//
//  MKOverlay and MKOverlayRenderer for the time-spent heat map.
//

import Foundation
import MapKit

struct HeatMapCellPolygon {
    let coordinates: [CLLocationCoordinate2D]
    let mapRect: MKMapRect
    let duration: TimeInterval
}

final class HeatMapOverlay: NSObject, MKOverlay {
    let boundingMapRect: MKMapRect
    let coordinate: CLLocationCoordinate2D
    let cellPolygons: [String: HeatMapCellPolygon]
    let maxDuration: TimeInterval

    init(cellData: [String: (duration: TimeInterval, visitCount: Int)],
         explorationEngine: ExplorationEngine) {
        var polygons: [String: HeatMapCellPolygon] = [:]
        var maximumDuration: TimeInterval = 0
        var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0

        for (cellID, value) in cellData {
            guard value.duration > 0 else { continue }
            let coords = explorationEngine.boundaryCoordinates(for: cellID)
            guard coords.count >= 3 else { continue }

            polygons[cellID] = HeatMapCellPolygon(
                coordinates: coords,
                mapRect: Self.mapRect(for: coords),
                duration: value.duration
            )
            maximumDuration = max(maximumDuration, value.duration)

            for coord in coords {
                minLat = min(minLat, coord.latitude)
                maxLat = max(maxLat, coord.latitude)
                minLng = min(minLng, coord.longitude)
                maxLng = max(maxLng, coord.longitude)
            }
        }

        self.cellPolygons = polygons
        self.maxDuration = maximumDuration

        if polygons.isEmpty {
            self.coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
            self.boundingMapRect = MKMapRect.null
        } else {
            self.coordinate = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLng + maxLng) / 2
            )

            let topLeft = MKMapPoint(CLLocationCoordinate2D(latitude: maxLat, longitude: minLng))
            let bottomRight = MKMapPoint(CLLocationCoordinate2D(latitude: minLat, longitude: maxLng))
            let padding = 1000.0
            self.boundingMapRect = MKMapRect(
                x: topLeft.x - padding,
                y: topLeft.y - padding,
                width: bottomRight.x - topLeft.x + padding * 2,
                height: bottomRight.y - topLeft.y + padding * 2
            )
        }

        super.init()
    }

    private static func mapRect(
        for coordinates: [CLLocationCoordinate2D]
    ) -> MKMapRect {
        coordinates.reduce(.null) { partialResult, coordinate in
            let point = MKMapPoint(coordinate)
            return partialResult.union(
                MKMapRect(x: point.x, y: point.y, width: 1, height: 1)
            )
        }
    }
}

final class HeatMapOverlayRenderer: MKOverlayRenderer {
    /// Thirteen anchors create twelve interpolation segments, giving nearby
    /// durations more distinct shades while preserving the green-to-red scale.
    private static let colorScale: [(red: CGFloat, green: CGFloat, blue: CGFloat)] = [
        (0.00, 0.68, 0.30),
        (0.15, 0.76, 0.25),
        (0.32, 0.82, 0.20),
        (0.50, 0.87, 0.14),
        (0.68, 0.90, 0.08),
        (0.84, 0.88, 0.03),
        (0.96, 0.82, 0.00),
        (1.00, 0.70, 0.00),
        (1.00, 0.56, 0.00),
        (1.00, 0.40, 0.00),
        (0.96, 0.24, 0.04),
        (0.88, 0.10, 0.10),
        (0.72, 0.00, 0.18)
    ]

    override func canDraw(_ mapRect: MKMapRect, zoomScale: MKZoomScale) -> Bool {
        return true
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let overlay = self.overlay as? HeatMapOverlay,
              !overlay.cellPolygons.isEmpty,
              overlay.maxDuration > 0 else { return }

        context.setLineWidth(1.0 / zoomScale)

        for cell in overlay.cellPolygons.values
            where cell.mapRect.intersects(mapRect) {
            guard cell.duration > 0 else { continue }

            let intensity = CGFloat(min(cell.duration / overlay.maxDuration, 1.0))
            let color = Self.colorForIntensity(intensity)

            context.setFillColor(red: color.red, green: color.green, blue: color.blue, alpha: 0.6)
            context.setStrokeColor(red: color.red, green: color.green, blue: color.blue, alpha: 0.3)

            context.beginPath()
            for (index, coord) in cell.coordinates.enumerated() {
                let point = self.point(for: MKMapPoint(coord))
                if index == 0 {
                    context.move(to: point)
                } else {
                    context.addLine(to: point)
                }
            }
            context.closePath()
            context.drawPath(using: .fillStroke)
        }
    }

    private static func colorForIntensity(_ t: CGFloat) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let clamped = max(0, min(1, t))
        let segmentCount = colorScale.count - 1
        let scaled = clamped * CGFloat(segmentCount)
        let index = min(Int(scaled), segmentCount - 1)
        let frac = scaled - CGFloat(index)

        let a = colorScale[index]
        let b = colorScale[min(index + 1, segmentCount)]

        return (
            red: a.red + (b.red - a.red) * frac,
            green: a.green + (b.green - a.green) * frac,
            blue: a.blue + (b.blue - a.blue) * frac
        )
    }
}
