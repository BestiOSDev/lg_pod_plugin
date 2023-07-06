//
//  CombineControlTargetPublisher.swift
//  LCombineExtension
//
//  Created by dongzb01 on 2022/7/28.
//

import Foundation
import Combine

extension Publishers {
    
    /// UIBarButtonItem 点击事件发布者
    @available(iOS 13.0, *)
    class CombineControlTargetPublisher<Control: AnyObject>: Subject {
        typealias Output = Control
        typealias Failure = Never
        var control: Control {
            didSet {
                // 如果没有结束的话，每个订阅都要通知。
                guard completion == nil else { return }
                subscriptions.forEach { $0.receiveForSubject(control) }
            }
        }
        
        private let addTargetAction: (Control, AnyObject, Selector) -> Void
        private let removeTargetAction: (Control?, AnyObject, Selector) -> Void
        private var completion: Subscribers.Completion<Failure>? {
            didSet { // 控制不发生二次完了通知。
                guard oldValue == nil, let completion = completion else { return }
                subscriptions.forEach {
                    $0.receiveForSubject(completion: completion)
                }
            }
        }

        // 订阅数组
        private var subscriptions: [Publishers.CombineControlTarget<Control, Failure>] = []
        func send(_ value: Output) {
            guard completion == nil else { return }
            control = value
        }

        func send(completion: Subscribers.Completion<Never>) {
            self.completion = completion
        }
        func send(subscription: Subscription) {
            subscription.request(.unlimited)
        }
        // for Subscription
        private func cancel(subscription: Publishers.CombineControlTarget<Control, Failure>) {
            guard let index = subscriptions.firstIndex(of: subscription) else { return }
            subscriptions.remove(at: index)
        }
        public init(control: Control,
                    addTargetAction: @escaping (Control, AnyObject, Selector) -> Void,
                    removeTargetAction: @escaping (Control?, AnyObject, Selector) -> Void) {
            self.control = control
            self.addTargetAction = addTargetAction
            self.removeTargetAction = removeTargetAction
        }
        func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
            let subscription = Publishers.CombineControlTarget(subscriber: subscriber, control: control, addTargetAction: addTargetAction, removeTargetAction: removeTargetAction, cancel: cancel(subscription:))
            subscriber.receive(subscription: subscription)
            subscriptions.append(subscription)
            if let completion = completion { // 如果结束，立即通知。
                subscription.receiveForSubject(completion: completion)
            }
        }
    }


}
