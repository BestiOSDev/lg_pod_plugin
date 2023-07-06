//
//  UISwitch+Combine.swift
//  CombineCocoa
//
//  Created by dongzb01 on 2022/7/28.
//

#if !(os(iOS) && (arch(i386) || arch(arm)))
import Combine
import UIKit

@available(iOS 13.0, *)
public extension LCombineXWrapper where Base: UISwitch {
    /// A publisher emitting on status changes for this switch.
    var isOnPublisher: AnyPublisher<Bool, Never> {
        Publishers.ControlProperty(control: self.base, events: .defaultValueEvents, keyPath: \.isOn)
                  .eraseToAnyPublisher()
    }
}
#endif
