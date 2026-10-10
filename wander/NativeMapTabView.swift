import SwiftData
import SwiftUI
import UIKit

private struct MapNavigationBottomInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var mapNavigationBottomInset: CGFloat {
        get { self[MapNavigationBottomInsetKey.self] }
        set { self[MapNavigationBottomInsetKey.self] = newValue }
    }
}

/// Keeps one full-screen map hierarchy beneath the centered events button.
struct NativeMapTabView<Content: View>: UIViewControllerRepresentable {
    let isEventsPresented: Bool
    let onToggleEvents: () -> Void
    var mapActions: MapDockActions? = nil
    @State private var contentInsets = UIEdgeInsets.zero
    @ViewBuilder let content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(contentInsets: $contentInsets)
    }

    func makeUIViewController(context: Context) -> NativeMapTabController {
        let controller = NativeMapTabController(rootView: rootView(context: context))
        controller.onToggleEvents = onToggleEvents
        controller.onContentInsetsChange = { [weak coordinator = context.coordinator] insets in
            coordinator?.contentInsets.wrappedValue = insets
        }
        controller.synchronizeEvents(isPresented: isEventsPresented)
        controller.synchronizeMapActions(mapActions)
        return controller
    }

    func updateUIViewController(_ controller: NativeMapTabController, context: Context) {
        context.coordinator.contentInsets = $contentInsets
        controller.onToggleEvents = onToggleEvents
        controller.updateContent(rootView(context: context))
        controller.synchronizeEvents(isPresented: isEventsPresented)
        controller.synchronizeMapActions(mapActions)
    }

    private func rootView(context: Context) -> AnyView {
        AnyView(content()
            .environment(\.modelContext, context.environment.modelContext)
            .environment(\.mapNavigationBottomInset, contentInsets.bottom)
            .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: contentInsets.top) }
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: contentInsets.bottom) }
            .safeAreaInset(edge: .leading, spacing: 0) { Color.clear.frame(width: contentInsets.left) }
            .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: contentInsets.right) }
        )
    }

    final class Coordinator {
        var contentInsets: Binding<UIEdgeInsets>

        init(contentInsets: Binding<UIEdgeInsets>) {
            self.contentInsets = contentInsets
        }
    }
}

final class NativeMapTabController: UIViewController {
    private static let eventsButtonSide: CGFloat = 56
    private let contentController: UIHostingController<AnyView>
    private let eventsController = UIHostingController(rootView: AnyView(EmptyView()))
    private let createController = UIHostingController(rootView: AnyView(EmptyView()))
    private let recenterController = UIHostingController(rootView: AnyView(EmptyView()))
    private var isEventsPresented = false
    private var eventsButton: UIView { eventsController.view }
    private var reportedContentInsets = UIEdgeInsets.zero
    var onContentInsetsChange: ((UIEdgeInsets) -> Void)?
    var onToggleEvents: (() -> Void)?

    init(rootView: AnyView) {
        contentController = UIHostingController(rootView: rootView)
        // Insets change without resizing the map's full-screen host.
        contentController.safeAreaRegions = []
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        // The button follows the keyboard while also respecting the safe area.
        view.keyboardLayoutGuide.usesBottomSafeArea = false

        addChild(contentController)
        contentController.view.backgroundColor = .clear
        contentController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentController.view)
        NSLayoutConstraint.activate([
            contentController.view.topAnchor.constraint(equalTo: view.topAnchor),
            contentController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        contentController.didMove(toParent: self)

        addChild(eventsController)
        eventsController.safeAreaRegions = []
        eventsButton.backgroundColor = .clear
        eventsButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(eventsButton)
        let preferredBottom = eventsButton.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8
        )
        preferredBottom.priority = .defaultHigh
        NSLayoutConstraint.activate([
            eventsButton.widthAnchor.constraint(equalToConstant: Self.eventsButtonSide),
            eventsButton.heightAnchor.constraint(equalToConstant: Self.eventsButtonSide),
            eventsButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            preferredBottom,
            eventsButton.bottomAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8
            ),
            eventsButton.bottomAnchor.constraint(
                lessThanOrEqualTo: view.keyboardLayoutGuide.topAnchor, constant: -8
            )
        ])
        eventsController.didMove(toParent: self)
        updateEventsButtonAppearance()

        for controller in [createController, recenterController] {
            addChild(controller)
            controller.safeAreaRegions = []
            controller.sizingOptions = .intrinsicContentSize
            controller.view.backgroundColor = .clear
            controller.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(controller.view)
            controller.didMove(toParent: self)
        }
        NSLayoutConstraint.activate([
            createController.view.centerYAnchor.constraint(equalTo: eventsButton.centerYAnchor),
            createController.view.trailingAnchor.constraint(
                // Leave room for Mapbox's attribution control at the bottom right.
                equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -56
            ),
            recenterController.view.centerXAnchor.constraint(equalTo: createController.view.centerXAnchor),
            recenterController.view.bottomAnchor.constraint(
                equalTo: createController.view.topAnchor, constant: -12
            )
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        reportContentInsets()
    }

    private func reportContentInsets() {
        let safeFrame = view.safeAreaLayoutGuide.layoutFrame
        guard eventsButton.bounds.height > 0 else { return }
        let buttonTop = eventsButton.frame.minY - 8
        let bottom = min(
            safeFrame.maxY, buttonTop,
            view.keyboardLayoutGuide.layoutFrame.minY
        )
        let insets = UIEdgeInsets(
            top: max(0, safeFrame.minY),
            left: max(0, safeFrame.minX),
            bottom: max(0, view.bounds.maxY - bottom),
            right: max(0, view.bounds.maxX - safeFrame.maxX)
        )
        if insets != reportedContentInsets {
            reportedContentInsets = insets
            // UIKit can lay out while SwiftUI is updating the representable.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.onContentInsetsChange?(self.reportedContentInsets)
            }
        }
    }

    func synchronizeEvents(isPresented: Bool) {
        loadViewIfNeeded()
        guard isEventsPresented != isPresented else { return }
        isEventsPresented = isPresented
        updateEventsButtonAppearance()
    }

    private func updateEventsButtonAppearance() {
        eventsController.rootView = AnyView(
            MapImageButton(
                assetName: isEventsPresented ? "TabIconEventsClose" : "TabIconEvents",
                label: "Événements",
                isSelected: isEventsPresented,
                diameter: Self.eventsButtonSide
            ) { [weak self] in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                self?.onToggleEvents?()
            }
            .accessibilityIdentifier("motion-dock-events")
            .accessibilityValue(isEventsPresented ? "Liste affichée" : "Liste masquée")
            .accessibilityHint(isEventsPresented ? "Fermer la liste des événements" : "Afficher la liste des événements")
        )
    }

    func updateContent(_ content: AnyView) {
        contentController.rootView = content
    }

    func synchronizeMapActions(_ actions: MapDockActions?) {
        loadViewIfNeeded()
        createController.view.isHidden = actions == nil
        recenterController.view.isHidden = actions == nil
        guard let actions else { return }

        createController.rootView = AnyView(
            mapActionButton(
                symbol: "plus", label: "Créer", identifier: "map-create",
                isEnabled: actions.isCreationEnabled, action: actions.onCreate
            )
        )
        recenterController.rootView = AnyView(
            mapActionButton(
                symbol: "scope", label: "Recentrer la carte sur ma position", identifier: "map-recenter",
                isEnabled: true, action: actions.onRecenter
            )
        )
    }

    private func mapActionButton(
        symbol: String, label: String, identifier: String,
        isEnabled: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
        .disabled(!isEnabled)
        .fixedSize()
    }
}
