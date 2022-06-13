//
//  GenericTableCollectionViewCell.swift
//  Indigo
//
//  Created by Aleksey on 05.11.2021.
//  Copyright © 2021 Indigo LLC. All rights reserved.
//

import UIKit

class GenericTableCollectionViewCell: UICollectionViewCell {
    private var isConstraintSetted:Bool = false
    class CellSizes {
        private var workItem:DispatchWorkItem?
        private var isFirstLoad:Bool = true
        
        private static let cellSizes:NSMapTable<UICollectionView, CellSizes> = .init(keyOptions: .weakMemory, valueOptions: .strongMemory)
        
        var sizes:[IndexPath:CGSize] = [:]
        
        private static var queue:DispatchQueue = .init(label: "CellSizes-static-queue")
        private var queue:DispatchQueue = .init(label: "CellSizes-queue")
        private static var updateViewQueue:DispatchQueue = .init(label: "CellSizesUpdateViewQueue-queue")
        
        private func addData(indexPath:IndexPath, size:CGSize) -> Bool {
            var res:Bool = false
            queue.sync {
                if sizes[indexPath]?.width == size.width {
                    res = true
                } else {
                    sizes[indexPath] = size
                }
            }
            return res
        }
        
        private func getData(indexPath:IndexPath) -> CGSize? {
            return queue.sync {
                return sizes[indexPath]
            }
        }
        
        private func hasSize(indexPath:IndexPath) -> Bool? {
            return queue.sync {
                return sizes[indexPath] != nil
            }
        }
        
        static func hasSize(view:UICollectionView, indexPath:IndexPath) -> Bool {
            let cell:CellSizes? = queue.sync {
                return Self.cellSizes.object(forKey: view)
            }
            return cell?.hasSize(indexPath: indexPath) ?? false
        }
        
        static func addData(view:UICollectionView, indexPath:IndexPath, size:CGSize) -> Bool {
            
            let cell:CellSizes = queue.sync {
                if let cell = Self.cellSizes.object(forKey: view) {
                    return cell
                } else {
                    let cell:CellSizes = .init()
                    Self.cellSizes.setObject(cell, forKey: view)
                    return cell
                }
            }
            let result = cell.addData(indexPath: indexPath, size: size)
            if !result {
                
                if cell.isFirstLoad {
                    view.alpha = 0
                    UIView.performWithoutAnimation {
                        view.reloadItems(at: [indexPath])
                    }
                    
                    let item:DispatchWorkItem = .init(block: {[weak cell, weak view] in
                        cell?.isFirstLoad = false
                        
                        (view as? CustomCollectionView)?.reloadDataAfterResize()
                        UIView.performWithoutAnimation {
                            view?.alpha = 1
                        }
                    })
                    
                    updateViewQueue.sync {
                        cell.workItem?.cancel()
                        cell.workItem = item
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: item)
                    }
                } else {
                    DispatchQueue.main.async {[weak view] in
                        UIView.performWithoutAnimation {
                            view?.reloadItems(at: [indexPath])
                        }
                    }
                }
                
            }
            return result
        }
        
        static func getData(view:UICollectionView, indexPath:IndexPath) -> CGSize? {
            
            let cell:CellSizes? = queue.sync {
                return cellSizes.object(forKey: view)
            }
            return cell?.getData(indexPath: indexPath)
        }
    }
    
    private class CustomView:UIView {
        
        var afterLayoutFn:((CustomView, IndexPath?) -> Void)?
        var indexPath:IndexPath?

        override func layoutSubviews() {
            super.layoutSubviews()
            afterLayoutFn?(self,indexPath)
        }
    }
    
    weak var dataCell:GenericTableDataCellProtocol?
    
    func configureCell(item:GenericTableDataEquatable, height:CGFloat, collectionView:UICollectionView, indexPath:IndexPath) {
        
        let cell = item.createNewCell()
        
        cell.alpha = 0
        guard let view = cell.subviews.first?.subviews.first else {print("view is null"); return}
        
        view.removeFromSuperview()
        
        view.translatesAutoresizingMaskIntoConstraints = false
        
        self.dataCell = cell as? GenericTableDataCellProtocol
        
        dataCell?.updateDataInCell(data: item)
        
        let customView:CustomView
        if let view = contentView.subviews.first as? CustomView {
            customView = view
            customView.indexPath = indexPath
        } else {
            let newView:CustomView = .init(frame: .zero)
            newView.indexPath = indexPath
            newView.alpha = 0
            newView.translatesAutoresizingMaskIntoConstraints = false
            
            newView.afterLayoutFn = {[weak collectionView] (view, indexPath) in
                
                guard let collectionView = collectionView, let size = view.subviews.last?.frame.size, let indexPath = indexPath else {return}
                
                _ = CellSizes.addData(view: collectionView, indexPath: indexPath, size: size)
                view.alpha = 1
            }
            contentView.addSubview(newView)
            newView.isUserInteractionEnabled = true
            
            NSLayoutConstraint.activate([
                
                newView.topAnchor.constraint(equalTo: contentView.topAnchor),
                newView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                newView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                newView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
            customView = newView
        }
        
        customView.subviews.forEach {$0.removeFromSuperview()}
        
        customView.addSubview(cell)
        customView.addSubview(view)
        
        if !isConstraintSetted {
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: customView.leadingAnchor),
                view.topAnchor.constraint(equalTo: customView.topAnchor),
                cell.leadingAnchor.constraint(equalTo: customView.leadingAnchor),
                cell.topAnchor.constraint(equalTo: customView.topAnchor)
            ])
            isConstraintSetted = true
        }
        
        if let viewHeightConstraint = view.heightConstraint {
            viewHeightConstraint.constant = height - 0.5
        } else {
            let constraint = view.heightAnchor.constraint(equalToConstant: height - 0.5)
            constraint.priority = UILayoutPriority(999)
            constraint.isActive = true
        }
        if let viewHeightConstraint = cell.heightConstraint {
            viewHeightConstraint.constant = height
        } else {
            let constraint = cell.heightAnchor.constraint(equalToConstant: height)
            constraint.priority = UILayoutPriority(999)
            constraint.isActive = true
        }
        
        customView.setNeedsLayout()
        customView.layoutIfNeeded()
        
    }
    
}

fileprivate extension UIView {

    var heightConstraint: NSLayoutConstraint? {
        get {
            return constraints.first(where: {
                $0.firstAttribute == .height && $0.relation == .equal
            })
        }
    }

    var widthConstraint: NSLayoutConstraint? {
        get {
            return constraints.first(where: {
                $0.firstAttribute == .width && $0.relation == .equal
            })
        }
    }

}
