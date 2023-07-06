//
//  CombineAnyCancellable.swift
//  LCombineExtension
//
//  Created by dongzb01 on 2022/10/20.
//

import Foundation
import Combine

// 用来保存 Combine 订阅者, 垮模块使用时传递引用对象 而不是值类型
public class CombineAnyCancellable {
    public init() { }
    public lazy var set: Set<AnyCancellable> = .init()
}
