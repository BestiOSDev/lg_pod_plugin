//
//  Relay.swift
//  CombineExt
//
//  Created by dongzb01 on 2022/7/28.
//

#if canImport(Combine)
import Combine

/// A publisher that exposes a method for outside callers to publish values.
/// It is identical to a `Subject`, but it cannot publish a finish event (until it's deallocated).
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public protocol Relay: Publisher where Failure == Never {
    associatedtype Output

    /// Relays a value to the subscriber.
    ///
    /// - Parameter value: The value to send.
    func accept(_ value: Output)

    /// Attaches the specified publisher to this relay.
    ///
    /// - parameter publisher: An infallible publisher with the relay's Output type
    ///
    /// - returns: `AnyCancellable`
    func subscribe<P: Publisher>(_ publisher: P) -> AnyCancellable where P.Failure == Failure, P.Output == Output
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension Publisher where Failure == Never {
    /// Attaches the specified relay to this publisher.
    ///
    /// - parameter relay: Relay to attach to this publisher
    ///
    /// - returns: `AnyCancellable`
    func subscribe<R: Relay>(_ relay: R) -> AnyCancellable where R.Output == Output {
        relay.subscribe(self)
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension Relay where Output == Void {
    /// Relay a void to the subscriber.
    func accept() {
        accept(())
    }
}


/// 指定 ShareReplaySubscription 的 两个范型
final class LShareReplaySubscription<Output, Failure: Error>: Combine.Subscription, Equatable {
    /// 缓存的结果个数。
    let capacity: Int
    /// 缓存的结果
    var buffer: [Output]
    /// 订阅者
    var subscriber: AnySubscriber<Output, Failure>?
    /// 发送次数
    var demand: Subscribers.Demand = .none
    /// 结束标识
    var completion: Subscribers.Completion<Failure>?

    private var cancelSubscription: (LShareReplaySubscription<Output, Failure>) -> Void

    init<S>(subscriber: S, replay: [Output], capacity: Int, completion: Subscribers.Completion<Failure>?,
            cancel: @escaping (LShareReplaySubscription<Output, Failure>) -> Void) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        self.subscriber = AnySubscriber(subscriber)
        self.buffer = replay
        self.capacity = capacity
        self.completion = completion
        self.cancelSubscription = cancel
    }

    /// 注意这里的subscriber 应该不是 引用类型
    private func complete(with completion: Subscribers.Completion<Failure>) {
        guard let subscriber = self.subscriber else { /// 注意： struct AnySubscriber 是结构体。
            return
        }
        self.subscriber = nil
        self.completion = nil
        /// 结束的时候，就把缓存的数据全部删除，且通知 订阅者已经结束。
        self.buffer.removeAll()
        subscriber.receive(completion: completion)
    }

    /// 本方法在 建立订阅的时候，在request 方法中调用。
    /// 把缓存的信息，全部发送给订阅者，同时更新 self.demand
    /// 如果已经结束的话，就把结束的结果也发给订阅者。
    private func emitAsNeeded() {
        guard let subscriber = self.subscriber else {
            return
        }
        while self.demand > .none, !self.buffer.isEmpty {
            self.demand -= .max(1)
            let nextDemand = subscriber.receive(buffer.removeFirst())
            if nextDemand != .none {
                self.demand += nextDemand
            }
        }
        if let completion = self.completion {
            complete(with: completion)
        }
    }

    /// 首次请求配置信息
    func request(_ demand: Subscribers.Demand) {
        if demand != .none {
            self.demand += demand
        }
        emitAsNeeded()
    }

    /// 把当前订阅 在 发布者的订阅List中删除。
    func cancel() {
        cancelSubscription(self)
    }

    /// 次方法在 Publisher中调用
    func receiveForPublisher(_ input: Output) {
        guard self.subscriber != nil else { return }
        buffer.append(input)
        if buffer.count > capacity {
            buffer.removeFirst()
        }
        emitAsNeeded()
    }

    /// 次方法在 Publisher中调用
    func receiveForPublisher(completion: Subscribers.Completion<Failure>) {
        guard let subscriber = self.subscriber else { return }
        self.subscriber = nil
        self.buffer.removeAll()
        subscriber.receive(completion: completion)
    }

    static func == (lhs: LShareReplaySubscription<Output, Failure>, rhs: LShareReplaySubscription<Output, Failure>) -> Bool {
        lhs.combineIdentifier == rhs.combineIdentifier
    }
    
}

#endif
