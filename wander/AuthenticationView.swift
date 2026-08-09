//
//  AuthenticationView.swift
//  wander
//

import AuthenticationServices
import SwiftUI

struct AuthenticationView: View {
    @ObservedObject var authenticationService: FirebaseService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "map.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)

                    VStack(spacing: 10) {
                        Text("Bienvenue sur Wander")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)

                        Text(
                            "Connecte-toi avec ton compte Apple pour retrouver "
                                + "ton profil et partager tes explorations "
                                + "en toute sécurité."
                        )
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    authenticationActions
                }
                .padding(24)
                .frame(
                    maxWidth: .infinity,
                    minHeight: geometry.size.height
                )
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var authenticationActions: some View {
        VStack(spacing: 16) {
            if let errorMessage = authenticationService.authErrorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Erreur : \(errorMessage)")
            }

            if authenticationService.isSigningIn {
                ProgressView("Connexion…")
            }

            if authenticationService.requiresExistingAccountConfirmation {
                existingAccountConfirmation
            } else {
                SignInWithAppleButton(.continue) { request in
                    authenticationService.prepareAppleAuthorizationRequest(request)
                } onCompletion: { result in
                    authenticationService.handleAppleAuthorizationCompletion(result)
                }
                .signInWithAppleButtonStyle(
                    colorScheme == .dark ? .white : .black
                )
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

            Text(
                "Le profil et les amis du compte anonyme ne peuvent pas être "
                    + "fusionnés automatiquement avec le profil Apple existant. "
                    + "Les données locales de cet appareil, dont tes explorations, "
                    + "seront ajoutées au profil Apple choisi."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Button("Utiliser ce profil Apple") {
                authenticationService.continueWithExistingAppleAccount()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Annuler", role: .cancel) {
                authenticationService.cancelExistingAppleAccountSignIn()
            }
        }
    }

    @ViewBuilder
    private var migrationExplanation: some View {
        if authenticationService.hasLegacyAnonymousAccount {
            Text(
                "En continuant, Wander tentera d’associer à ton compte Apple "
                    + "les données déjà créées sur cet appareil."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(
                "En continuant, les données locales de cet appareil, dont tes "
                    + "explorations, seront associées au compte Apple utilisé. "
                    + "Wander ne prend en charge aucun autre mode de connexion."
            )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
