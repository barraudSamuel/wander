//
//  RightEdgePanGestureView.swift
//  wander
//
//  Bridges UIKit's screen-edge recognizer so the social rail does not steal
//  ordinary MapKit pans.
//

import SwiftUI
import UIKit

enum RightEdgePanEvent {
    case began(locationY: CGFloat)
    case changed(
        translationX: CGFloat,
        velocityX: CGFloat,
        locationY: CGFloat
    )
    case ended(
        translationX: CGFloat,
        velocityX: CGFloat,
        locationY: CGFloat
    )
    case cancelled
}

struct RightEdgePanGestureView: UIViewRepresentable {
    let onEvent: (RightEdgePanEvent) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onEvent: onEvent)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isOpaque = false

        let recognizer = UIScreenEdgePanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handle(_:))
        )
        recognizer.edges = .right
        recognizer.cancelsTouchesInView = true
        view.addGestureRecognizer(recognizer)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onEvent = onEvent
    }

    final class Coordinator: NSObject {
        var onEvent: (RightEdgePanEvent) -> Void

        init(onEvent: @escaping (RightEdgePanEvent) -> Void) {
            self.onEvent = onEvent
        }

        @objc func handle(_ recognizer: UIScreenEdgePanGestureRecognizer) {
            let translationX = recognizer.translation(in: recognizer.view).x
            let velocityX = recognizer.velocity(in: recognizer.view).x
            let coordinateView: UIView? = recognizer.view?.window
                ?? recognizer.view
            let locationY = recognizer.location(in: coordinateView).y

            switch recognizer.state {
            case .began:
                onEvent(.began(locationY: locationY))
            case .changed:
                onEvent(
                    .changed(
                        translationX: translationX,
                        velocityX: velocityX,
                        locationY: locationY
                    )
                )
            case .ended:
                onEvent(
                    .ended(
                        translationX: translationX,
                        velocityX: velocityX,
                        locationY: locationY
                    )
                )
            case .cancelled, .failed:
                onEvent(.cancelled)
            case .possible:
                break
            @unknown default:
                onEvent(.cancelled)
            }
        }
    }
}
