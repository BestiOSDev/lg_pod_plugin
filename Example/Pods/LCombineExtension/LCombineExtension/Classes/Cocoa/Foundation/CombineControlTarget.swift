//
//  CombineControlTarget.swift
//  LCombineExtension
//
//  Created by dongzb01 on 2022/7/28.
//

#if canImport(Combine)

import Combine
import Foundation

extension Combine.Publishers {
    
    /// 用来处理 button 点击事件, 并讲接收到事件发送出去
    @available(iOS 13.0, *)
    class CombineControlTarget<Output: AnyObject, Failure: Error>: Combine.Subscription, Equatable {
        private var control: Output?
        private var demand: Subscribers.Demand = .none
        private var subscriber: AnySubscriber<Output, Failure>
        private let removeTargetAction: (Output?, AnyObject, Selector) -> Void
        private let action = #selector(handleAction)
        private var cancelSubscription: (CombineControlTarget<Output, Failure>) -> Void
        
        init<S>(subscriber: S, control: Output, addTargetAction: @escaping (Output, AnyObject, Selector) -> Void, removeTargetAction: @escaping (Output?, AnyObject, Selector) -> Void, cancel: @escaping (CombineControlTarget<Output, Failure>) -> Void) where S: Combine.Subscriber, Output == S.Input, Failure == S.Failure  {
            self.control = control
            self.cancelSubscription = cancel
            self.subscriber = .init(subscriber)
            self.removeTargetAction = removeTargetAction
            addTargetAction(control, self, action)
        }
        
        @objc func handleAction() {
            if let control = self.control {
                // 发送点击事件给外部订阅者
                _ = self.subscriber.receive(control)
            }
        }

        // Subscription
        func request(_ demand: Subscribers.Demand) {
            // 每次发生订阅的时候，会执行一次。
            self.demand = demand
        }

        // Cancellable, 从 订阅List删除本身。 初始化的时候，将使用MySubject#cancel 进行实现。
        func cancel() {
            cancelSubscription(self)
            if let control = self.control {
                self.removeTargetAction(control, self, action)
            }
        }

        // for Subscriber, 在 MySubject 中调用。
        func receiveForSubject(_ value: Output) {
            guard demand != .none else { return }
            demand -= 1
            demand += subscriber.receive(value)
        }

        // for Subscriber, 在 ControlEventPublisher 中调用。
        func receiveForSubject(completion: Subscribers.Completion<Failure>) {
            subscriber.receive(completion: completion)
        }

        static func == (lhs: CombineControlTarget<Output, Failure>, rhs: CombineControlTarget<Output, Failure>) -> Bool {
            lhs.combineIdentifier == rhs.combineIdentifier
        }
    }
}

#endif
