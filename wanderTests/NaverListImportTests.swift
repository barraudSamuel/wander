import Foundation
import XCTest
@testable import wander

@MainActor
final class NaverListImportTests: XCTestCase {
    private let listURL = "https://map.naver.com/p/favorite/sharedPlace/folder/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

    func testSharedTextAndSupportedPaths() throws {
        XCTAssertEqual(try NaverListImporter.parseURL("[NAVER Maps]\nCafé\nhttps://naver.me/example").host, "naver.me")
        for url in [listURL, listURL.replacingOccurrences(of: "/p/", with: "/v5/"),
                    "https://pages.map.naver.com/save-pages/pc/detail-list/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"] {
            XCTAssertEqual(NaverListImporter.shareID(in: try NaverListImporter.parseURL(url)), String(repeating: "a", count: 32))
        }
    }

    func testRejectsNonNaverHostsCredentialsPortsAndNonListLinks() {
        for input in ["https://evil.test/a", "https://naver.me.evil.test/a", "http://naver.me/a",
                      "https://user:password@naver.me/a", "https://naver.me:8443/a", "https://map.naver.com/p/entry/place/123",
                      "https://naver.me/a https://naver.me/b", "rien"] {
            XCTAssertThrowsError(try NaverListImporter.parseURL(input))
        }
    }

    func testLoadsEveryPageAndPreservesWarnings() async throws {
        let list = try await importer("pagination").load(listURL)
        XCTAssertEqual(list.name, "Synthetic list")
        XCTAssertEqual(list.places.count, 3)
        XCTAssertEqual(list.places.map(\.id), ["place:1", "place:2", "place:3"])
        XCTAssertEqual(list.places.map(\.categoryCode), ["CAFE", "DINING", "UNKNOWN"])
        XCTAssertEqual(list.places.map(\.categorySymbol), ["cup.and.saucer", "fork.knife", "mappin"])
        XCTAssertEqual(list.places.map { NaverPlaceCategory.label(for: $0.categoryCode, name: $0.categoryName) },
                       ["Café", "Restaurant", "미술관"])
        XCTAssertTrue(list.places[0].isUnavailable)
        XCTAssertTrue(list.places[0].hasLocationWarning)
        XCTAssertEqual(list.places[0].latitude, 37)
        XCTAssertEqual(list.places[0].longitude, 127)
        XCTAssertEqual(list.places[0].naverURL.absoluteString, "https://map.naver.com/p/entry/place/1")
    }

    func testResolvesShortLinkAndRejectsExternalRedirect() async throws {
        let list = try await importer("short").load("https://naver.me/example")
        XCTAssertEqual(list.places.count, 1)
        await assertFailure("external", input: "https://naver.me/example")
    }

    func testRejectsPartialChangingDuplicateAndInvalidResponses() async {
        for scenario in ["empty-page", "changed-count", "duplicate", "bad-coordinate", "private", "malformed"] {
            await assertFailure(scenario)
        }
    }

    func testAddressBookmarkHasStableFallback() async throws {
        let list = try await importer("address").load(listURL)
        XCTAssertEqual(list.places[0].id, "bookmark:1")
        XCTAssertEqual(list.places[0].address, "")
        XCTAssertNil(list.places[0].categoryCode)
        XCTAssertNil(list.places[0].categoryName)
        XCTAssertEqual(NaverPlaceCategory.label(for: nil, name: "  "), "Adresse")
        XCTAssertEqual(list.places[0].categorySymbol, "mappin")
        XCTAssertTrue(list.places[0].naverURL.absoluteString.contains("sharedPlace/folder/"))
    }

    func testUnavailablePlaceDoesNotImplyChangedPosition() async throws {
        let list = try await importer("unavailable").load(listURL)
        XCTAssertTrue(list.places[0].isUnavailable)
        XCTAssertFalse(list.places[0].hasLocationWarning)
    }

    func testCancelledLoadDoesNotReturnResults() async {
        let client = importer("pagination")
        let input = listURL
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await client.load(input)
        }
        do {
            _ = try await task.value
            XCTFail("Cancelled import must fail")
        } catch {
            XCTAssertTrue(error is CancellationError || (error as? URLError)?.code == .cancelled)
        }
    }

    private func importer(_ scenario: String) -> NaverListImporter {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NaverFixtureProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Fixture": scenario]
        return NaverListImporter(configuration: configuration)
    }

    private func assertFailure(_ scenario: String, input: String? = nil) async {
        do {
            _ = try await importer(scenario).load(input ?? listURL)
            XCTFail("Expected import to reject \(scenario)")
        } catch { XCTAssertTrue(error is NaverListImportError, "Unexpected error: \(error)") }
    }
}

private nonisolated final class NaverFixtureProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let url = request.url!
        let scenario = request.value(forHTTPHeaderField: "X-Fixture") ?? "pagination"
        let start = Int(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "start" }?.value ?? "0") ?? 0
        if url.host == "naver.me" {
            let target = scenario == "external" ? "https://evil.test/list" : "https://map.naver.com/p/favorite/myPlace/folder/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
            respond(status: 302, headers: ["Location": target], data: Data())
            return
        }
        if scenario == "private" { respond(status: 403, data: Data()); return }
        if scenario == "malformed" { respond(data: Data("{}".utf8)); return }
        let paginated = ["pagination", "empty-page", "changed-count", "duplicate"].contains(scenario)
        var ids = paginated ? (start == 0 ? [1, 2] : [3]) : [1]
        if scenario == "empty-page" && start > 0 { ids = [] }
        if scenario == "duplicate" && start > 0 { ids = [1] }
        let count = scenario == "changed-count" && start > 0 ? 4 : (paginated ? 3 : 1)
        let entries: [[String: Any]] = ids.map { id in
            ["bookmarkId": id, "name": "Synthetic café \(id)", "displayName": "", "px": 127,
             "py": scenario == "bad-coordinate" ? 100 : 37, "type": scenario == "address" ? "address" : "place",
             "sid": "\(id)", "address": NSNull(), "available": id != 1,
             "mcid": scenario == "address" ? NSNull() : [1: "CAFE", 2: "DINING"][id] ?? "UNKNOWN",
             "mcidName": scenario == "address" ? NSNull() : [1: "카페", 2: "음식점"][id] ?? "미술관",
             "bookmarkMismatchInfo": ["isMatched": id != 1,
                                      "details": id != 1 ? ["AVAILABLE"]
                                        : scenario == "unavailable" ? ["UNAVAILABLE"] : ["GEOMETRY"]]]
        }
        let payload: [String: Any] = ["folder": ["name": "Synthetic list", "bookmarkCount": count],
                                      "bookmarkList": entries, "removed": false]
        respond(data: try! JSONSerialization.data(withJSONObject: payload))
    }

    private func respond(status: Int = 200, headers: [String: String] = [:], data: Data) {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}
