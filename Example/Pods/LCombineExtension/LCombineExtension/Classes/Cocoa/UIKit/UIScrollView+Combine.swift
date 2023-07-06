//
//  UIScrollView+Combine.swift
//  CombineCocoa
//
//  Created by dongzb01 on 2022/7/28.
//

#if !(os(iOS) && (arch(i386) || arch(arm)))
import UIKit
import Combine

@available(iOS 13.0, *)
extension UIScrollView: LCombineXCompatible { }

// swiftlint:disable force_cast
@available(iOS 13.0, *)
public extension LCombineXWrapper where Base: UIScrollView {
    
    /// A publisher emitting content offset changes from this UIScrollView.
    var contentOffsetPublisher: AnyPublisher<CGPoint, Never> {
        self.base.publisher(for: \.contentOffset)
            .eraseToAnyPublisher()
    }
    
    /// Combine wrapper for `scrollViewDidScroll(_:)`
    var didScrollPublisher: AnyPublisher<Void, Never> {
        let selector = #selector(UIScrollViewDelegate.scrollViewDidScroll(_:))
        return delegateProxy.interceptSelectorPublisher(selector)
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    /// Combine wrapper for `scrollViewWillBeginDecelerating(_:)`
    var willBeginDeceleratingPublisher: AnyPublisher<Void, Never> {
        let selector = #selector(UIScrollViewDelegate.scrollViewWillBeginDecelerating(_:))
        return delegateProxy.interceptSelectorPublisher(selector)
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    /// Combine wrapper for `scrollViewDidEndDecelerating(_:)`
    var didEndDeceleratingPublisher: AnyPublisher<Void, Never> {
        let selector = #selector(UIScrollViewDelegate.scrollViewDidEndDecelerating(_:))
        return delegateProxy.interceptSelectorPublisher(selector)
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    /// Combine wrapper for `scrollViewWillBeginDragging(_:)`
    var willBeginDraggingPublisher: AnyPublisher<Void, Never> {
        let selector = #selector(UIScrollViewDelegate.scrollViewWillBeginDragging(_:))
        return delegateProxy.interceptSelectorPublisher(selector)
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    /// Combine wrapper for `scrollViewWillEndDragging(_:withVelocity:targetContentOffset:)`
    var willEndDraggingPublisher: AnyPublisher<(velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>), Never> {
        let selector = #selector(UIScrollViewDelegate.scrollViewWillEndDragging(_:withVelocity:targetContentOffset:))
        return delegateProxy.interceptSelectorPublisher(selector)
            .map { values in
                let targetContentOffsetValue = values[2] as! NSValue
                let rawPointer = targetContentOffsetValue.pointerValue!
                
                return (values[1] as! CGPoint, rawPointer.bindMemory(to: CGPoint.self, capacity: MemoryLayout<CGPoint>.size))
            }
            .eraseToAnyPublisher()
    }
    
    /// Combine wrapper for `scrollViewDidEndDragging(_:willDecelerate:)`
    var didEndDraggingPublisher: AnyPublisher<Bool, Never> {
        let selector = #selector(UIScrollViewDelegate.scrollViewDidEndDragging(_:willDecelerate:))
        return delegateProxy.interceptSelectorPublisher(selector)
            .map { $0[1] as! Bool }
            .eraseToAnyPublisher()
    }
    
    /// Combine wrapper for `scrollViewDidZoom(_:)`
    var didZoomPublisher: AnyPublisher<Void, Never> {
        let selector = #selector(UIScrollViewDelegate.scrollViewDidZoom(_:))
        return delegateProxy.interceptSelectorPublisher(selector)
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    /// Combine wrapper for `scrollViewDidScrollToTop(_:)`
    var didScrollToTopPublisher: AnyPublisher<Void, Never> {
        let selector = #selector(UIScrollViewDelegate.scrollViewDidScrollToTop(_:))
        return delegateProxy.interceptSelectorPublisher(selector)
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    /// Combine wrapper for `scrollViewDidEndScrollingAnimation(_:)`
    var didEndScrollingAnimationPublisher: AnyPublisher<Void, Never> {
        let selector = #selector(UIScrollViewDelegate.scrollViewDidEndScrollingAnimation(_:))
        return delegateProxy.interceptSelectorPublisher(selector)
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    /// Combine wrapper for `scrollViewWillBeginZooming(_:with:)`
    var willBeginZoomingPublisher: AnyPublisher<UIView?, Never> {
        let selector = #selector(UIScrollViewDelegate.scrollViewWillBeginZooming(_:with:))
        return delegateProxy.interceptSelectorPublisher(selector)
            .map { $0[1] as! UIView? }
            .eraseToAnyPublisher()
    }
    
    /// Combine wrapper for `scrollViewDidEndZooming(_:with:atScale:)`
    var didEndZooming: AnyPublisher<(view: UIView?, scale: CGFloat), Never> {
        let selector = #selector(UIScrollViewDelegate.scrollViewDidEndZooming(_:with:atScale:))
        return delegateProxy.interceptSelectorPublisher(selector)
            .map { ($0[1] as! UIView?, $0[2] as! CGFloat) }
            .eraseToAnyPublisher()
    }
    
    var delegateProxy: DelegateProxy {
        ScrollViewDelegateProxy.createDelegateProxy(for: self.base)
    }
}

@available(iOS 13.0, *)
private class ScrollViewDelegateProxy: DelegateProxy, UIScrollViewDelegate, DelegateProxyType {
    func setDelegate(to object: UIScrollView) {
        object.delegate = self
    }
}
#endif
// swiftlint:enable force_cast

