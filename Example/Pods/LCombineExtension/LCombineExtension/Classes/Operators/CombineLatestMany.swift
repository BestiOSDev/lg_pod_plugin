//
//  PublisherExt.swift
//  LBase
//
//  Created by dongzb01 on 2022/7/26.
//

// 当需要组合Publisher数量达到 5个, 6 个时, 用下边的方法, 少于5 个时实现apple Combine.combineLatest方法
// API命名 借鉴了苹果 Combine `combineLatest` 方法声明, 代码实现核心部分借鉴了 `CombineX` 框架
// 借鉴 https://github.com/cx-org/CombineX, 感谢 `CombineX` 提供的思路
#if canImport(Combine)
import Combine

// MARK: - 组合 5 个 Publisher

public extension Publisher {
    /// 组合 5 个 publisher
    /// - Parameters:
    ///   - publisher1: publisher1
    ///   - publisher2: publisher2
    ///   - publisher3: publisher3
    ///   - publisher4: publisher4
    /// - Returns: 返回组合后publisher
    func l_combineLatest5<P, Q, R, S>(_ publisher1: P, _ publisher2: Q, _ publisher3: R, _ publisher4: S) -> Publishers.CombineLatest5<Self, P, Q, R, S> where P: Publisher, Q: Publisher, R: Publisher, S: Publisher, Failure == P.Failure, P.Failure == Q.Failure, Q.Failure == R.Failure, R.Failure == S.Failure {
        return .init(self, publisher1, publisher2, publisher3, publisher4)
    }
}

public extension Publishers {
    /// A publisher that receives and combines the latest elements from four publishers.
    struct CombineLatest5<A, B, C, D, E>: Publisher where A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, A.Failure == B.Failure, B.Failure == C.Failure, C.Failure == D.Failure, D.Failure == E.Failure {
        public typealias Output = (A.Output, B.Output, C.Output, D.Output, E.Output)
        // 组合a,b,c,d,e5个 publisher元祖
        private typealias CombineMapABCDE = (abcd: (abc: (ab: (a: A.Output, b: B.Output), c: C.Output), d: D.Output), e: E.Output)
        public typealias Failure = A.Failure

        public let a: A
        public let b: B
        public let c: C
        public let d: D
        public let e: E

        public init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e
        }

        public func receive<S: Subscriber>(subscriber: S) where D.Failure == S.Failure, S.Input == (A.Output, B.Output, C.Output, D.Output, E.Output) {
            // 依次合并 a,b,c,d,e 5个publisher,再对输出数据 map 操作成(a,b,c,d,e)
            self.a
                .l_combineLatest(self.b)
                .l_combineLatest(self.c)
                .l_combineLatest(self.d)
                .l_combineLatest(self.e)
                .map { (tuple: CombineMapABCDE) -> Output in
                    //这里没有使用$0.0.0.0 方式读取主要是为了代码可读性
                    let a = tuple.abcd.abc.ab.a
                    let b = tuple.abcd.abc.ab.b
                    let c = tuple.abcd.abc.c
                    let d = tuple.abcd.d
                    let e = tuple.e
                    return (a, b, c, d, e)
                }.receive(subscriber: subscriber)
        }
    }
}

// MARK: - 组合 6 个 Publisher

public extension Publisher {
    /// 组合 6 个 publisher
    /// - Parameters:
    ///   - publisher1: publisher1
    ///   - publisher2: publisher2
    ///   - publisher3: publisher3
    ///   - publisher4: publisher4
    ///   - publisher5: publisher5
    /// - Returns: 返回组合后publisher
    func l_combineLatest6<P, Q, R, S, T>(_ publisher1: P, _ publisher2: Q, _ publisher3: R, _ publisher4: S, _ publisher5: T) -> Publishers.CombineLatest6<Self, P, Q, R, S, T> where P: Publisher, Q: Publisher, R: Publisher, S: Publisher, T: Publisher, Failure == P.Failure, P.Failure == Q.Failure, Q.Failure == R.Failure, R.Failure == S.Failure, S.Failure == T.Failure {
        return .init(self, publisher1, publisher2, publisher3, publisher4, publisher5)
    }
}

public extension Publishers {
    /// A publisher that receives and combines the latest elements from four publishers.
    struct CombineLatest6<A, B, C, D, E, F>: Publisher where A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, A.Failure == B.Failure, B.Failure == C.Failure, C.Failure == D.Failure, D.Failure == E.Failure, E.Failure == F.Failure {
        public typealias Output = (A.Output, B.Output, C.Output, D.Output, E.Output, F.Output)
        // 组合a,b,c,d,e,f 6个 publisher元祖
        private typealias CombineMapABCDEF = (abcde: (abcd: (abc: (ab: (a: A.Output, b: B.Output), c: C.Output), d: D.Output), e: E.Output), f: F.Output)
        public typealias Failure = A.Failure

        public let a: A
        public let b: B
        public let c: C
        public let d: D
        public let e: E
        public let f: F
        public init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e
            self.f = f
        }

        public func receive<S>(subscriber: S) where S: Subscriber, A.Failure == S.Failure, (A.Output, B.Output, C.Output, D.Output, E.Output, F.Output) == S.Input {
            // 依次合并 a,b,c,d,e,f 6个publisher,再对输出数据 map 操作转成(a,b,c,d,e,f
            self.a
                .l_combineLatest(self.b)
                .l_combineLatest(self.c)
                .l_combineLatest(self.d)
                .l_combineLatest(self.e)
                .l_combineLatest(self.f)
                .map { (tuple: CombineMapABCDEF) -> Output in
                    //这里没有使用$0.0.0.0.1 方式读取主要是为了代码可读性
                    let a = tuple.abcde.abcd.abc.ab.a
                    let b = tuple.abcde.abcd.abc.ab.b
                    let c = tuple.abcde.abcd.abc.c
                    let d = tuple.abcde.abcd.d
                    let e = tuple.abcde.e
                    let f = tuple.f
                    return (a, b, c, d, e, f)
                }.receive(subscriber: subscriber)
        }
        
    }
}
#endif
