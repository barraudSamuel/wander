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
        #if DEBUG && targetEnvironment(simulator)
        if DebugSocialMapScenario.isEnabled && !hasPublicToken {
            // Exercises real Mapbox gestures and annotations without network tiles.
            return MapboxMaps.MapView(frame: .zero, mapInitOptions: MapInitOptions(
                cameraOptions: camera, styleURI: nil, styleJSON: """
                {"version":8,"sources":{},"layers":[{"id":"background","type":"background","paint":{"background-color":"#edece8"}}]}
                """
            ))
        }
        #endif
        return MapboxMaps.MapView(frame: .zero, mapInitOptions: MapInitOptions(
            cameraOptions: camera, styleURI: .streets
        ))
    }
}
