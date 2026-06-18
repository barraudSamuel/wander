//
//  GeoJSON.swift
//  wander
//
//  Minimal GeoJSON parser used to load city boundaries.
//  Only FeatureCollections containing Polygon features are supported in V1.
//

import Foundation

/// Top-level GeoJSON object containing an array of features.
struct GeoJSONFeatureCollection: Codable {
    let features: [GeoJSONFeature]
}

/// A single feature with its geometry.
struct GeoJSONFeature: Codable {
    let geometry: GeoJSONGeometry
}

/// Polygon geometry with one outer ring and optional inner holes.
struct GeoJSONGeometry: Codable {
    let type: String
    /// Polygon coordinates: one outer ring plus optional holes.
    let coordinates: [[[Double]]]?

    /// Returns the exterior ring (first ring) as [lon, lat] pairs.
    /// Holes are ignored for V1 city percentage calculation.
    var exteriorRing: [[Double]]? {
        guard type == "Polygon", let rings = coordinates, let first = rings.first else { return nil }
        return first
    }
}
