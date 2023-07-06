//
//  UISegmentedControl+Combine.swift
//  LCombineExtension
//
//  Created by dongzb01 on 2022/8/16.
//

import Foundation

#if !(os(iOS) && (arch(i386) || arch(arm)))
import Combine
import UIKit

@available(iOS 13.0, *)
public extension LCombineXWrapper where Base: UISegmentedControl {
    /// A publisher emitting selected segment index changes for this segmented control.
      var selectedSegmentIndexPublisher: AnyPublisher<Int, Never> {
          Publishers.ControlProperty(control: self.base, events: .defaultValueEvents, keyPath: \.selectedSegmentIndex)
                    .eraseToAnyPublisher()
      }
}
#endif
