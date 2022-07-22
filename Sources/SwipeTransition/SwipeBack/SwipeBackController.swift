//
//  SwipeBackController.swift
//  SwipeTransition
//
//  Created by Tatsuya Tanaka on 20171222.
//  Copyright © 2017年 tattn. All rights reserved.
//

import UIKit

@objcMembers
public final class SwipeBackController: NSObject {
    public var onStartTransition: ((UIViewControllerContextTransitioning) -> Void)?
    public var onFinishTransition: ((UIViewControllerContextTransitioning) -> Void)?

    public var isEnabled: Bool {
        get { return context.isEnabled }
        set {
            context.isEnabled = newValue
            
            switch newValue {
            case true where panGestureRecognizer.view == nil:
                navigationController?.view.addGestureRecognizer(panGestureRecognizer)
            case true:
                // If already added gesture, do nothing
                break
            case false:
                panGestureRecognizer.view?.removeGestureRecognizer(panGestureRecognizer)
            }
        }
    }

    private lazy var animator = SwipeBackAnimator(parent: self)
    private let context: SwipeBackContext
    private lazy var panGestureRecognizer = OneFingerDirectionalPanGestureRecognizer(direction: .right, target: self, action: #selector(handlePanGesture(_:)))
    private weak var navigationController: UINavigationController?

    public required init(navigationController: UINavigationController) {
        context = SwipeBackContext(target: navigationController)
        super.init()

        self.navigationController = navigationController
        panGestureRecognizer.delegate = self

        navigationController.view.addGestureRecognizer(panGestureRecognizer)
        setNavigationControllerDelegate(navigationController.delegate)

        // Prioritize the default edge swipe over the custom swipe back
        navigationController.interactivePopGestureRecognizer.map { panGestureRecognizer.require(toFail: $0) }
    }

    deinit {
        panGestureRecognizer.view?.removeGestureRecognizer(panGestureRecognizer)
    }

    public func setNavigationControllerDelegate(_ delegate: UINavigationControllerDelegate?) {
        context.navigationControllerDelegateProxy = NavigationControllerDelegateProxy(delegates: [self] + (delegate.map { [$0] } ?? []) )
    }

    @objc private func handlePanGesture(_ recognizer: OneFingerDirectionalPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            context.startTransition()
        case .changed:
            context.updateTransition(recognizer: recognizer)
        case .ended:
            if context.allowsTransitionFinish(recognizer: recognizer) {
                context.finishTransition()
            } else {
                fallthrough
            }
        case .cancelled:
            context.cancelTransition()
        default:
            break
        }
    }
}

extension SwipeBackController: UIGestureRecognizerDelegate {
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return context.allowsTransitionStart
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let view_is_not_slider = !(touch.view is UISlider)
        
        if view_is_not_slider {
            if let scroll_view = touch.view as? UIScrollView {
                panGestureRecognizer.require(toFail: scroll_view.panGestureRecognizer)
            }
        }
        
        return view_is_not_slider
    }
}

extension SwipeBackController: UINavigationControllerDelegate {
    public func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return operation == .pop && context.isEnabled && context.interactiveTransition != nil ? animator : nil
    }

    public func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return context.interactiveTransitionIfNeeded()
    }

    public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if animated, context.isEnabled {
            context.transitioning = true
        }
    }

    public func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        context.transitioning = false
        panGestureRecognizer.isEnabled = navigationController.viewControllers.count > 1
    }
}
