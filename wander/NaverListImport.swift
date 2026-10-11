import Foundation

nonisolated struct NaverImportedPlace: Identifiable, Sendable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let naverURL: URL
    let isUnavailable: Bool
    let hasLocationWarning: Bool
    var categoryCode: String? = nil
    var categoryName: String? = nil

    var categorySymbol: String {
        NaverPlaceCategory.symbol(for: categoryCode)
    }
}

nonisolated enum NaverPlaceCategory {
    static func symbol(for code: String?) -> String {
        switch code {
        case "CAFE": "cup.and.saucer"
        case "DINING": "fork.knife"
        default: "mappin"
        }
    }

    static func label(for code: String?, name: String?) -> String {
        switch code {
        case "CAFE": return "Café"
        case "DINING": return "Restaurant"
        default:
            let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? "Adresse" : trimmed
        }
    }
}

nonisolated struct NaverImportedList: Sendable {
    let name: String
    let places: [NaverImportedPlace]
}

nonisolated enum NaverListImportError: LocalizedError {
    case invalidLink, inaccessible, invalidData, incompleteList

    var errorDescription: String? {
        switch self {
        case .invalidLink: "Colle le lien de partage d’une liste Naver Map."
        case .inaccessible: "Cette liste est inaccessible. Vérifie qu’elle est publique ou accessible par lien."
        case .invalidData: "Naver a renvoyé des lieux incomplets ou des positions invalides. Aucun lieu n’a été importé."
        case .incompleteList: "La liste n’a pas pu être récupérée entièrement. Réessaie avant de l’importer."
        }
    }
}

nonisolated struct NaverListImporter {
    private let configuration: URLSessionConfiguration

    init(configuration: URLSessionConfiguration = .ephemeral) {
        self.configuration = configuration
    }

    static func parseURL(_ text: String) throws -> URL {
        let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let links = detector.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap(\.url)
        guard links.count == 1, let url = links.first, isAllowedURL(url),
              url.host == "naver.me" || shareID(in: url) != nil else {
            throw NaverListImportError.invalidLink
        }
        return url
    }

    func load(_ text: String) async throws -> NaverImportedList {
        let settings = configuration.copy() as! URLSessionConfiguration
        settings.httpCookieStorage = nil
        settings.httpShouldSetCookies = false
        settings.urlCredentialStorage = nil
        settings.urlCache = nil
        settings.timeoutIntervalForRequest = 20
        settings.timeoutIntervalForResource = 60
        let session = URLSession(configuration: settings, delegate: NaverRedirectBlocker(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var url = try Self.parseURL(text)
        // Resolve short links manually so no request can leave the Naver allowlist.
        for _ in 0..<5 where Self.shareID(in: url) == nil {
            try Task.checkCancellation()
            let (_, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (300..<400).contains(http.statusCode),
                  let location = http.value(forHTTPHeaderField: "Location"),
                  let target = URL(string: location, relativeTo: url)?.absoluteURL,
                  Self.isAllowedURL(target),
                  target.host == "naver.me" || Self.shareID(in: target) != nil else {
                throw NaverListImportError.inaccessible
            }
            url = target
        }
        guard let shareID = Self.shareID(in: url) else { throw NaverListImportError.invalidLink }
        var bookmarks: [Bookmark] = []
        var bookmarkIDs = Set<Int64>()
        var expectedCount: Int?
        var listName = ""
        repeat {
            try Task.checkCancellation()
            let endpoint = URL(string: "https://pages.map.naver.com/save-pages/api/maps-bookmark/v3/shares/\(shareID)/bookmarks?start=\(bookmarks.count)&limit=100&sort=lastUseTime&createIdNo=false")!
            let (data, response) = try await session.data(from: endpoint)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw NaverListImportError.inaccessible
            }
            let page: Page
            do { page = try JSONDecoder().decode(Page.self, from: data) }
            catch { throw NaverListImportError.invalidData }
            guard !page.removed, page.folder.bookmarkCount >= 0 else {
                throw NaverListImportError.inaccessible
            }
            if let expectedCount, expectedCount != page.folder.bookmarkCount {
                throw NaverListImportError.incompleteList
            }
            expectedCount = page.folder.bookmarkCount
            listName = page.folder.name
            for bookmark in page.bookmarkList {
                guard bookmarkIDs.insert(bookmark.bookmarkId).inserted else {
                    throw NaverListImportError.incompleteList
                }
                bookmarks.append(bookmark)
            }
            guard bookmarks.count <= page.folder.bookmarkCount,
                  !page.bookmarkList.isEmpty || bookmarks.count == page.folder.bookmarkCount else {
                throw NaverListImportError.incompleteList
            }
        } while bookmarks.count < (expectedCount ?? 0)
        try Task.checkCancellation()
        return NaverImportedList(name: listName, places: try bookmarks.map { try $0.place(shareID: shareID) })
    }

    static func isAllowedURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" && url.user == nil && url.password == nil
            && (url.port == nil || url.port == 443)
            && ["naver.me", "map.naver.com", "pages.map.naver.com"].contains(url.host?.lowercased() ?? "")
    }

    static func shareID(in url: URL) -> String? {
        guard isAllowedURL(url) else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        let candidate: String?
        if url.host == "map.naver.com", parts.count == 5,
           ["v5", "p"].contains(parts[0]), parts[1] == "favorite", parts[3] == "folder" {
            candidate = parts[4]
        } else if url.host == "pages.map.naver.com", parts.count == 4,
                  parts[0] == "save-pages", ["pc", "mobile"].contains(parts[1]), parts[2] == "detail-list" {
            candidate = parts[3]
        } else {
            candidate = nil
        }
        guard let candidate, candidate.range(of: "^[a-fA-F0-9]{32}$", options: .regularExpression) != nil else { return nil }
        return candidate
    }

    private struct Page: Decodable {
        let folder: Folder
        let bookmarkList: [Bookmark]
        let removed: Bool
    }

    private struct Folder: Decodable {
        let name: String
        let bookmarkCount: Int
    }

    private struct Bookmark: Decodable {
        let bookmarkId: Int64
        let name: String
        let displayName: String?
        let px: Double
        let py: Double
        let type: String
        let sid: String?
        let address: String?
        let available: Bool?
        let mcid: String?
        let mcidName: String?
        let bookmarkMismatchInfo: Mismatch?

        func place(shareID: String) throws -> NaverImportedPlace {
            let title = (displayName?.isEmpty == false ? displayName! : name).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, px.isFinite, py.isFinite, (-180...180).contains(px), (-90...90).contains(py) else {
                throw NaverListImportError.invalidData
            }
            let placeID = type == "place" ? sid.flatMap { $0.isEmpty ? nil : $0 } : nil
            let sourceID = placeID.map { "place:\($0)" } ?? "bookmark:\(bookmarkId)"
            let naverURL: URL
            if let placeID, placeID.range(of: "^[0-9]+$", options: .regularExpression) != nil {
                naverURL = URL(string: "https://map.naver.com/p/entry/place/\(placeID)")!
            } else {
                naverURL = URL(string: "https://map.naver.com/p/favorite/sharedPlace/folder/\(shareID)")!
            }
            return NaverImportedPlace(id: sourceID, name: title, address: address ?? "", latitude: py,
                                      longitude: px, naverURL: naverURL, isUnavailable: available == false,
                                      hasLocationWarning: bookmarkMismatchInfo?.details.contains("GEOMETRY") == true,
                                      categoryCode: mcid, categoryName: mcidName)
        }
    }

    private struct Mismatch: Decodable {
        let isMatched: Bool
        let details: [String]
    }
}

private nonisolated final class NaverRedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
