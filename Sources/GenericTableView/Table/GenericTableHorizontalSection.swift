//
//  File.swift
//  
//
//  Created by Aleksey on 05.11.2021.
//

import Foundation
import UIKit

protocol GenericTableHorizontalSectionProtocol {
    
}

class CustomCollectionView:UICollectionView {
    weak var tableView:UITableView?
    
    func reloadDataAfterResize() {
        UIView.performWithoutAnimation {
            tableView?.beginUpdates()
            (collectionViewLayout as? UICollectionViewFlowLayout)?.invalidateLayout()
            tableView?.endUpdates()
        }
        
    }
}

class GenericTableHorizontalSection:GenericViewXib<GenericTableHorizontalSection.Config> {
    
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!
    public override class var bundle: Bundle {
        return .module
    }
    @IBOutlet weak var collectionView: CustomCollectionView!
    
    var firstInit:Bool = true
    private var returnedItemsCount:Int? 
    
    public class Config {
        public init(section: GenericTableSectionProtocol, tableViewFn: (() -> UITableView?)?, height:CGFloat = 150, inset:UIEdgeInsets? = nil) {
            self.section = section
            self.height = height
            self.inset = inset
            self.tableViewFn = tableViewFn
        }
        let tableViewFn:(() -> UITableView?)?
        let height:CGFloat
        let section:GenericTableSectionProtocol
        let inset:UIEdgeInsets?
        var scrollContentOffset:CGPoint?
        
        var updateDataMethod:(([GenericTableDataEquatable]) -> Bool)?
    }
    
    public override func setupIfNeeded() {
        
        collectionView.delegate = self
        
        collectionView.dataSource = self
        collectionView.scrollIndicatorInsets = .zero
        collectionView.alwaysBounceVertical = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.contentInset = .zero
        
        (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.estimatedItemSize = .zero
        
        collectionView.setNeedsLayout()
        collectionView.layoutIfNeeded()
        collectionView.alpha = 0
    }
    
    private func updateData(dataOld: [GenericTableDataEquatable]?, dataNew: [GenericTableDataEquatable]) -> Bool {
        guard let dataOld = dataOld else {return false}
        let itemsOld = dataOld
        let itemsNew = dataNew
        if itemsOld.count != itemsNew.count || itemsOld.count == 0 || itemsNew.count == 0 {
            return false
        }
        
        var indexes:[Int] = []
        for (index,item) in itemsNew.enumerated() {
            if !item.isEqual(itemsOld[index]) {
                indexes.append(index)
            }
        }
        let method:(() -> Void)
        if indexes.count == itemsNew.count {
            method = {[weak self] in self?.collectionView.reloadData()}
        } else {
            let indexPaths:[IndexPath] = indexes.map {return .init(row: $0, section: 0)}
            method = {[weak self] in
                UIView.performWithoutAnimation {
                    self?.collectionView.reloadItems(at: indexPaths)
                }
            }
        }
        DispatchQueue.main.async {
            method()
        }
        
        return true
    }
    
    private func needUpdateData(data: [GenericTableDataEquatable]) -> Bool {
        return updateData(dataOld: self.data?.section.getItems(), dataNew: data)
    }
    
//    private func getHeight() -> CGFloat {
//        if self.data.section.getItemCount() > 0 {
//            return data.height + (data.inset?.top ?? 0) + (data.inset?.bottom ?? 0)
////            collectionView.alpha = 1
//        } else {
//            return 0
////            collectionView.alpha = 0
//        }
//    }
    
    public override func configure(data: Config) {
        data.updateDataMethod = {[weak self] data in return self?.needUpdateData(data: data) ?? false}
        collectionView.tableView = data.tableViewFn?()
        var needReload:Bool = true
        if firstInit {
            self.collectionView.register(.init(nibName: "\(GenericTableCollectionViewCell.self)", bundle: .module), forCellWithReuseIdentifier: data.getCellReuseIdentifier())
            
            if let inset = data.inset {
                (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset = inset
            }
            firstInit = false
            needReload = false
        } else {
            
        }
        
//        let oldData = self.data
        self.data = data
        
        if data.section.getItemCount() > 0 {
            heightConstraint.constant = data.height + (data.inset?.top ?? 0) + (data.inset?.bottom ?? 0)
            collectionView.alpha = 1
        } else {
            heightConstraint.constant = 0
            collectionView.alpha = 0
        }
//        heightConstraint.constant = getHeight()
        
        setNeedsLayout()
        layoutIfNeeded()
        
        if returnedItemsCount != self.data.section.getItemCount() {
            let collectionView = self.collectionView
            let offset = data.scrollContentOffset

            DispatchQueue.main.async {
                collectionView?.reloadData()
                if let offset = offset {
                    collectionView?.setContentOffset(offset, animated: false)
                }
            }
        } else if let offset = data.scrollContentOffset {
            collectionView?.setContentOffset(offset, animated: false)
        }
        
//        updateData(dataOld: oldData, dataNew: data)
        if needReload {
            collectionView.reloadData()
        }
    }
    
}

extension GenericTableHorizontalSection: UICollectionViewDelegateFlowLayout {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.data.scrollContentOffset = scrollView.contentOffset
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if let size = GenericTableCollectionViewCell.CellSizes.getData(view: collectionView, indexPath: indexPath) {
            return .init(width: size.width, height: self.data.height)
        }
        let size:CGSize = .init(width: collectionView.frame.size.width, height: self.data?.height ?? 33)
        return size
    }
}

extension GenericTableHorizontalSection:UICollectionViewDataSource {
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell:UICollectionViewCell = collectionView.dequeueReusableCell(withReuseIdentifier: data.getCellReuseIdentifier(), for: indexPath)
        if let data = data, indexPath.row < data.section.getItemCount() {
            let inset = (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset
            
//            cell = collectionView.dequeueReusableCell(withReuseIdentifier: data.getCellReuseIdentifier(), for: indexPath)
            
            (cell as? GenericTableCollectionViewCell)?.configureCell(item: data.section.getItems()[indexPath.row], height: self.data.height - (inset?.top ?? 0) - (inset?.bottom ?? 0), collectionView: collectionView, indexPath: indexPath)
        } else {
            
        }
        return cell
    }
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        self.data == nil ? 0 : 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        returnedItemsCount = self.data?.section.getItemCount() ?? 0
        let count:Int = returnedItemsCount ?? 0
        let alpha:CGFloat = count == 0 ? 0 : 1
        
        if collectionView.alpha != alpha {
            UIView.animate(withDuration: 0.3, animations: {[weak collectionView] in
                collectionView?.alpha = alpha
            })
        }
        
        return count
    }
}

extension GenericTableHorizontalSection: GenericTableDataCellProtocol {
    typealias CellDataType = GenericTableHorizontalSection.Config
    
    public func updateDataInCell(data: GenericTableDataEquatable) {
        if let data = data as? CellDataType {
            self.data = data
            self.configure(data: self.data)
        }
    }
}

extension GenericTableHorizontalSection.Config: GenericTableDataEquatable {
    typealias CellDataType = GenericTableHorizontalSection.Config
    typealias CellView = GenericTableHorizontalSection
    
    typealias CellType = SimpleGenericTableViewCellZeroSpace<CellDataType, CellView>
    
    public func isViewHidden() -> Bool {
        return section.getItemCount() == 0
//        return false
    }
    
    public func isEqual(_ to: GenericTableDataEquatable) -> Bool {
        
        return false
        
    }
    
    public func createNewCell() -> UITableViewCell {
        let cell: CellType = .init()
        return cell
    }
    
    public func getCellReuseIdentifier() -> String {
        return "\(CellView.self)"
    }
    
}
