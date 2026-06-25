//
//  OnboardingView.swift
//  wander
//
//  Created by Codex on 18/06/2026.
//

import PhotosUI
import SwiftUI
import UIKit

struct OnboardingView: View {
    @AppStorage("profile.displayName") private var storedDisplayName = ""
    @AppStorage("profile.avatarImageData") private var avatarImageData = Data()
    @AppStorage("profile.onboardingCompleted") private var onboardingCompleted = false

    @State private var displayName = ""
    @State private var selectedPhoto: PhotosPickerItem?

    private var trimmedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canContinue: Bool {
        !trimmedDisplayName.isEmpty
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 24)

            VStack(spacing: 18) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    ProfileAvatarView(imageData: avatarImageData, size: 112)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 34, height: 34)
                                .background(Color.green)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(.background, lineWidth: 3))
                        }
                }
                .buttonStyle(.plain)

                VStack(spacing: 8) {
                    Text("Bienvenue")
                        .font(.largeTitle.bold())

                    Text("Choisis ton pseudo et une photo pour personnaliser ton exploration.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Pseudo")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                TextField("Ton pseudo", text: $displayName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onSubmit(completeOnboarding)
            }

            Button(action: completeOnboarding) {
                Text("Commencer")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(!canContinue)

            Spacer(minLength: 24)
        }
        .padding(.horizontal, 24)
        .background {
            LinearGradient(
                colors: [
                    Color.green.opacity(0.16),
                    Color(uiColor: .systemBackground),
                    Color(uiColor: .systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .onAppear {
            displayName = storedDisplayName
        }
        .onChange(of: selectedPhoto) { _, newPhoto in
            loadAvatar(from: newPhoto)
        }
    }

    private func completeOnboarding() {
        guard canContinue else { return }

        storedDisplayName = trimmedDisplayName

        withAnimation(.easeInOut(duration: 0.25)) {
            onboardingCompleted = true
        }
    }

    private func loadAvatar(from item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            guard
                let data = try? await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data),
                let jpegData = image.preparingThumbnail(of: CGSize(width: 360, height: 360))?.jpegData(compressionQuality: 0.82)
            else { return }

            await MainActor.run {
                avatarImageData = jpegData
            }
        }
    }
}

struct ProfileAvatarView: View {
    let imageData: Data
    let size: CGFloat

    var body: some View {
        Group {
            if let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .padding(size * 0.1)
            }
        }
        .frame(width: size, height: size)
        .background(.ultraThinMaterial)
        .clipShape(Circle())
        .contentShape(Circle())
    }
}
