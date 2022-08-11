//
//  GenericCell.swift
//  saas-ios
//
//  Created by Pirogov Aleksey on 20.08.2021.
//  Copyright © 2021 Nikita Zhukov. All rights reserved.
//

import UIKit

private var updateFnsMap:NSMapTable<UITableView, GenericCellUpdate> = .init(keyOptions: .weakMemory, valueOptions: .strongMemory)

private var queue:DispatchQueue = .init(label: "GenericCell")

private class GenericCellUpdate {
    
    init(tableView: UITableView) {
        self.tableView = tableView
    }
    
    private var workItem:DispatchWorkItem?
    weak var tableView:UITableView?
    var fns:[(()->Void)] = []
    var animFns:[(()->Void)] = []
    private var queue:DispatchQueue = .init(label: "GenericCellUpdate")
    
    func addFn(fn: @escaping (() -> Void), animFn: @escaping (() -> Void)) {
        queue.sync {
            
            workItem?.cancel()
            let item:DispatchWorkItem = .init(block: {[weak self] in
                guard let self = self, let tableView = self.tableView, self.fns.count > 0 else {
                    return
                }
                var fns:[(() -> Void)]?
                var animFns:[(() -> Void)]?
                self.queue.sync {
                    fns = self.fns
                    animFns = self.animFns
                    self.fns = []
                    self.animFns = []
                }
                
                UIView.performWithoutAnimation {
                    tableView.beginUpdates()
                    for fn in fns ?? [] {
                        fn()
                    }
                    tableView.endUpdates()
                }
                UIView.animate(withDuration: 0.2, animations: {
                    
//                })
//                UIView.animate(withDuration: 0.2, delay: 0, options: [], animations: {
                    for fn in animFns ?? [] {
                        fn()
                    }
                })
                
            })
            self.workItem = item
            fns.append(fn)
            animFns.append(animFn)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: item)
        }
    }
}

protocol GenericCellProtocol {
    func updateWidth(width:CGFloat)
}

public class GenericCell<E, T:GenericViewXib<E>>:UITableViewCell, GenericCellProtocol {
    private(set) weak var cellDataView:T!
    weak var table:UITableView?
    public var viewConstants:CustomInsetConstants { return .init()}
//    private var lastUpdateClosure:(() -> Void)?
    private var isLayouted:Bool = false
    
    required override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }
    
    func updateWidth(width: CGFloat) {
        if self.contentView.frame.width != width {
            self.contentView.frame.size.width = width
        }
    }
    
    private func setup() {
        
        createDataView()
    }

    private func createDataView() {
        
        let view = T()
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        
        view.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(view)
        let bottomAnchor = self.contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: viewConstants.bottom)
        bottomAnchor.priority = .init(rawValue: 999)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor,constant: viewConstants.left),
            view.topAnchor.constraint(equalTo: self.contentView.topAnchor,constant: viewConstants.top),
            view.rightAnchor.constraint(equalTo: self.contentView.rightAnchor,constant: viewConstants.right),
            bottomAnchor
        ])
        
        cellDataView = view
    }
    
    func updateData(data:E) {
        configureCell(data: data)
    }
    
    open func configureCell(data:E) {
//        if isLayouted {
        cellDataView.configure(data: data)
//        } else {
//            lastUpdateClosure = {[weak self, data] in
//                guard let self = self else {return}
//                self.cellDataView?.configure(data: data)
//            }
//        }
    }
    
}
public struct CustomInsetConstants {
    var top:CGFloat = 0
    var bottom:CGFloat = 0
    var left:CGFloat = 0
    var right:CGFloat = 0
}

public class SimpleGenericTableViewCell<E, T:GenericViewXib<E>>: GenericCell<E,T> {
    public override var viewConstants: CustomInsetConstants { return .init(top: 8, bottom: 8, left: 8, right: -8)}
}
public class SimpleGenericTableViewCellZeroSpace<E, T:GenericViewXib<E>>: GenericCell<E,T> {
    public override var viewConstants: CustomInsetConstants { return .init(top: 0, bottom: 0, left: 0, right: 0)}
}
extension SimpleGenericTableViewCell: GenericTableDataCellProtocol {
    public func updateDataInCell(data: GenericTableDataEquatable) {
        if let d = data as? E {
            self.updateData(data: d)
        }
        
    }
}
extension SimpleGenericTableViewCellZeroSpace: GenericTableDataCellProtocol {
    public func updateDataInCell(data: GenericTableDataEquatable) {
        if let d = data as? E {
            self.updateData(data: d)
        }
        
    }
}

fileprivate extension UIView {
    func parentView<T: UIView>(of type: T.Type) -> T? {
        guard let view = superview else {
            return nil
        }
        return (view as? T) ?? view.parentView(of: T.self)
    }
}
