//
//  CombineLatest.swift
//  LCombineExtension
//
//  Created by dongzb01 on 2022/7/31.
//


#if canImport(Combine)
import Combine
import Foundation
// 自定义实现 combineLatest 方法
extension Publisher {
    // 组合两个publisher
    func l_combineLatest<P>(_ other: P) -> Publishers.CombineLatest2<Self, P> where P: Publisher, Self.Failure == P.Failure {
        let publisher = Publishers.CombineLatest2(a: self, b: other)
        return publisher
    }
}

extension Publishers {
    
    struct CombineLatest2<A, B>: Publisher where A: Publisher, B: Publisher, A.Failure == B.Failure {
        let a: A
        let b: B
        typealias Failure = A.Failure
        typealias Output = (A.Output, B.Output)
        public init(a: A, b: B) {
            self.a = a
            self.b = b
        }
        func receive<S>(subscriber: S) where S: Subscriber, A.Failure == S.Failure, (A.Output, B.Output) == S.Input {
            let subscription = LCombineLatestSubscription(pub: self, sub: subscriber)
            subscriber.receive(subscription: subscription)
        }
    }
}


/// 订阅状态
struct CombineLatestState: OptionSet {
    let rawValue: Int

    static let aCompleted = CombineLatestState(rawValue: 1 << 0)
    static let bCompleted = CombineLatestState(rawValue: 1 << 1)

    static let initial: CombineLatestState = []
    static let completed: CombineLatestState = [.aCompleted, .bCompleted]

    var isACompleted: Bool {
        return self.contains(.aCompleted)
    }

    var isBCompleted: Bool {
        return self.contains(.bCompleted)
    }

    var isCompleted: Bool {
        return self == .completed
    }
}

extension Publishers.CombineLatest2 {
    
    /// 自定义Subscription, 内部监听publish1, publish2接受数据和发送数据
    final class LCombineLatestSubscription<S>: Combine.Subscription, CustomStringConvertible, CustomDebugStringConvertible where S: Subscriber, B.Failure == S.Failure, S.Input == (A.Output, B.Output) {
        typealias Sub = S
        typealias Pub = Publishers.CombineLatest2<A, B>

        let sub: Sub
        let lock = NSLock()

        enum Source: Int {
            case a = 1
            case b = 2
        }

        var childA: LChildSubscriber<A.Output>?
        var childB: LChildSubscriber<B.Output>?
        var state: CombineLatestState = .initial
        var outputA: A.Output?
        var outputB: B.Output?
        var demand: Subscribers.Demand = .none

        static func == (lhs: Publishers.CombineLatest2<A, B>.LCombineLatestSubscription<S>, rhs: Publishers.CombineLatest2<A, B>.LCombineLatestSubscription<S>) -> Bool {
            return lhs.combineIdentifier == rhs.combineIdentifier
        }

        init(pub: Pub, sub: Sub) {
            self.sub = sub

            let childA = LChildSubscriber<A.Output>(parent: self, source: .a)
            pub.a.subscribe(childA)
            self.childA = childA

            let childB = LChildSubscriber<B.Output>(parent: self, source: .b)
            pub.b.subscribe(childB)
            self.childB = childB
        }

        var description: String {
            return "LCombineLatest"
        }

        var debugDescription: String {
            return "LCombineLatest"
        }
        
        /// 每次准备请求数据都会来到这里
        func request(_ demand: Subscribers.Demand) {
            guard demand > .none else {
                return
            }
            self.lock.lock()
            if self.state == .completed {
                self.lock.unlock()
                return
            }
            self.demand += demand
            let childA = self.childA
            let childB = self.childB
            self.lock.unlock()
            childA?.request(demand)
            childB?.request(demand)
        }
        
        /// 取消订阅的通知
        func cancel() {
            self.lock.lock()
            self.state = .completed
            let (childA, childB) = self.release()
            self.lock.unlock()
            childA?.cancel()
            childB?.cancel()
        }
        
        /// 内部释放 publisher1 和 publish2的引用
        private func release() -> (LChildSubscriber<A.Output>?, LChildSubscriber<B.Output>?) {
            defer {
                self.outputA = nil
                self.outputB = nil

                self.childA = nil
                self.childB = nil
            }
            return (self.childA, self.childB)
        }
        
        /// 处理内部子 publisher 接收到数据
        /// - Parameters:
        ///   - value:  input 数据
        ///   - source: 数据来源类型, 区分publisher1 和publisher2
        /// - Returns: 返回Demand
        func childReceive(_ value: Any, from source: Source) -> Subscribers.Demand {
            self.lock.lock()
            // 判断 subscription状态, 如果是已完成 就返回 .none
            let action = CombineLatestState(rawValue: source.rawValue)
            if self.state.contains(action) {
                self.lock.unlock()
                return .none
            }
            // 根据 source 类型给self.outputA, self.outputB 赋值
            switch source {
            case .a:
                self.outputA = value as? A.Output
            case .b:
                self.outputB = value as? B.Output
            }
            // 如果剩余需要发送的数据为 0, 就返回.none
            if self.demand == 0 {
                self.lock.unlock()
                return .none
            }
            // 对 self.outputA, self.outputB 进行解包, 当同时都有值存在时 发送数据出去
            switch (self.outputA, self.outputB) {
            case let (.some(a), .some(b)):
                self.demand -= 1 // 剩余需要发送的数据次数 - 1
                self.lock.unlock()
                let more = self.sub.receive((a, b)) // 将 outputA, outputB对值发送出去
                // FIXME: Apple's Combine doesn't strictly support sync backpressure.
                self.lock.lock()
                self.demand += more // 发送完毕后得到是否累加, 重新给 demand 赋值
                self.lock.unlock()
                return .none
            default:
                self.lock.unlock()
                return .none
            }
        }
        
        /// 子 publisher 收到完成的通知
        /// - Parameters:
        ///   - completion: 完成的通知
        ///   - source: source 类型
        func childReceive(completion: Subscribers.Completion<A.Failure>, from source: Source) {
            let action = CombineLatestState(rawValue: source.rawValue)

            self.lock.lock()
            if self.state.contains(action) {
                self.lock.unlock()
                return
            }

            switch completion {
            case .failure: // 发送数据失败, 释放 ChildA, childB, 并发送失败的事件给最外层的sink订阅者
                self.state = .completed
                let (childA, childB) = self.release()
                self.lock.unlock()

                childA?.cancel()
                childB?.cancel()
                self.sub.receive(completion: completion)
            case .finished:
                self.state.insert(action)
                if self.state.isCompleted { // 必须最外部的 publisher1, publisher2都调用了 .send(completion: .finished), 才会标记为已完成, 并且释放 ChildA, childB, 并发送失败的事件给最外层的sink订阅者
                    let (childA, childB) = self.release()
                    self.lock.unlock()

                    childA?.cancel()
                    childB?.cancel()
                    self.sub.receive(completion: completion)
                } else { // 如果publisher1, publisher2 都没有完成, 则继续订阅 A, B
                    self.lock.unlock()
                }
            }
        }
        
        /// 自定义Subscriber
        final class LChildSubscriber<Output>: Combine.Subscriber {
            typealias Input = Output
            typealias Failure = A.Failure
            typealias Parent = LCombineLatestSubscription
            let parent: Parent
            let source: Source
            var subscription = AtomicBox<Subscription?>(nil)
            func receive(subscription: Subscription) {
                self.subscription.exchange(with: subscription)
            }

            func receive(_ input: Output) -> Subscribers.Demand {
                // 如果subscription为空就不再处理接收到的数据
                guard self.subscription.value != nil else {
                    return .none
                }
                // 通过 source 区分 A, B 发送过来的数据, 并交给子 publisher 处理
                return self.parent.childReceive(input, from: self.source)
            }

            func receive(completion: Subscribers.Completion<A.Failure>) {
                guard let subscription = self.subscription.value else { return }
                subscription.cancel()
                self.subscription.exchange(with: nil)
                self.parent.childReceive(completion: completion, from: self.source)
            }

            init(parent: Parent, source: Source) {
                self.parent = parent
                self.source = source
            }

            func cancel() {
                guard let subscription = self.subscription.value else { return }
                subscription.cancel()
                self.subscription.exchange(with: nil)
            }

            func request(_ demand: Subscribers.Demand) {
                self.subscription.value?.request(demand)
            }
        }
    }
}

#endif
