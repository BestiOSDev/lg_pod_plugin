//
//  BehaviorSubject.swift
//  LCombineExtension
//
//  Created by dongzb01 on 2022/8/4.
//
//6666666
#if canImport(Combine)

import Combine
import Foundation

/*
 封装单个值并在值更改时发布新元素的中继。
 与其对应的主题不同，它可能只接受值，并且只在释放时发送一个完成事件。
 它不能发送失败事件。
 注意：与 PassthroughRelay 不同，CurrentValueRelay 维护最近发布的值的缓冲区。
 功能和 Combine.CurrentValueSubject 形似, 唯一区别是不能发送 Failure 事件, 相当于
 CurrentValueSubject<Output, Never>
 */

public class CurrentValueRelay<Output>: Relay {
    private let capacity: Int = 1 // 默认只缓存一个数据
    private let lock = NSRecursiveLock()
    private var upstream: CurrentValueSubject<Output, Failure>
    private var replay = [Output]()
    private var subscriptions = [LShareReplaySubscription<Output, Failure>]()
    private var completion: Subscribers.Completion<Failure>?
    // 初始化带一个默认值
    public init(value: Output) {
        self.upstream = .init(value)
    }
    // 获取当前值
    public var value: Output {
        return self.upstream.value
    }
    // 接收一个值
    public func accept(_ value: Output) {
        self.upstream.send(value)
    }

    // 这个方法只是测试 订阅者能否收到完成事件, 不对外界使用
    private func setCompletion() {
        self.upstream.send(completion: .finished)
    }

    /// 在第一个 sink 接受到数据后，就可以 replay进行。让所有的 订阅 进行发送数据。
    private func replay(_ value: Output) {
        lock.lock()
        defer {
            lock.unlock()
        }
        guard completion == nil else {
            return
        }
        self.replay.append(value)
        if self.replay.capacity > capacity {
            self.replay.removeFirst()
        }
        subscriptions.forEach {
            $0.receiveForPublisher(value)
        }
    }

    /// 清除缓存，不在进行发送，同时 让所有的 订阅 进行发送 结束数据。同时保留self.completion ，意味着 replay方法不再 发送数据。
    private func complete(with completion: Subscribers.Completion<Failure>) {
        lock.lock()
        defer {
            lock.unlock()
        }
        self.replay.removeAll()
        self.completion = completion
        subscriptions.forEach {
            $0.receiveForPublisher(completion: completion)
        }
    }

    public func subscribe<P>(_ publisher: P) -> AnyCancellable where P: Publisher, Output == P.Output, P.Failure == Never {
        publisher.subscribe(upstream)
    }

    /// 本方法是SharedReplay 发布者 和 订阅者subscriber 进行关联， 产生订阅关系。
    public func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
        lock.lock()
        defer {
            lock.unlock()
        }
        /// 订阅Subscription和 订阅者subscriber 是 1:1 的关系。
        let subscription = LShareReplaySubscription(subscriber: subscriber, replay: replay, capacity: capacity, completion: completion, cancel: cancel(subscription:))
        subscriptions.append(subscription)

        /// 订阅者 和 订阅关联。
        subscriber.receive(subscription: subscription)

        guard subscriptions.count == 1 else {
            // 新添加都订阅者, 订阅后发送当前最新值
            subscriptions.last?.receiveForPublisher(self.value)
            return
        }

        /// 为了接受上游数据，这里 定义了 上游的订阅者sink ， 然后对SharedReplay 的订阅者 继续传递数据。
        let sink = AnySubscriber<Output, Never> { subscription in
            subscription.request(.unlimited)
        } receiveValue: { [weak self] value in
            self?.replay(value)
            return .none
        } receiveCompletion: { [weak self] in
            self?.complete(with: $0)
        }

        /// 这里的sink 是一个中转站的角色。 从上游接受到数据后，对 订阅List进行 再传递。
        self.upstream.subscribe(sink)
    }

    /// f as! (BehaviorSubject<BehaviorSubject<T>.Output>) -> Subscribers.Demand Subscription
    private func cancel(subscription: LShareReplaySubscription<Output, Failure>) {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        guard let index = subscriptions.firstIndex(of: subscription) else { return }
        subscriptions.remove(at: index)
    }
    
}

#endif
