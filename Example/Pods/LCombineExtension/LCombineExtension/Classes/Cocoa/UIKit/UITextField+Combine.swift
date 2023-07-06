//
//  UITextField+Combine.swift
//  LCombineExtension
//
//  Created by dongzb01 on 2022/7/28.
//

#if canImport(Combine)

import UIKit
import Combine

@available(iOS 13.0, *)
extension LCombineXWrapper where Base: UITextField {
  
    /// A publisher emitting any text changes to a this text field.
    public var textPublisher: AnyPublisher<String, Never> {
        Publishers.ControlProperty(control: self.base, events: .defaultValueEvents, keyPath: \.text).map({ str -> String in
            return str ?? ""
        }).eraseToAnyPublisher()
    }

    /// A publisher emitting any attributed text changes to this text field.
    public var attributedTextPublisher: AnyPublisher<NSAttributedString, Never> {
        Publishers.ControlProperty(control: self.base, events: .defaultValueEvents, keyPath: \.attributedText).map({ attributes in
            return attributes ?? NSAttributedString()
        }).eraseToAnyPublisher()
    }
    
    /// A publisher that emits whenever the user taps the return button and ends the editing on the text field.
    public var returnPublisher: AnyPublisher<Void, Never> {
        controlEvent(.editingDidEndOnExit).map { _ -> Void in
            return
        }.eraseToAnyPublisher()
    }

    /// A publisher that emits whenever the user taps the text fields and begin the editing.
    public var didBeginEditingPublisher: AnyPublisher<Void, Never> {
        controlEvent(.editingDidBegin).map { _ -> Void in
            return
        }.eraseToAnyPublisher()
    }
}

#endif
