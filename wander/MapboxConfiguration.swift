import CoreLocation
import CoreGraphics
import MapboxMaps

enum MapboxConfiguration {
    static var hasPublicToken: Bool {
        publicToken.hasPrefix("pk.")
    }

    private static var publicToken: String {
        (Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func makeMapView() -> MapboxMaps.MapView {
        MapboxOptions.accessToken = publicToken
        let camera = CameraOptions(
            center: CLLocationCoordinate2D(latitude: 10.76, longitude: 106.66),
            zoom: 11, bearing: 0, pitch: 0
        )
        return MapboxMaps.MapView(frame: .zero, mapInitOptions: MapInitOptions(
            cameraOptions: camera, styleURI: nil, styleJSON: styleJSON
        ))
    }

    private static var styleJSON: String {
        #if DEBUG && targetEnvironment(simulator)
        if DebugSocialMapScenario.isEnabled && !hasPublicToken {
            // Exercises real Mapbox gestures and annotations without network tiles.
            return """
            {"version":8,"sources":{},"layers":[{"id":"background","type":"background","paint":{"background-color":"#ECEDEC"}}]}
            """
        }
        #endif
        return lightPastelStyleJSON
    }

    // Keep projection and palette in the initial style, including after style reloads.
    // A flat Mercator map preserves the H3 fog geometry and layer ordering.
    private static let lightPastelStyleJSON = """
    {
        "version": 8,
        "name": "Wander Clair pastel",
        "projection": {"name": "mercator"},
        "imports": [{
            "id": "basemap",
            "url": "mapbox://styles/mapbox/standard",
            "config": {
                "theme": "default",
                "lightPreset": "day",
                "show3dObjects": false,
                "showPointOfInterestLabels": false,
                "showLandmarkIcons": false,
                "showLandmarkIconLabels": false,
                "showPlaceLabels": true,
                "showRoadLabels": true,
                "colorLand": "#ECEDEC",
                "colorBuildings": "#ECEDEC",
                "colorCommercial": "#ECEDEC",
                "colorIndustrial": "#ECEDEC",
                "colorEducation": "#ECEDEC",
                "colorMedical": "#ECEDEC",
                "colorGreenspace": "#C4E1AE",
                "colorWater": "#BEDFF1",
                "colorRoads": "#FFFFFF",
                "colorTrunks": "#FFFFFF",
                "colorMotorways": "#FFFFFF",
                "colorRoadLabels": "#3F4346",
                "colorPlaceLabels": "#73789B"
            }
        }],
        "sources": {},
        "layers": []
    }
    """
}
