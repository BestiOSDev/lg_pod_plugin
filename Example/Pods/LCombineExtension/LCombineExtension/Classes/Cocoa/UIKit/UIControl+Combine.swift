//
//  UIControl+ControlEventPublisher.swift
//  AFNetworking
//
//  Created by dongzb01 on 2022/7/27.
//
#if canImport(Combine)

import UIKit
import Combine
import Foundation

@available(iOS 13.0, *)
extension UIControl: LCombineXCompatible { }

extension LCombineXWrapper where Base: UIControl {
    /// 给 UIControl 及其子类添加点击事件
    /// - Parameter events: 事件类型
    /// - Returns: 返回事件发布者对象
    @available(iOS 13.0, *)
    public func controlEvent(_ events: UIControl.Event) -> AnyPublisher<Base, Never> {
        // 对 publisher 类型擦除不想暴露给外界 CombineControlEventPublisher 类型Publisher
        return Publishers.CombineControlEventPublisher(control: self.base, events: events).eraseToAnyPublisher()
    }
    
}

#endif
