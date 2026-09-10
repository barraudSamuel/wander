import SwiftData
import SwiftUI
import UIKit

/// Keeps one map hierarchy beneath the system tab bar while tabs select panels.
struct NativeMapTabView<Content: View>: UIViewControllerRepresentable {
    @Binding var selection: MotionDockSelection
    @State private var contentInsets = UIEdgeInsets.zero
    @ViewBuilder let content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection, contentInsets: $contentInsets)
    }

    func makeUIViewController(context: Context) -> NativeMapTabController {
        let controller = NativeMapTabController(rootView: rootView(context: context))
        controller.delegate = context.coordinator
        controller.onContentInsetsChange = { [weak coordinator = context.coordinator] insets in
            coordinator?.contentInsets.wrappedValue = insets
        }
        controller.synchronizeSelection(selection)
        return controller
    }

    func updateUIViewController(_ controller: NativeMapTabController, context: Context) {
        context.coordinator.selection = $selection
        context.coordinator.contentInsets = $contentInsets
        controller.updateContent(rootView(context: context))
        controller.synchronizeSelection(selection)
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
            guard let controller = tabBarController as? NativeMapTabController,
                  let index = controller.viewControllers?.firstIndex(of: viewController),
                  MotionDockSelection.allCases.indices.contains(index) else { return }

            let tappedSelection = MotionDockSelection.allCases[index]
            selection.wrappedValue = selection.wrappedValue == tappedSelection
                ? .explore : tappedSelection

            // Account confirmations may reject a selection change in the binding.
            controller.synchronizeSelection(selection.wrappedValue)
        }
    }
}

final class NativeMapTabController: UITabBarController {
    private let contentController: UIHostingController<AnyView>
    private var reportedContentInsets = UIEdgeInsets.zero
    var onContentInsetsChange: ((UIEdgeInsets) -> Void)?

    init(rootView: AnyView) {
        contentController = UIHostingController(rootView: rootView)
        // This persistent host is not a selected tab child. Forward the public
        // layout guides explicitly instead of relying on tab-child safe areas.
        contentController.safeAreaRegions = []
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewControllers = MotionDockSelection.allCases.map { selection in
            let controller = UIViewController()
            let image = UIImage(named: selection.assetName)?.withRenderingMode(.alwaysOriginal)
            controller.tabBarItem = UITabBarItem(title: nil, image: image, selectedImage: image)
            controller.tabBarItem.accessibilityLabel = selection.title
            controller.tabBarItem.accessibilityIdentifier = "motion-dock-" + selection.rawValue
            return controller
        }
        tabBar.accessibilityIdentifier = "native-map-tab-bar"

        addChild(contentController)
        contentController.view.backgroundColor = .clear
        contentController.view.frame = view.bounds
        contentController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(contentController.view)
        positionContentBelowBar()
        contentController.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        contentController.view.frame = view.bounds
        positionContentBelowBar()

        let contentFrame = contentLayoutGuide.layoutFrame
        let bottom = min(contentFrame.maxY, view.keyboardLayoutGuide.layoutFrame.minY)
        let insets = UIEdgeInsets(
            top: max(0, contentFrame.minY),
            left: max(0, contentFrame.minX),
            bottom: max(0, view.bounds.maxY - bottom),
            right: max(0, view.bounds.maxX - contentFrame.maxX)
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

    func updateContent(_ content: AnyView) {
        contentController.rootView = content
    }

    private func positionContentBelowBar() {
        // On iOS 26 the tab bar lives inside its own glass container. Insert
        // beneath that container, not beneath a view belonging to another parent.
        var barContainer: UIView = tabBar
        while let parent = barContainer.superview, parent !== view {
            barContainer = parent
        }
        guard barContainer.superview === view,
              let barIndex = view.subviews.firstIndex(of: barContainer),
              let contentIndex = view.subviews.firstIndex(of: contentController.view),
              contentIndex != barIndex - 1 else { return }
        view.insertSubview(contentController.view, belowSubview: barContainer)
    }

    func synchronizeSelection(_ selection: MotionDockSelection) {
        loadViewIfNeeded()
        guard let index = MotionDockSelection.allCases.firstIndex(of: selection),
              selectedIndex != index else { return }
        selectedIndex = index
        view.setNeedsLayout()
        if selection == .explore, UIAccessibility.isVoiceOverRunning {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.selectedIndex == 0 else { return }
                UIAccessibility.post(notification: .layoutChanged, argument: self.tabBar)
            }
        }
    }
}
