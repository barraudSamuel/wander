import SwiftData
import SwiftUI
import UIKit

/// Keeps one map hierarchy beneath the system tab bar while tabs select panels.
struct NativeMapTabView<Content: View>: UIViewControllerRepresentable {
    @Binding var selection: MotionDockSelection
    let isEventsPresented: Bool
    let onToggleEvents: () -> Void
    @State private var contentInsets = UIEdgeInsets.zero
    @ViewBuilder let content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection, contentInsets: $contentInsets)
    }

    func makeUIViewController(context: Context) -> NativeMapTabController {
        let controller = NativeMapTabController(rootView: rootView(context: context))
        controller.delegate = context.coordinator
        controller.onToggleEvents = onToggleEvents
        controller.onContentInsetsChange = { [weak coordinator = context.coordinator] insets in
            coordinator?.contentInsets.wrappedValue = insets
        }
        controller.synchronizeSelection(selection)
        controller.synchronizeEvents(isPresented: isEventsPresented)
        return controller
    }

    func updateUIViewController(_ controller: NativeMapTabController, context: Context) {
        context.coordinator.selection = $selection
        context.coordinator.contentInsets = $contentInsets
        controller.onToggleEvents = onToggleEvents
        controller.updateContent(rootView(context: context))
        controller.synchronizeSelection(selection)
        controller.synchronizeEvents(isPresented: isEventsPresented)
    }

    private func rootView(context: Context) -> AnyView {
        AnyView(content()
            .environment(\.modelContext, context.environment.modelContext)
            .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: contentInsets.top) }
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: contentInsets.bottom) }
            .safeAreaInset(edge: .leading, spacing: 0) { Color.clear.frame(width: contentInsets.left) }
            .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: contentInsets.right) }
        )
    }

    final class Coordinator: NSObject, UITabBarControllerDelegate {
        var selection: Binding<MotionDockSelection>
        var contentInsets: Binding<UIEdgeInsets>

        init(selection: Binding<MotionDockSelection>, contentInsets: Binding<UIEdgeInsets>) {
            self.selection = selection
            self.contentInsets = contentInsets
        }

        func tabBarController(
            _ tabBarController: UITabBarController,
            didSelect viewController: UIViewController
        ) {
            guard let controller = tabBarController.parent as? NativeMapTabController,
                  let index = tabBarController.viewControllers?.firstIndex(of: viewController),
                  MotionDockSelection.allCases.indices.contains(index) else { return }

            let tappedSelection = MotionDockSelection.allCases[index]
            selection.wrappedValue = selection.wrappedValue == tappedSelection
                ? .explore : tappedSelection

            // Account confirmations may reject a selection change in the binding.
            controller.synchronizeSelection(selection.wrappedValue)
        }
    }
}

final class NativeMapTabController: UIViewController {
    private static let eventsButtonSide: CGFloat = 54
    // Match the 40-point tab artwork after the navigation container's 0.9 scale.
    private static let eventsIconSide: CGFloat = 36
    private static let eventsIcon = UIImage(named: "TabIconEvents")?
        .preparingThumbnail(of: CGSize(width: eventsIconSide, height: eventsIconSide))?
        .withRenderingMode(.alwaysOriginal)

    private let contentController: UIHostingController<AnyView>
    private let tabsController = CompactTabBarController()
    private let navigationContainer = TabBarHitTestingView()
    private let eventsButton = UIButton(type: .system)
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

        tabsController.viewControllers = MotionDockSelection.allCases.map { selection in
            let controller = UIViewController()
            controller.view.backgroundColor = .clear
            let image = UIImage(named: selection.assetName)?.withRenderingMode(.alwaysOriginal)
            controller.tabBarItem = UITabBarItem(title: nil, image: image, selectedImage: image)
            controller.tabBarItem.accessibilityLabel = selection.title
            controller.tabBarItem.accessibilityIdentifier = "motion-dock-" + selection.rawValue
            return controller
        }
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
            equalTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 0.75
        )
        preferredWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            preferredWidth,
            navigationContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 320),
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

        eventsButton.accessibilityLabel = "Événements"
        eventsButton.accessibilityIdentifier = "motion-dock-events"
        eventsButton.addAction(UIAction { [weak self] _ in self?.onToggleEvents?() }, for: .touchUpInside)
        view.addSubview(eventsButton)
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
            let side = Self.eventsButtonSide
            // The floating bar's bounds extend below its visible capsule.
            // Keep a stable diameter at its top, independent of safe-area changes.
            // Glass can transform the button during interaction; setting frame
            // then would resize its bounds to compensate for that transform.
            eventsButton.bounds = CGRect(x: 0, y: 0, width: side, height: side)
            eventsButton.center = CGPoint(
                x: controlsFrame.maxX + side / 2,
                y: controlsFrame.minY + side / 2
            )
        }
        reportContentInsets()
    }

    private func reportContentInsets() {
        let safeFrame = view.safeAreaLayoutGuide.layoutFrame
        let navigationContentFrame = tabsController.view.convert(
            tabsController.contentLayoutGuide.layoutFrame, to: view
        )
        guard navigationContentFrame.height > 0 else { return }
        // Reserve the resting geometry, not the glass interaction's transformed frame.
        let buttonTop = eventsButton.bounds.height > 0
            ? eventsButton.center.y - eventsButton.bounds.height / 2 - 8
            : safeFrame.maxY
        let bottom = min(
            safeFrame.maxY, navigationContentFrame.maxY, buttonTop,
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
        guard eventsButton.isSelected != isPresented else { return }
        eventsButton.isSelected = isPresented
        updateEventsButtonAppearance()
    }

    private func updateEventsButtonAppearance() {
        var configuration: UIButton.Configuration = eventsButton.isSelected ? .prominentGlass() : .glass()
        configuration.image = Self.eventsIcon
        let inset = (Self.eventsButtonSide - Self.eventsIconSide) / 2
        configuration.contentInsets = NSDirectionalEdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset)
        configuration.cornerStyle = .capsule
        eventsButton.configuration = configuration
        eventsButton.imageView?.layer.cornerRadius = Self.eventsIconSide / 2
        eventsButton.imageView?.clipsToBounds = true
        eventsButton.accessibilityValue = eventsButton.isSelected ? "Liste affichée" : "Liste masquée"
        eventsButton.accessibilityHint = eventsButton.isSelected ? "Fermer la liste des événements" : "Afficher la liste des événements"
    }

    func updateContent(_ content: AnyView) {
        contentController.rootView = content
    }

    func synchronizeSelection(_ selection: MotionDockSelection) {
        loadViewIfNeeded()
        guard let index = MotionDockSelection.allCases.firstIndex(of: selection),
              tabsController.selectedIndex != index else { return }
        tabsController.selectedIndex = index
        tabsController.view.setNeedsLayout()
        if selection == .explore, UIAccessibility.isVoiceOverRunning {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.tabsController.selectedIndex == 0 else { return }
                UIAccessibility.post(notification: .layoutChanged, argument: self.tabsController.tabBar)
            }
        }
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
