//
//  GenericViewXib.swift
//  saas-ios
//
//  Created by Pirogov Aleksey on 20.08.2021.
//  Copyright © 2021 Nikita Zhukov. All rights reserved.
//

import UIKit

public protocol GenericViewXibProtocol:UIView {
    associatedtype ViewToShowConfigType
    func configure(data:ViewToShowConfigType)
}
extension GenericViewXibProtocol {
    static func test()->ViewToShowConfigType.Type {
        return ViewToShowConfigType.self
    }
}

open class GenericViewXib<T:Any>:GenericXibTemplate, GenericViewXibProtocol {
    
    public typealias ViewToShowConfigType = T
    public var data:T!
    open var hasKeyboard:Bool {return false}
    open func configure(data: T) {
        self.data = data
    }
    
    public class func calculateHeight(item:T) -> CGFloat {
        let view:Self = .init()
        view.frame = .zero
        view.setupIfNeeded()
        view.configure(data: item)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        let height = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        return height
    }
}

