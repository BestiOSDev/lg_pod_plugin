//
//  CustomNameSpace.swift
//  LCombineExtension
//
//  Created by dongzb01 on 2022/7/28.
//

import Foundation

@available(iOS 13.0, *)
public protocol LCombineXWrapper {
    associatedtype Base
    var base: Base { get }
    init(_ base: Base)
}

@available(iOS 13.0, *)
public struct LAnyXWrapper<Base>: LCombineXWrapper {
    public let base: Base
    public init(_ base: Base) {
        self.base = base
    }
}

@available(iOS 13.0, *)
public protocol LCombineXCompatible {
}

@available(iOS 13.0, *)
extension LCombineXCompatible {
    
    public var lx: LAnyXWrapper<Self> {
        LAnyXWrapper(self)
    }
    
    public static var lx: LAnyXWrapper<Self>.Type {
        LAnyXWrapper.self
    }
}



