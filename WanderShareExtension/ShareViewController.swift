//
//  ShareViewController.swift
//  WanderShareExtension
//

import SwiftUI
import UIKit

@MainActor
final class ShareViewController: UIViewController {
    private var hostingController: UIHostingController<ShareComposerView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        let inputItems = extensionContext?.inputItems.compactMap {
            $0 as? NSExtensionItem
        } ?? []
        let content = ShareComposerView(
            inputItems: inputItems,
            onCancel: { [weak self] in
                self?.cancelExtension()
            },
            onComplete: { [weak self] in
                self?.extensionContext?.completeRequest(
                    returningItems: nil
                )
            }
        )
        let hostingController = UIHostingController(rootView: content)
        self.hostingController = hostingController

        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .systemBackground
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
    }

    private func cancelExtension() {
        extensionContext?.cancelRequest(
            withError: NSError(
                domain: NSCocoaErrorDomain,
                code: NSUserCancelledError
            )
        )
    }
}
