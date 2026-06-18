//
//  GeoJSON.swift
//  wander
//
//  Minimal GeoJSON parser used to load city boundaries.
//  Only FeatureCollections containing Polygon features are supported in V1.
//

import Foundation

struct GeoJSONFeatureCollection: Codable {
    let features: [GeoJSONFeature]
}

struct GeoJSONFeature: Codable {
    let geometry: GeoJSONGeometry
}

struct GeoJSONGeometry: Codable {
    let type: String
    /// Polygon coordinates: one outer ring plus optional holes.
    let coordinates: [[[Double]]]?

    /// Returns the exterior ring (first ring) as [lon, lat] pairs.
    /// Holes are ignored for the V1 city percentage.
    var exteriorRing: [[Double]]? {
        guard type == "Polygon", let rings = coordinates, let first = rings.first else { return nil }
        return first
    }
}
