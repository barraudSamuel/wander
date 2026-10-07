import Ch3

/// Represents a unidirectional edge between two neighboring H3 cells.
///
/// An edge index is a 64-bit H3 value (like `H3Index`) but encodes a directed
/// connection from an origin cell to an adjacent destination cell.
public struct H3Edge: Sendable {

    // MARK: - Internal

    let value: UInt64

    // MARK: - Initializers

    /// Initializes with a raw edge index value.
    ///
    /// - Parameter value: The raw 64-bit edge index.
    public init(_ value: UInt64) {
        self.value = value
    }

    /// Creates a unidirectional edge from `origin` to `destination`.
    ///
    /// Returns `nil` if the two cells are not direct neighbors.
    ///
    /// - Parameters:
    ///   - origin: The origin cell.
    ///   - destination: The destination cell.
    public init?(from origin: H3Index, to destination: H3Index) {
        var neighborFlag: Int32 = 0
        areNeighborCells(origin.value, destination.value, &neighborFlag)
        guard neighborFlag == 1 else { return nil }
        var out: UInt64 = 0
        let err = cellsToDirectedEdge(origin.value, destination.value, &out)
        guard err == E_SUCCESS.rawValue, out != 0 else { return nil }
        self.value = out
    }

    // MARK: - Properties

    /// Whether this is a valid directed edge index.
    public var isValid: Bool {
        isValidDirectedEdge(value) == 1
    }

    /// The raw 64-bit edge index value.
    public var rawValue: UInt64 { value }

    /// The origin cell of this edge.
    public var origin: H3Index {
        var out: UInt64 = 0
        getDirectedEdgeOrigin(value, &out)
        return H3Index(out)
    }

    /// The destination cell of this edge.
    public var destination: H3Index {
        var out: UInt64 = 0
        getDirectedEdgeDestination(value, &out)
        return H3Index(out)
    }

    /// Both the origin and destination cells of this edge.
    public var cells: (origin: H3Index, destination: H3Index) {
        var pair = [UInt64](repeating: 0, count: 2)
        directedEdgeToCells(value, &pair)
        return (H3Index(pair[0]), H3Index(pair[1]))
    }

    /// The geographic boundary of this edge as an ordered array of coordinates.
    public func boundary() -> [H3Coordinate] {
        var cb = CellBoundary()
        directedEdgeToBoundary(value, &cb)
        let count = Int(cb.numVerts)

        return withUnsafeBytes(of: &cb.verts) { ptr -> [H3Coordinate] in
            (0 ..< count).map { i in
                let vert = ptr.load(
                    fromByteOffset: i * MemoryLayout<LatLng>.stride,
                    as: LatLng.self
                )
                return H3Coordinate(lat: radsToDegs(vert.lat), lng: radsToDegs(vert.lng))
            }
        }
    }

}

// MARK: - CustomStringConvertible

extension H3Edge: CustomStringConvertible {

    /// The lowercase hex string representation of this edge index.
    public var description: String {
        let bufferSize = 17
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        h3ToString(value, buffer, bufferSize)
        return String(cString: buffer)
    }

}

// MARK: - Equatable, Hashable

extension H3Edge: Equatable, Hashable {}
