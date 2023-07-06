//
//  CombineControlEventPublisher.swift
//  LCombineExtension
//
//  Created by dongzb01 on 2022/7/28.
//
#if canImport(Combine)
import UIKit
import Foundation
import Combine

extension Publishers {
    /// UIControl 点击事件发布者
    @available(iOS 13.0, *)
    class CombineControlEventPublisher<Control: UIControl>: Subject {
        typealias Output = Control
        typealias Failure = Never
        let events: UIControl.Event
        private var value: Output {
            didSet {
                // 如果没有结束的话，每个订阅都要通知。
                guard completion == nil else { return }
                subscriptions.forEach { $0.receiveForSubject(value) }
            }
        }
        
        private var completion: Subscribers.Completion<Failure>? {
            didSet {
                // 控制不发生二次完了通知。
                guard oldValue == nil, let completion = completion else { return }
                subscriptions.forEach { $0.receiveForSubject(completion: completion) }
            }
        }
        
        // 订阅数组
        private var subscriptions: [Publishers.CombineControlEvent<Output, Failure>] = []
        func send(_ value: Output) {
            guard completion == nil else { return }
            self.value = value
        }
        
        func send(completion: Subscribers.Completion<Never>) {
            self.completion = completion
        }
        
        func send(subscription: Subscription) {
            subscription.request(.unlimited)
        }
        
        // for Subscription
        private func cancel(subscription: Publishers.CombineControlEvent<Output, Failure>) {
            guard let index = subscriptions.firstIndex(of: subscription) else { return }
            subscriptions.remove(at: index)
        }
        
        public init(control: Control, events: UIControl.Event) {
            self.value = control
            self.events = events
        }
        
        func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
            let subscription = Publishers.CombineControlEvent(subscriber: subscriber, control: self.value, events: self.events, cancel: cancel(subscription:))
            subscriber.receive(subscription: subscription)
            
            subscriptions.append(subscription)
            
            if let completion = completion {
                // 如果结束，立即通知。
                subscription.receiveForSubject(completion: completion)
            }
        }
    }
}

#endif
