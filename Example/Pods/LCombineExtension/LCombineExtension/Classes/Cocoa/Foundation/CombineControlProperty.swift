//
//  CombineControlProperty.swift
//  LCombineExtension
//
//  Created by dongzb01 on 2022/7/28.
//

#if !(os(iOS) && (arch(i386) || arch(arm)))
import Combine
import Foundation
import UIKit.UIControl

// MARK: - Publisher
@available(iOS 13.0, *)
extension Combine.Publishers {
    /// A Control Property is a publisher that emits the value at the provided key-path
    /// whenever the specific control events are triggered. It also emits the key-path's
    /// initial value upon subscription.
    struct ControlProperty<Control: UIControl, Value>: Publisher {
        typealias Output = Value
        typealias Failure = Never
        
        private let control: Control
        private let controlEvents: Control.Event
        private let keyPath: KeyPath<Control, Value>
        
        /// Initialize a publisher that emits the value at the specified key-path
        /// whenever any of the provided Control Events trigger.
        ///
        /// - parameter control: UI Control.
        /// - parameter events: Control Events.
        /// - parameter keyPath: A Key Path from the UI Control to the requested value.
        public init(control: Control,
                    events: Control.Event,
                    keyPath: KeyPath<Control, Value>) {
            self.control = control
            self.controlEvents = events
            self.keyPath = keyPath
        }
        
        func receive<S: Subscriber>(subscriber: S) where S.Failure == Failure, S.Input == Output {
            let subscription = ControlPropertySubscription(subscriber: subscriber,
                                                           control: control,
                                                           event: controlEvents,
                                                           keyPath: keyPath)
            subscriber.receive(subscription: subscription)
        }
    }
}

// MARK: - Subscription
@available(iOS 13.0, *)
extension Combine.Publishers.ControlProperty {
    private final class ControlPropertySubscription<S: Subscriber, Control: UIControl, Value>: Combine.Subscription where S.Input == Value {
        private var subscriber: S?
        weak private var control: Control?
        let keyPath: KeyPath<Control, Value>
        private var didEmitInitial = false
        private let event: Control.Event
        
        init(subscriber: S, control: Control, event: Control.Event, keyPath: KeyPath<Control, Value>) {
            self.subscriber = subscriber
            self.control = control
            self.keyPath = keyPath
            self.event = event
            control.addTarget(self, action: #selector(handleEvent), for: event)
        }
        
        func request(_ demand: Subscribers.Demand) {
            // Emit initial value upon first demand request
            if !didEmitInitial,
               demand > .none,
               let control = control,
               let subscriber = subscriber {
                _ = subscriber.receive(control[keyPath: keyPath])
                didEmitInitial = true
            }
            
            // We don't care about the demand at this point.
            // As far as we're concerned - UIControl events are endless until the control is deallocated.
        }
        
        func cancel() {
            control?.removeTarget(self, action: #selector(handleEvent), for: event)
            subscriber = nil
        }
        
        @objc private func handleEvent() {
            guard let control = control else { return }
            _ = subscriber?.receive(control[keyPath: keyPath])
        }
    }
}

extension UIControl.Event {
    static var defaultValueEvents: UIControl.Event {
        return [.allEditingEvents, .valueChanged]
    }
}
#endif
