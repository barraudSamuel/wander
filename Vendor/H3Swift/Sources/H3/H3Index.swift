import Ch3

/// Represents an index in H3's hexagonal geospatial grid system.
public struct H3Index: Sendable {

    // MARK: - Internal

    static let invalidIndex: UInt64 = 0  // 0

    let value: UInt64

    // MARK: - Initializers

    /// Initializes using a raw 64-bit H3 index value.
    ///
    /// - Parameter value: The 64-bit integer representing the H3 index.
    public init(_ value: UInt64) {
        self.value = value
    }

    /// Initializes using a geographic coordinate at a given resolution.
    ///
    /// - Parameters:
    ///   - coordinate: The latitude/longitude coordinate.
    ///   - resolution: The H3 resolution (0–15).
    public init(coordinate: H3Coordinate, resolution: Int32) {
        var coord = LatLng(lat: degsToRads(coordinate.lat), lng: degsToRads(coordinate.lng))
        var out: UInt64 = 0
        latLngToCell(&coord, Int32(resolution), &out)
        self.value = out
    }

    /// Failable initializer using the hex-string representation of an H3 index.
    ///
    /// Returns `nil` when the string does not represent a valid H3 index.
    ///
    /// - Parameter string: The hex string, e.g. `"842a107ffffffff"`.
    public init?(string: String) {
        var out: UInt64 = 0
        let err = string.withCString { stringToH3($0, &out) }
        guard err == 0, out != 0 else { return nil }
        self.value = out
    }

}

// MARK: - Core Properties

extension H3Index {

    /// The resolution of this index (0–15).
    public var resolution: Int {
        Int(getResolution(value))
    }

    /// Whether this is a valid H3 cell index.
    public var isValid: Bool {
        isValidCell(value) == 1
    }

    /// The geographic coordinate at the center of this index.
    public var coordinate: H3Coordinate {
        var coord = LatLng()
        cellToLatLng(value, &coord)
        return H3Coordinate(lat: radsToDegs(coord.lat), lng: radsToDegs(coord.lng))
    }

    /// The raw 64-bit integer value of this index.
    public var rawValue: UInt64 { value }

    /// The base cell number (0–121) of this index.
    public var baseCell: Int {
        Int(getBaseCellNumber(value))
    }

    /// Whether this cell is one of the 12 pentagons per resolution.
    public var isPentagon: Bool {
        Ch3.isPentagon(value) == 1
    }

    /// Whether this cell is at a Class III resolution (odd resolutions: 1, 3, 5 …).
    ///
    /// Class III resolutions are rotated 19.1° relative to Class II.
    public var isResClassIII: Bool {
        Ch3.isResClassIII(value) == 1
    }

    /// The icosahedron face numbers (0–19) that this cell intersects.
    public func faces() -> [Int] {
        var count: Int32 = 0
        maxFaceCount(value, &count)
        var raw = [Int32](repeating: -1, count: Int(count))
        getIcosahedronFaces(value, &raw)
        return raw.filter { $0 >= 0 }.map { Int($0) }
    }

}

// MARK: - Traversal

extension H3Index {

    /// All cells within `k` rings of this index (including self).
    ///
    /// - Parameter k: The number of rings to expand.
    /// - Returns: An array of `H3Index` values (may be empty).
    public func kRing(k: Int32) -> [H3Index] {
        var size: Int64 = 0
        maxGridDiskSize(k, &size)
        var raw = [UInt64](repeating: 0, count: Int(size))
        gridDisk(value, k, &raw)
        return raw.compactMap { $0 == 0 ? nil : H3Index($0) }
    }

    /// Cells in the hollow ring at exactly distance `k` from this index.
    ///
    /// In H3 v4, `gridRing` handles pentagons correctly (unlike the old
    /// `hexRing`/`gridRingUnsafe`), so this never returns `nil`.
    ///
    /// - Parameter k: The ring distance (0 returns just self).
    public func hexRing(k: Int32) -> [H3Index]? {
        var size: Int64 = 0
        maxGridRingSize(k, &size)
        var raw = [UInt64](repeating: 0, count: Int(size))
        let err = gridRing(value, k, &raw)
        guard err == E_SUCCESS.rawValue else { return nil }
        return raw.compactMap { $0 == 0 ? nil : H3Index($0) }
    }

    /// A result pairing an `H3Index` with its grid distance from the origin.
    public struct KRingEntry: Sendable {
        public let index: H3Index
        public let distance: Int
    }

    /// All cells within `k` rings, each paired with their grid distance from self.
    ///
    /// - Parameter k: The number of rings to expand.
    public func kRingDistances(k: Int32) -> [KRingEntry] {
        var size: Int64 = 0
        maxGridDiskSize(k, &size)
        let count = Int(size)
        var rawIndexes   = [UInt64](repeating: 0, count: count)
        var rawDistances = [Int32](repeating: 0, count: count)
        gridDiskDistances(value, k, &rawIndexes, &rawDistances)
        return zip(rawIndexes, rawDistances).compactMap { idx, dist in
            guard idx != 0 else { return nil }
            return KRingEntry(index: H3Index(idx), distance: Int(dist))
        }
    }

}

// MARK: - Hierarchy

extension H3Index {

    /// The parent index one resolution coarser than this index.
    public var directParent: H3Index? {
        parent(at: resolution - 1)
    }

    /// The center-child index one resolution finer than this index.
    public var directCenterChild: H3Index? {
        centerChild(at: resolution + 1)
    }

    /// The ancestor index at the specified resolution.
    ///
    /// - Parameter resolution: Target resolution (must be coarser than `self.resolution`).
    /// - Returns: The parent index, or `nil` if the resolution is invalid.
    public func parent(at resolution: Int) -> H3Index? {
        var out: UInt64 = 0
        let err = cellToParent(value, Int32(resolution), &out)
        guard err == E_SUCCESS.rawValue, out != 0 else { return nil }
        return H3Index(out)
    }

    /// All child indices at the specified resolution.
    ///
    /// - Parameter resolution: Target resolution (must be finer than `self.resolution`).
    public func children(at resolution: Int) -> [H3Index] {
        var count: Int64 = 0
        guard cellToChildrenSize(value, Int32(resolution), &count) == E_SUCCESS.rawValue,
              count > 0 else { return [] }
        var raw = [UInt64](repeating: 0, count: Int(count))
        raw.withUnsafeMutableBufferPointer { ptr in
            _ = cellToChildren(value, Int32(resolution), ptr.baseAddress)
        }
        return raw.filter { $0 != 0 }.map { H3Index($0) }
    }

    /// The center-child index at the specified resolution.
    ///
    /// - Parameter resolution: Target resolution (must be finer than `self.resolution`).
    /// - Returns: The center child, or `nil` if the resolution is invalid.
    public func centerChild(at resolution: Int) -> H3Index? {
        var out: UInt64 = 0
        let err = cellToCenterChild(value, Int32(resolution), &out)
        guard err == E_SUCCESS.rawValue, out != 0 else { return nil }
        return H3Index(out)
    }

}

// MARK: - Grid Distance & Line

extension H3Index {

    /// The grid distance (number of cell hops) between this index and `other`.
    ///
    /// Returns `nil` if the two cells are at different resolutions or the
    /// distance cannot be computed (e.g. across a pentagon).
    ///
    /// - Parameter other: The target cell.
    public func distance(to other: H3Index) -> Int? {
        var d: Int64 = 0
        let err = gridDistance(value, other.value, &d)
        guard err == E_SUCCESS.rawValue else { return nil }
        return Int(d)
    }

    /// The ordered sequence of cells forming a grid line from this index to `other`.
    ///
    /// Returns `nil` if a line cannot be computed (e.g. across a pentagon,
    /// or cells at different resolutions).
    ///
    /// - Parameter other: The target cell.
    public func gridLine(to other: H3Index) -> [H3Index]? {
        var size: Int64 = 0
        guard gridPathCellsSize(value, other.value, &size) == E_SUCCESS.rawValue,
              size >= 0 else { return nil }
        var raw = [UInt64](repeating: 0, count: Int(size))
        let err = gridPathCells(value, other.value, &raw)
        guard err == E_SUCCESS.rawValue else { return nil }
        return raw.filter { $0 != 0 }.map { H3Index($0) }
    }

}

// MARK: - Neighbor / Edge Queries

extension H3Index {

    /// Whether `other` is a direct neighbor of this cell.
    ///
    /// - Parameter other: The candidate neighbor.
    public func isNeighbor(of other: H3Index) -> Bool {
        var out: Int32 = 0
        areNeighborCells(value, other.value, &out)
        return out == 1
    }

    /// All unidirectional edges originating from this cell.
    ///
    /// Returns 6 edges for a hexagon, 5 for a pentagon.
    public func edges() -> [H3Edge] {
        var raw = [UInt64](repeating: 0, count: 6)
        originToDirectedEdges(value, &raw)
        return raw.compactMap { $0 == 0 ? nil : H3Edge($0) }
    }

}

// MARK: - Compact / Uncompact

extension H3Index {

    /// Compresses a set of cells to the most coarse-resolution representation possible.
    ///
    /// Input cells may be at mixed resolutions. Returns `nil` if compaction fails
    /// (e.g. invalid input).
    ///
    /// - Parameter cells: The cells to compact.
    public static func compact(_ cells: [H3Index]) -> [H3Index]? {
        guard !cells.isEmpty else { return [] }
        let raw = cells.map { $0.value }
        var output = [UInt64](repeating: 0, count: raw.count)
        let err = compactCells(raw, &output, Int64(raw.count))
        guard err == E_SUCCESS.rawValue else { return nil }
        return output.filter { $0 != 0 }.map { H3Index($0) }
    }

    /// Expands a compacted (mixed-resolution) set of cells to a uniform resolution.
    ///
    /// Returns `nil` if uncompaction fails.
    ///
    /// - Parameters:
    ///   - cells: The compacted cells.
    ///   - resolution: The target resolution.
    public static func uncompact(_ cells: [H3Index], resolution: Int) -> [H3Index]? {
        guard !cells.isEmpty else { return [] }
        let raw = cells.map { $0.value }
        var maxSize: Int64 = 0
        guard uncompactCellsSize(raw, Int64(raw.count), Int32(resolution), &maxSize) == E_SUCCESS.rawValue,
              maxSize >= 0 else { return nil }
        var output = [UInt64](repeating: 0, count: Int(maxSize))
        let err = uncompactCells(raw, Int64(raw.count), &output, maxSize, Int32(resolution))
        guard err == E_SUCCESS.rawValue else { return nil }
        return output.filter { $0 != 0 }.map { H3Index($0) }
    }

}

// MARK: - Resolution Statistics

extension H3Index {

    /// Units for hex area queries.
    public enum AreaUnit: Sendable {
        case km2
        case m2
    }

    /// Units for edge length queries.
    public enum LengthUnit: Sendable {
        case km
        case m
    }

    /// Average area of a hexagonal cell at the given resolution.
    ///
    /// - Parameters:
    ///   - resolution: The H3 resolution (0–15).
    ///   - unit: `.km2` or `.m2`.
    public static func hexArea(resolution: Int, unit: AreaUnit) -> Double {
        var out: Double = 0
        switch unit {
        case .km2: getHexagonAreaAvgKm2(Int32(resolution), &out)
        case .m2:  getHexagonAreaAvgM2(Int32(resolution), &out)
        }
        return out
    }

    /// Average edge length of a hexagonal cell at the given resolution.
    ///
    /// - Parameters:
    ///   - resolution: The H3 resolution (0–15).
    ///   - unit: `.km` or `.m`.
    public static func edgeLength(resolution: Int, unit: LengthUnit) -> Double {
        var out: Double = 0
        switch unit {
        case .km: getHexagonEdgeLengthAvgKm(Int32(resolution), &out)
        case .m:  getHexagonEdgeLengthAvgM(Int32(resolution), &out)
        }
        return out
    }

    /// Total number of cells at the given resolution.
    ///
    /// - Parameter resolution: The H3 resolution (0–15).
    public static func cellCount(resolution: Int) -> Int64 {
        var out: Int64 = 0
        getNumCells(Int32(resolution), &out)
        return out
    }

    /// All 122 resolution-0 base cells.
    public static func res0Cells() -> [H3Index] {
        let count = Int(res0CellCount())
        var raw = [UInt64](repeating: 0, count: count)
        getRes0Cells(&raw)
        return raw.map { H3Index($0) }
    }

    /// All 12 pentagons at the given resolution.
    ///
    /// - Parameter resolution: The H3 resolution (0–15).
    public static func pentagons(resolution: Int) -> [H3Index] {
        let count = Int(pentagonCount())
        var raw = [UInt64](repeating: 0, count: count)
        getPentagons(Int32(resolution), &raw)
        return raw.map { H3Index($0) }
    }

}

// MARK: - Boundary

extension H3Index {

    /// Returns the cell boundary as an ordered array of geographic coordinates
    /// in counter-clockwise order.
    public func boundary() -> [H3Coordinate] {
        var cb = CellBoundary()
        cellToBoundary(value, &cb)
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

extension H3Index: CustomStringConvertible {

    /// The lowercase hex string representation, e.g. `"842a107ffffffff"`.
    public var description: String {
        let bufferSize = 17
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        h3ToString(value, buffer, bufferSize)
        return String(cString: buffer)
    }

}

// MARK: - Equatable, Hashable

extension H3Index: Equatable, Hashable {}
