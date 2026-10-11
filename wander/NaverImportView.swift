import SwiftData
import SwiftUI
import UIKit

struct NaverImportView: View {
    let ownerID: String
    var loadList: (String) async throws -> NaverImportedList = {
        try await NaverListImporter().load($0)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @FocusState private var linkIsFocused: Bool
    @State private var link = ""
    @State private var preview: NaverImportedList?
    @State private var importedCount: Int?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if let importedCount {
                    ContentUnavailableView {
                        Label("Import terminé", systemImage: "checkmark.circle")
                    } description: {
                        Text(importedCount == 0
                             ? "Tes adresses étaient déjà importées. Elles ont été mises à jour."
                             : "\(importedCount) nouvelles adresses enregistrées sur cet appareil.")
                    }
                    .accessibilityIdentifier("naver-import-success")
                } else if let preview {
                    previewList(preview)
                } else {
                    inputForm
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar {
                if preview != nil && importedCount == nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Retour", systemImage: "chevron.left") {
                            preview = nil
                            errorMessage = nil
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer", systemImage: "xmark") { dismiss() }
                        .accessibilityIdentifier("naver-import-close")
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("naver-import-error")
                    }
                    primaryButton
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .buttonBorderShape(.capsule)
                }
                .padding()
                .background(.regularMaterial)
            }
        }
        .onDisappear { loadTask?.cancel() }
    }

    private var inputForm: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image("NaverMapLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .clipShape(.rect(cornerRadius: 20))
                    .accessibilityLabel("Naver Map")

                Text("Colle le lien de ta liste Naver")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("Dans Naver, partage ta liste puis copie son lien.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    TextField("Lien de la liste Naver", text: $link,
                              prompt: Text(verbatim: "https://naver.me/…").foregroundStyle(.secondary))
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .focused($linkIsFocused)
                        .accessibilityLabel("Lien de la liste Naver")
                        .accessibilityIdentifier("naver-import-link")
                        .onSubmit { startLoading() }
                    PasteButton(payloadType: String.self) { values in
                        guard let value = values.first else { return }
                        link = value
                        errorMessage = nil
                    }
                    .accessibilityIdentifier("naver-import-paste")
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                .disabled(isLoading)

                Text("La liste doit être publique ou accessible par lien. Tes adresses restent privées dans Wander, sur cet appareil.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: link) { _, _ in errorMessage = nil }
    }

    private func previewList(_ list: NaverImportedList) -> some View {
        List {
            Section {
                Text(list.name).font(.title2.bold())
                Text(list.places.count == 1 ? "1 adresse à importer" : "\(list.places.count) adresses à importer")
                    .accessibilityIdentifier("naver-import-count")
                Text("Les adresses déjà présentes seront mises à jour sans doublon.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Adresses") {
                ForEach(list.places) { place in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: place.categorySymbol)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(place.name)
                            Text(place.address).font(.caption).foregroundStyle(.secondary)
                            if place.isUnavailable {
                                Label("Lieu signalé indisponible par Naver", systemImage: "exclamationmark.triangle")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                            if place.hasLocationWarning {
                                Label("Position à vérifier sur Naver", systemImage: "mappin.slash")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
        }
    }

    private var primaryButton: some View {
        Button {
            if importedCount != nil {
                dismiss()
            } else if let preview {
                do {
                    importedCount = try SavedPlace.importList(preview, ownerID: ownerID, into: modelContext)
                } catch {
                    errorMessage = "Impossible d’enregistrer les adresses. Réessaie."
                }
            } else {
                startLoading()
            }
        } label: {
            Group {
                if isLoading {
                    HStack {
                        ProgressView().tint(.white)
                        Text("Chargement de la liste…")
                    }
                } else {
                    Text(importedCount != nil ? "Voir sur la carte"
                         : preview != nil ? "Enregistrer les adresses" : "Importer la liste")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(isLoading || (preview == nil && importedCount == nil
                               && link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
        .accessibilityIdentifier("naver-import-submit")
    }

    private func startLoading() {
        let input = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, !isLoading else { return }
        linkIsFocused = false
        errorMessage = nil
        isLoading = true
        loadTask = Task {
            defer { isLoading = false }
            do {
                let list = try await loadList(input)
                try Task.checkCancellation()
                guard !list.places.isEmpty else {
                    errorMessage = "Cette liste ne contient aucune adresse à importer."
                    return
                }
                preview = list
            } catch is CancellationError {
                // Closing the sheet cancels the pending import.
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = (error as? NaverListImportError)?.errorDescription
                    ?? "Impossible de charger la liste. Vérifie ta connexion et réessaie."
            }
        }
    }
}
