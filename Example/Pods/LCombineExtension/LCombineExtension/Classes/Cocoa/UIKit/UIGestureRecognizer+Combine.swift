//
//  UIGestureRecognizer+Combine.swift
//  LCombineExtension
//
//  Created by dongzb01 on 2022/7/28.
//

#if canImport(Combine)

import UIKit
import Combine
import Foundation

@available(iOS 13.0, *)
extension UIGestureRecognizer: LCombineXCompatible { }

// MARK: - Gesture Publishers
@available(iOS 13.0, *)
extension LCombineXWrapper where Base: UITapGestureRecognizer {
    /// A publisher which emits when this Pinch Gesture Recognizer is triggered
    public var tapPublisher: AnyPublisher<UITapGestureRecognizer, Never> {
        gesturePublisher(for: self.base)
    }
}

@available(iOS 13.0, *)
extension LCombineXWrapper where Base: UIPinchGestureRecognizer {
    /// A publisher which emits when this Pinch Gesture Recognizer is triggered
    public var pinchPublisher: AnyPublisher<UIPinchGestureRecognizer, Never> {
        gesturePublisher(for: self.base)
    }
}

@available(iOS 13.0, *)
extension LCombineXWrapper where Base: UIRotationGestureRecognizer {
    /// A publisher which emits when this Rotation Gesture Recognizer is triggered
    public var rotationPublisher: AnyPublisher<UIRotationGestureRecognizer, Never> {
        gesturePublisher(for: self.base)
    }
}

@available(iOS 13.0, *)
extension LCombineXWrapper where Base: UISwipeGestureRecognizer {
    /// A publisher which emits when this Swipe Gesture Recognizer is triggered
    public var swipePublisher: AnyPublisher<UISwipeGestureRecognizer, Never> {
        gesturePublisher(for: self.base)
    }
}

@available(iOS 13.0, *)
extension LCombineXWrapper where Base: UIPanGestureRecognizer {
    /// A publisher which emits when this Pan Gesture Recognizer is triggered
    public var panPublisher: AnyPublisher<UIPanGestureRecognizer, Never> {
        gesturePublisher(for: self.base)
    }
}

@available(iOS 13.0, *)
extension LCombineXWrapper where Base: UIScreenEdgePanGestureRecognizer {
    /// A publisher which emits when this Screen Edge Gesture Recognizer is triggered
    public var screenEdgePanPublisher: AnyPublisher<UIScreenEdgePanGestureRecognizer, Never> {
        gesturePublisher(for: self.base)
    }
}

@available(iOS 13.0, *)
extension LCombineXWrapper where Base: UILongPressGestureRecognizer {
    /// A publisher which emits when this Long Press Recognizer is triggered
    public var longPressPublisher: AnyPublisher<UILongPressGestureRecognizer, Never> {
        gesturePublisher(for: self.base)
    }
}

// MARK: - Private Helpers

// A private generic helper function which returns the provided
// generic publisher whenever its specific event occurs.
@available(iOS 13.0, *)
private func gesturePublisher<Gesture: UIGestureRecognizer>(for gesture: Gesture) -> AnyPublisher<Gesture, Never> {
    let publisher = Publishers.CombineControlTargetPublisher(control: gesture, addTargetAction: { gesture, target, action in
        gesture.addTarget(target, action: action)
    }, removeTargetAction: { gesture, target, action in
        gesture?.removeTarget(target, action: action)
    }).subscribe(on: DispatchQueue.main)
        .map { output -> Gesture in
            output
        }.eraseToAnyPublisher()
    return publisher
}

#endif

