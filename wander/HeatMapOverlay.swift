//
//  HeatMapOverlay.swift
//  wander
//
//  MKOverlay and MKOverlayRenderer for the time-spent heat map.
//

import Foundation
import MapKit

final class HeatMapOverlay: NSObject, MKOverlay {
    let boundingMapRect: MKMapRect
    let coordinate: CLLocationCoordinate2D
    let cellPolygons: [String: [CLLocationCoordinate2D]]
    let cellDurations: [String: TimeInterval]

    init(cellData: [String: (duration: TimeInterval, visitCount: Int)],
         explorationEngine: ExplorationEngine) {
        var polygons: [String: [CLLocationCoordinate2D]] = [:]
        var durations: [String: TimeInterval] = [:]
        var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0

        for (cellID, value) in cellData {
            guard value.duration > 0 else { continue }
            let coords = explorationEngine.boundaryCoordinates(for: cellID)
            guard coords.count >= 3 else { continue }

            polygons[cellID] = coords
            durations[cellID] = value.duration

            for coord in coords {
                minLat = min(minLat, coord.latitude)
                maxLat = max(maxLat, coord.latitude)
                minLng = min(minLng, coord.longitude)
                maxLng = max(maxLng, coord.longitude)
            }
        }

        self.cellPolygons = polygons
        self.cellDurations = durations

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
}

final class HeatMapOverlayRenderer: MKOverlayRenderer {
    private static let colorScale: [(red: CGFloat, green: CGFloat, blue: CGFloat)] = [
        (0.0, 0.8, 0.2),
        (0.4, 0.9, 0.2),
        (0.8, 0.9, 0.0),
        (1.0, 0.8, 0.0),
        (1.0, 0.5, 0.0),
        (1.0, 0.2, 0.0),
        (0.8, 0.0, 0.2)
    ]

    override func canDraw(_ mapRect: MKMapRect, zoomScale: MKZoomScale) -> Bool {
        return true
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let overlay = self.overlay as? HeatMapOverlay,
              !overlay.cellPolygons.isEmpty,
              let maxDuration = overlay.cellDurations.values.max(),
              maxDuration > 0 else { return }

        context.setLineWidth(1.0 / zoomScale)

        for (cellID, coords) in overlay.cellPolygons {
            guard let duration = overlay.cellDurations[cellID], duration > 0 else { continue }

            let intensity = CGFloat(min(duration / maxDuration, 1.0))
            let color = Self.colorForIntensity(intensity)

            context.setFillColor(red: color.red, green: color.green, blue: color.blue, alpha: 0.6)
            context.setStrokeColor(red: color.red, green: color.green, blue: color.blue, alpha: 0.3)

            context.beginPath()
            for (index, coord) in coords.enumerated() {
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
