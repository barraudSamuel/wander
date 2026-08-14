//
//  AuthenticationView.swift
//  wander
//

import AuthenticationServices
import SwiftUI

struct AuthenticationView: View {
    @ObservedObject var authenticationService: FirebaseService

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("WelcomeForest")
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                    .clipped()
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.02), location: 0),
                        .init(color: .black.opacity(0.10), location: 0.38),
                        .init(color: .black.opacity(0.68), location: 0.68),
                        .init(color: .black.opacity(0.92), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .accessibilityHidden(true)

                ScrollView {
                    VStack(spacing: 24) {
                        Spacer(minLength: 160)

                        welcomeCopy

                        authenticationActions
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: geometry.size.height,
                        alignment: .bottom
                    )
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    private var welcomeCopy: some View {
        VStack(spacing: 10) {
            Text("Bienvenue sur Wander")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(
                "Connecte-toi avec ton compte Apple pour retrouver "
                    + "ton profil et partager tes explorations "
                    + "en toute sécurité."
            )
            .foregroundStyle(.white.opacity(0.90))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 440)
    }

    private var authenticationActions: some View {
        VStack(spacing: 16) {
            if let errorMessage = authenticationService.authErrorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Erreur : \(errorMessage)")
            }

            if authenticationService.isSigningIn {
                ProgressView("Connexion…")
                    .tint(.white)
                    .foregroundStyle(.white)
            }

            if authenticationService.requiresExistingAccountConfirmation {
                existingAccountConfirmation
            } else {
                SignInWithAppleButton(.continue) { request in
                    authenticationService.prepareAppleAuthorizationRequest(request)
                } onCompletion: { result in
                    authenticationService.handleAppleAuthorizationCompletion(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .disabled(authenticationService.isSigningIn)
                .accessibilityHint(
                    "Ouvre la feuille de connexion sécurisée Apple"
                )
            }

            migrationExplanation
        }
        .frame(maxWidth: 440)
    }

    private var existingAccountConfirmation: some View {
        VStack(spacing: 12) {
            Text("Ce compte Apple utilise déjà Wander")
                .font(.headline)
                .foregroundStyle(.white)

            Text(
                "Le profil et les amis du compte anonyme ne peuvent pas être "
                    + "fusionnés automatiquement avec le profil Apple existant. "
                    + "Les données locales de cet appareil, dont tes explorations, "
                    + "seront ajoutées au profil Apple choisi."
            )
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.86))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Button("Utiliser ce profil Apple") {
                authenticationService.continueWithExistingAppleAccount()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.white)
            .foregroundStyle(.black)

            Button("Annuler", role: .cancel) {
                authenticationService.cancelExistingAppleAccountSignIn()
            }
            .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var migrationExplanation: some View {
        if authenticationService.hasLegacyAnonymousAccount {
            Text(
                "En continuant, Wander tentera d’associer à ton compte Apple "
                    + "les données déjà créées sur cet appareil."
            )
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.78))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 340)
        } else {
            Text(
                "En continuant, les données locales de cet appareil, dont tes "
                    + "explorations, seront associées au compte Apple utilisé. "
                    + "Wander ne prend en charge aucun autre mode de connexion."
            )
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.78))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 340)
        }
    }
}
