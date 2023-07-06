//
//  UIControlEvent.swift
//  LCombineExtension
//
//  Created by dongzb01 on 2022/7/28.
//

#if canImport(Combine)
import UIKit
import Foundation
import Combine

extension Publishers {
    
    /// 用来处理 button 点击事件, 并讲接收到事件发送出去
    @available(iOS 13.0, *)
    class CombineControlEvent<Output, Failure: Error>: Combine.Subscription, Equatable where Output: UIControl {
        private var demand: Subscribers.Demand = .none
        private var subscriber: AnySubscriber<Output, Failure>
        private var cancelSubscription: (CombineControlEvent<Output, Failure>) -> Void
        private weak var control: UIControl?
        private let events: UIControl.Event
        
        init<S>(subscriber: S, control: UIControl, events: UIControl.Event, cancel: @escaping (CombineControlEvent<Output, Failure>) -> Void) where S: Combine.Subscriber, Output == S.Input, Failure == S.Failure {
            self.subscriber = .init(subscriber)
            self.cancelSubscription = cancel
            self.control = control
            self.events = events
            self.control?.addTarget(self, action: #selector(self.run), for: events)
        }
        
        @objc private func run() {
            guard let control = self.control as? Output else { return }
            // 发送点击事件给外部订阅者
            _ = self.subscriber.receive(control)
        }
        
        // Subscription
        func request(_ demand: Subscribers.Demand) {
            // 每次发生订阅的时候，会执行一次。
            self.demand = demand
        }
        
        // Cancellable, 从 订阅List删除本身。 初始化的时候，将使用MySubject#cancel 进行实现。
        func cancel() {
            cancelSubscription(self)
            self.control?.removeTarget(self, action: #selector(self.run), for: self.events)
        }
        
        // for Subscriber, 在 ControlEventPublisher 中调用。
        func receiveForSubject(_ value: Output) {
            guard demand != .none else { return }
            demand -= 1
            demand += subscriber.receive(value)
        }
        
        // for Subscriber, 在 ControlEventPublisher 中调用。
        func receiveForSubject(completion: Subscribers.Completion<Failure>) {
            subscriber.receive(completion: completion)
        }
        
        static func == (lhs: CombineControlEvent<Output, Failure>, rhs: CombineControlEvent<Output, Failure>) -> Bool {
            lhs.combineIdentifier == rhs.combineIdentifier
        }
    }
    
}

#endif
