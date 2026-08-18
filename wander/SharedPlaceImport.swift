//
//  SharedPlaceImport.swift
//  wander
//

import CoreLocation
import Foundation
import LinkPresentation
import MapKit
import UniformTypeIdentifiers

struct SharedPlaceInput {
    let url: URL?
    let text: String?
}

struct ResolvedSharedPlace {
    let placeName: String
    let address: String?
    let coordinate: CLLocationCoordinate2D
}

enum SharedPlaceImportError: LocalizedError {
    case missingInput
    case unsupportedInput
    case unresolvedPlace

    var errorDescription: String? {
        switch self {
        case .missingInput:
            return "Aucun lieu n’a été reçu."
        case .unsupportedInput:
            return "Ce partage ne contient ni lien ni texte exploitable."
        case .unresolvedPlace:
            return "Wander n’a pas réussi à retrouver ce lieu. Réessaie depuis sa fiche Naver."
        }
    }
}

enum SharedPlaceInputLoader {
    static func load(from items: [NSExtensionItem]) async throws -> SharedPlaceInput {
        let providers = items.flatMap { $0.attachments ?? [] }
        guard !providers.isEmpty else {
            throw SharedPlaceImportError.missingInput
        }

        var resolvedURL: URL?
        var resolvedText: String?

        for provider in providers {
            if resolvedURL == nil,
               provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
               let item = try? await loadItem(
                   from: provider,
                   typeIdentifier: UTType.url.identifier
               ) {
                resolvedURL = url(from: item)
            }

            if resolvedText == nil,
               provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
               let item = try? await loadItem(
                   from: provider,
                   typeIdentifier: UTType.plainText.identifier
               ) {
                resolvedText = normalizedText(from: item)
            }

            if resolvedURL != nil, resolvedText != nil {
                break
            }
        }

        guard resolvedURL != nil || resolvedText != nil else {
            throw SharedPlaceImportError.unsupportedInput
        }
        if resolvedURL == nil, let resolvedText {
            resolvedURL = embeddedWebURL(in: resolvedText)
        }
        return SharedPlaceInput(url: resolvedURL, text: resolvedText)
    }

    private static func loadItem(
        from provider: NSItemProvider,
        typeIdentifier: String
    ) async throws -> NSSecureCoding? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(
                forTypeIdentifier: typeIdentifier,
                options: nil
            ) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: item)
                }
            }
        }
    }

    private static func url(from item: NSSecureCoding) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let value = item as? String {
            return URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    private static func normalizedText(from item: NSSecureCoding) -> String? {
        guard let value = item as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func embeddedWebURL(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range)
            .compactMap(\.url)
            .first { url in
                guard let scheme = url.scheme?.lowercased() else { return false }
                return scheme == "https" || scheme == "http"
            }
    }
}

@MainActor
final class SharedPlaceResolver {
    func resolve(_ input: SharedPlaceInput) async throws -> ResolvedSharedPlace {
        let finalURL = await resolvedURL(from: input.url)
        let sharedTextDetails = placeDetails(from: input.text)

        if let coordinate = coordinate(from: finalURL ?? input.url) {
            return await place(
                at: coordinate,
                fallbackName: sharedTextDetails.name
                    ?? queryValue(named: ["name", "title"], in: finalURL ?? input.url),
                fallbackAddress: sharedTextDetails.address
            )
        }

        let metadataTitle = await metadataTitle(for: finalURL ?? input.url)
        let candidate = searchCandidate(
            text: input.text,
            metadataTitle: metadataTitle,
            url: finalURL ?? input.url
        )

        guard let candidate else {
            throw SharedPlaceImportError.unresolvedPlace
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = candidate
        let response = try await localSearch(request)
        guard let mapItem = response.mapItems.first,
              CLLocationCoordinate2DIsValid(mapItem.location.coordinate) else {
            throw SharedPlaceImportError.unresolvedPlace
        }

        return ResolvedSharedPlace(
            placeName: placeName(for: mapItem, fallback: candidate),
            address: formattedAddress(for: mapItem),
            coordinate: mapItem.location.coordinate
        )
    }

    private func resolvedURL(from url: URL?) async -> URL? {
        guard let url,
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            return url
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 15
        let session = URLSession(
            configuration: configuration,
            delegate: RedirectBlockingURLSessionDelegate(),
            delegateQueue: nil
        )
        var currentURL = url

        for _ in 0..<5 {
            var request = URLRequest(url: currentURL)
            request.httpMethod = "GET"

            guard let (_, response) = try? await session.data(for: request),
                  let httpResponse = response as? HTTPURLResponse,
                  let location = httpResponse.value(forHTTPHeaderField: "Location"),
                  let redirectedURL = URL(
                      string: location,
                      relativeTo: currentURL
                  )?.absoluteURL,
                  redirectedURL != currentURL else {
                return currentURL
            }

            if coordinate(from: redirectedURL) != nil {
                return redirectedURL
            }
            currentURL = redirectedURL
        }
        return currentURL
    }

    private func metadataTitle(for url: URL?) async -> String? {
        guard let url else { return nil }
        return await withCheckedContinuation { continuation in
            let provider = LPMetadataProvider()
            provider.timeout = 8
            provider.startFetchingMetadata(for: url) { metadata, _ in
                let title = metadata?.title?.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                continuation.resume(
                    returning: title?.isEmpty == false ? title : nil
                )
            }
        }
    }

    private func coordinate(from url: URL?) -> CLLocationCoordinate2D? {
        guard let url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let values = (components.queryItems ?? []).reduce(
            into: [String: String]()
        ) { result, item in
            guard let value = item.value else { return }
            result[item.name.lowercased()] = value
        }
        let pairs = [
            ("latitude", "longitude"),
            ("lat", "lng"),
            ("lat", "lon")
        ]

        for (latitudeKey, longitudeKey) in pairs {
            guard let latitudeValue = values[latitudeKey],
                  let longitudeValue = values[longitudeKey],
                  let latitude = Double(latitudeValue),
                  let longitude = Double(longitudeValue) else {
                continue
            }

            let coordinate = CLLocationCoordinate2D(
                latitude: latitude,
                longitude: longitude
            )
            if CLLocationCoordinate2DIsValid(coordinate) {
                return coordinate
            }
        }
        return nil
    }

    private func searchCandidate(
        text: String?,
        metadataTitle: String?,
        url: URL?
    ) -> String? {
        let textLines = meaningfulTextLines(in: text)

        if !textLines.isEmpty {
            return String(textLines.joined(separator: " ").prefix(240))
        }

        if let metadataTitle,
           !isGenericNaverTitle(metadataTitle) {
            return String(metadataTitle.prefix(240))
        }

        let queryName = queryValue(
            named: ["name", "title", "address", "query"],
            in: url
        )

        guard let queryName, !queryName.isEmpty else { return nil }
        return String(queryName.prefix(240))
    }

    private func placeDetails(from text: String?) -> (name: String?, address: String?) {
        let lines = meaningfulTextLines(in: text)
        return (
            lines.first,
            lines.dropFirst().first
        )
    }

    private func meaningfulTextLines(in text: String?) -> [String] {
        text?
            .split(whereSeparator: { $0.isNewline })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                !line.isEmpty
                    && URL(string: line)?.scheme == nil
                    && !isGenericNaverTitle(line)
            } ?? []
    }

    private func queryValue(named names: Set<String>, in url: URL?) -> String? {
        URLComponents(
            url: url ?? URL(fileURLWithPath: "/"),
            resolvingAgainstBaseURL: false
        )?
        .queryItems?
        .first(where: { names.contains($0.name.lowercased()) })?
        .value?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isGenericNaverTitle(_ value: String) -> Bool {
        let surroundingCharacters = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: "[]【】"))
        let normalized = value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: surroundingCharacters)
        return normalized == "naver map"
            || normalized == "네이버 지도"
            || normalized == "naver"
    }

    private func localSearch(_ request: MKLocalSearch.Request) async throws -> MKLocalSearch.Response {
        let search = MKLocalSearch(request: request)
        return try await withCheckedThrowingContinuation { continuation in
            search.start { response, error in
                if let response {
                    continuation.resume(returning: response)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: SharedPlaceImportError.unresolvedPlace)
                }
            }
        }
    }

    private func place(
        at coordinate: CLLocationCoordinate2D,
        fallbackName: String?,
        fallbackAddress: String?
    ) async -> ResolvedSharedPlace {
        let location = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return ResolvedSharedPlace(
                placeName: fallbackName ?? "Lieu partagé",
                address: fallbackAddress,
                coordinate: coordinate
            )
        }

        let mapItem = await withCheckedContinuation { continuation in
            request.getMapItems { mapItems, _ in
                continuation.resume(returning: mapItems?.first)
            }
        }
        guard let mapItem else {
            return ResolvedSharedPlace(
                placeName: fallbackName ?? "Lieu partagé",
                address: fallbackAddress,
                coordinate: coordinate
            )
        }
        return ResolvedSharedPlace(
            placeName: fallbackName.map {
                String($0.prefix(OutingPlan.maximumPlaceNameLength))
            } ?? placeName(for: mapItem, fallback: nil),
            address: fallbackAddress.map {
                String($0.prefix(OutingPlan.maximumAddressLength))
            } ?? formattedAddress(for: mapItem),
            coordinate: coordinate
        )
    }

    private func placeName(for mapItem: MKMapItem, fallback: String?) -> String {
        let name = mapItem.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = name?.isEmpty == false ? name : fallback
        return String((resolved ?? "Lieu partagé").prefix(OutingPlan.maximumPlaceNameLength))
    }

    private func formattedAddress(for mapItem: MKMapItem) -> String? {
        let value = mapItem.addressRepresentations?.fullAddress(
            includingRegion: false,
            singleLine: true
        ) ?? mapItem.address?.fullAddress
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let normalized, !normalized.isEmpty else { return nil }
        return String(normalized.prefix(OutingPlan.maximumAddressLength))
    }
}

private final class RedirectBlockingURLSessionDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
