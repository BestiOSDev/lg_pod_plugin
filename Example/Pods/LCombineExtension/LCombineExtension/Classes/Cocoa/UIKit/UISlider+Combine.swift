//
//  UISlider+Combine.swift
//  CombineCocoa
//
//  Created by dongzb01 on 2022/7/28.
//

#if !(os(iOS) && (arch(i386) || arch(arm)))
import Combine
import UIKit

@available(iOS 13.0, *)
public extension LCombineXWrapper where Base: UISlider {
    /// A publisher emitting value changes for this slider.
    var valuePublisher: AnyPublisher<Float, Never> {
        Publishers.ControlProperty(control: self.base, events: .defaultValueEvents, keyPath: \.value)
                  .eraseToAnyPublisher()
    }
}
#endif
