//
//  UIView+Extensions.swift
//  GenericTableViewSample
//
//  Created by Aleksey on 14.06.2022.
//

import Foundation
import UIKit

extension UIView {
    func parentView<T: UIView>(of type: T.Type) -> T? {
        guard let view = superview else {
            return nil
        }
        return (view as? T) ?? view.parentView(of: T.self)
    }
}
