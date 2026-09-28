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

/// Keeps one map hierarchy beneath the system tab bar above the map.
struct NativeMapTabView<Content: View>: UIViewControllerRepresentable {
    let onExplore: () -> Void
    let isEventsPresented: Bool
    let onToggleEvents: () -> Void
    @State private var contentInsets = UIEdgeInsets.zero
    @ViewBuilder let content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(onExplore: onExplore, contentInsets: $contentInsets)
    }

    func makeUIViewController(context: Context) -> NativeMapTabController {
        let controller = NativeMapTabController(rootView: rootView(context: context))
        controller.delegate = context.coordinator
        controller.onToggleEvents = onToggleEvents
        controller.onContentInsetsChange = { [weak coordinator = context.coordinator] insets in
            coordinator?.contentInsets.wrappedValue = insets
        }
        controller.synchronizeEvents(isPresented: isEventsPresented)
        return controller
    }

    func updateUIViewController(_ controller: NativeMapTabController, context: Context) {
        context.coordinator.onExplore = onExplore
        context.coordinator.contentInsets = $contentInsets
        controller.onToggleEvents = onToggleEvents
        controller.updateContent(rootView(context: context))
        controller.synchronizeEvents(isPresented: isEventsPresented)
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

    final class Coordinator: NSObject, UITabBarControllerDelegate {
        var onExplore: () -> Void
        var contentInsets: Binding<UIEdgeInsets>

        init(onExplore: @escaping () -> Void, contentInsets: Binding<UIEdgeInsets>) {
            self.onExplore = onExplore
            self.contentInsets = contentInsets
        }

        func tabBarController(
            _ tabBarController: UITabBarController,
            didSelect viewController: UIViewController
        ) {
            onExplore()
        }
    }
}

final class NativeMapTabController: UIViewController {
    private let contentController: UIHostingController<AnyView>
    private let tabsController = CompactTabBarController()
    private let navigationContainer = TabBarHitTestingView()
    private let eventsController = UIHostingController(rootView: AnyView(EmptyView()))
    private var isEventsPresented = false
    private var eventsButton: UIView { eventsController.view }
    private var reportedContentInsets = UIEdgeInsets.zero
    var onContentInsetsChange: ((UIEdgeInsets) -> Void)?
    var onToggleEvents: (() -> Void)?

    var delegate: (any UITabBarControllerDelegate)? {
        get { tabsController.delegate }
        set { tabsController.delegate = newValue }
    }

    init(rootView: AnyView) {
        contentController = UIHostingController(rootView: rootView)
        // The map has its own full-width host, independent of the narrow tabs.
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
        // Keep the native tabs above the keyboard, including when its responder
        // belongs to the full-width content host rather than a selected tab.
        view.keyboardLayoutGuide.usesBottomSafeArea = false

        let exploreController = UIViewController()
        exploreController.view.backgroundColor = .clear
        let image = UIImage(named: "TabIconExplore")?.withRenderingMode(.alwaysOriginal)
        exploreController.tabBarItem = UITabBarItem(title: nil, image: image, selectedImage: image)
        exploreController.tabBarItem.accessibilityLabel = "Explorer"
        exploreController.tabBarItem.accessibilityIdentifier = "motion-dock-explore"
        tabsController.viewControllers = [exploreController]
        tabsController.tabBar.accessibilityIdentifier = "native-map-tab-bar"

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

        navigationContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navigationContainer)
        let preferredWidth = navigationContainer.widthAnchor.constraint(
            equalToConstant: 100
        )
        preferredWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            preferredWidth,
            navigationContainer.widthAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor, constant: -88
            ),
            navigationContainer.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor, constant: -31),
            navigationContainer.topAnchor.constraint(equalTo: view.topAnchor),
            navigationContainer.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        ])

        addChild(tabsController)
        tabsController.view.backgroundColor = .clear
        tabsController.view.translatesAutoresizingMaskIntoConstraints = false
        navigationContainer.addSubview(tabsController.view)
        NSLayoutConstraint.activate([
            tabsController.view.topAnchor.constraint(equalTo: navigationContainer.topAnchor),
            tabsController.view.bottomAnchor.constraint(equalTo: navigationContainer.bottomAnchor),
            tabsController.view.leadingAnchor.constraint(equalTo: navigationContainer.leadingAnchor),
            tabsController.view.trailingAnchor.constraint(equalTo: navigationContainer.trailingAnchor)
        ])
        navigationContainer.tabBar = tabsController.tabBar
        tabsController.onLayout = { [weak self] in self?.updateNavigationLayout() }
        tabsController.didMove(toParent: self)

        addChild(eventsController)
        eventsController.safeAreaRegions = []
        eventsButton.backgroundColor = .clear
        view.addSubview(eventsButton)
        eventsController.didMove(toParent: self)
        updateEventsButtonAppearance()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        updateNavigationLayout()
    }

    private func updateNavigationLayout() {
        let scale: CGFloat = 0.9
        // UIKit scales around the center. Offset that shrinkage to keep the
        // bottom edge at the keyboard guide without reading a transformed frame.
        let transform = CGAffineTransform(
            a: scale, b: 0, c: 0, d: scale,
            tx: 0, ty: navigationContainer.bounds.height * (1 - scale) / 2
        )
        if navigationContainer.transform != transform {
            navigationContainer.transform = transform
        }
        // Align to the native bar's control area, excluding its bottom safe area.
        let tabBar = tabsController.tabBar
        let controlsRect = CGRect(
            x: 0, y: 0, width: tabBar.bounds.width,
            height: max(0, tabBar.bounds.height - tabBar.safeAreaInsets.bottom)
        )
        let controlsFrame = tabBar.convert(controlsRect, to: view)
        if controlsFrame.height > 0 {
            let side = MapImageButton.side
            // Preserve the center of the previous 54 pt control while reducing
            // the image and hit area to 44 pt, aligned with the native tabs.
            let centerOffset: CGFloat = 27
            eventsButton.bounds = CGRect(x: 0, y: 0, width: side, height: side)
            eventsButton.center = CGPoint(
                x: controlsFrame.maxX + centerOffset,
                y: controlsFrame.minY + centerOffset
            )
        }
        reportContentInsets()
    }

    private func reportContentInsets() {
        let safeFrame = view.safeAreaLayoutGuide.layoutFrame
        let tabBar = tabsController.tabBar
        let tabBarFrame = tabBar.convert(tabBar.bounds, to: view)
        guard tabBarFrame.height > 0 else { return }
        // The content guide ends below the floating bar's top edge.
        let buttonTop = eventsButton.bounds.height > 0
            ? eventsButton.center.y - eventsButton.bounds.height / 2 - 8
            : safeFrame.maxY
        let bottom = min(
            safeFrame.maxY, tabBarFrame.minY, buttonTop,
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
                assetName: "TabIconEvents", label: "Événements",
                isSelected: isEventsPresented
            ) { [weak self] in
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


}

/// Report the system's final tab layout without modifying its internal views.
private final class CompactTabBarController: UITabBarController {
    var onLayout: (() -> Void)?

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        onLayout?()
    }
}

/// Only the system bar intercepts touches; the map and panels remain interactive.
private final class TabBarHitTestingView: UIView {
    weak var tabBar: UITabBar?

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let tabBar, !tabBar.isHidden, tabBar.alpha > 0.01,
              tabBar.isUserInteractionEnabled else { return false }
        return tabBar.point(inside: convert(point, to: tabBar), with: event)
    }
}
