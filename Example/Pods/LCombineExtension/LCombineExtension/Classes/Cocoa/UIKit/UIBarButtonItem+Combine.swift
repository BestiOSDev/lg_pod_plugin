//
//  UIBarButtonItem+Combine.swift
//  LCombineExtension
//
//  Created by dongzb01 on 2022/7/28.
//

#if canImport(Combine)

import UIKit
import Combine
import Foundation

@available(iOS 13.0, *)
extension UIBarButtonItem: LCombineXCompatible { }

extension LCombineXWrapper where Base: UIBarButtonItem {
    
    /// 给 UIBarButtonItem 及其子类添加点击事件
    /// - Parameter events: 事件类型
    /// - Returns: 返回事件发布者对象
    @available(iOS 13.0, *)
    public var tapPublisher: AnyPublisher<UIBarButtonItem, Never> {
        // 对 publisher 类型擦除不想暴露给外界 CombineControlTargetPublisher 类型的Publisher
        return Publishers.CombineControlTargetPublisher(control: self.base) { control, target, action in
            control.target = target
            control.action = action
        } removeTargetAction: { control, target, action in
            control?.target = nil
            control?.action = nil
        }.eraseToAnyPublisher()
    }

}

#endif
