//
//  File.swift
//  
//
//  Created by Pirogov Aleksey on 29.10.2021.
//

import Foundation
import UIKit

open class GenericXibTemplate: UIView {
    
    open class var bundle:Bundle {
        return .module
    }
    
    private(set) public var alreadyLayouted:Bool = false
    
    open var afterLayoutFn:(() -> Void)? {return nil}
    open var beforeLayoutFn:(() -> Void)? {return nil}
    
    weak var contentView:UIView?
    
    public class var nibName : String {
                return "\(self)"
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        xibSetup()
    }
    public override init(frame: CGRect) {
        super.init(frame: frame)
        xibSetup()
    }
    
    public override func layoutSubviews() {
        if (!alreadyLayouted) {
            beforeLayoutFn?()
        }
        super.layoutSubviews()
        if (!alreadyLayouted) {
            alreadyLayouted = true
            afterLayoutFn?()
            
        }
    }
    
    public func instanceFromNib<T : GenericXibTemplate>(templateClass : T.Type) -> UIView? {
        let nibName = (templateClass as GenericXibTemplate.Type).nibName
//        Bundle.module
//        Bundle.module
//        let bundle = Bundle(for: templateClass)
        let nib = UINib(nibName: nibName, bundle: Self.bundle)
        let instance = nib.instantiate(withOwner: self, options: nil)
        if (instance.count > 0) {
            return instance[0] as? UIView
        }
        return nil
    }
    
    func xibSetup() {
        
        guard let view = instanceFromNib(templateClass: type(of: self)) else {return}
        
        view.frame = bounds
        addSubview(view)
        
        translatesAutoresizingMaskIntoConstraints = false
        
        contentView = view
        setupIfNeeded()
    }
    
    open func setupIfNeeded() {
        
    }
    
}
