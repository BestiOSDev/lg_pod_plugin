//
//  UIButtonExt.swift
//  LCombineExtension
//
//  Created by dongzb01 on 2022/7/28.
//

#if canImport(Combine)

import UIKit
import Combine
import Foundation

public extension LAnyXWrapper where Base: UIButton {
    @available(iOS 13.0, *)
    var tapPublisher: AnyPublisher<Base, Never> {
        return self.controlEvent(.touchUpInside)
    }
}

#endif
