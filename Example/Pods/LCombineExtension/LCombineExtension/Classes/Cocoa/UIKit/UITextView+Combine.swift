//
//  UITextView+Combine.swift
//  CombineCocoa
//
//  Created by dongzb01 on 2022/7/28.
//

#if !(os(iOS) && (arch(i386) || arch(arm)))
import UIKit
import Combine

@available(iOS 13.0, *)
extension LCombineXWrapper where Base: UITextView {
    /// A Combine publisher for the `UITextView's` value.
    ///
    /// - note: This uses the underlying `NSTextStorage` to make sure
    ///         autocorrect changes are reflected as well.
    ///
    /// - seealso: https://git.io/JJM5Q
    public var valuePublisher: AnyPublisher<String, Never> {
        Deferred { [weak textView = self.base] in
            textView?.textStorage
                .didProcessEditingRangeChangeInLengthPublisher
                .map { _ in textView?.text ?? "" }
                .prepend(textView?.text ?? "")
                .eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
    
    public var textPublisher: AnyPublisher<String, Never> { valuePublisher }
}


#endif
