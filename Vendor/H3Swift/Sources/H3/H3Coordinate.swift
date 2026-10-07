/// Represents a geographic coordinate defined by latitude and longitude.
public struct H3Coordinate: Sendable {

    /// The latitude in degrees.
    public let lat: Double

    /// The longitude in degrees.
    public let lng: Double

    /// Initializes the coordinate with the given latitude and longitude.
    ///
    /// - Parameters:
    ///   - lat: Latitude in degrees.
    ///   - lng: Longitude in degrees.
    public init(lat: Double, lng: Double) {
        self.lat = lat
        self.lng = lng
    }

}

extension H3Coordinate: Equatable, Hashable {}

extension H3Coordinate: Codable {}
