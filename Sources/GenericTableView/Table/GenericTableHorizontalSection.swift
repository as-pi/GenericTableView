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
    
    /*
    func reloadDataAfterResize() {
        print("reloadDataAfterResize")
        
        (collectionViewLayout as? UICollectionViewFlowLayout)?.invalidateLayout()
        
    }*/
}

class GenericTableHorizontalSection:GenericViewXib<GenericTableHorizontalSection.Config> {
    
    @IBOutlet var parentView: UIView!
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!
    
    public override class var bundle: Bundle {
        return .module
    }
    
    private weak var collectionView: CustomCollectionView! {return self.data.collectionView}
    
    
    public class Config:NSObject {
        public init(section: GenericTableSectionProtocol, tableViewFn: (() -> UITableView?)?, height:CGFloat = 150, interitemSpace:CGFloat, inset:UIEdgeInsets? = nil) {
            self.section = section
            self.height = height
            self.inset = inset
            self.tableViewFn = tableViewFn
            self.interitemSpace = interitemSpace
        }
        let tableViewFn:(() -> UITableView?)?
        let interitemSpace:CGFloat
        let height:CGFloat
        let section:GenericTableSectionProtocol
        let inset:UIEdgeInsets?
        var scrollContentOffset:CGPoint?
        
        fileprivate weak var collectionView:CustomCollectionView?
        
        var updateDataMethod:(([GenericTableDataEquatable]) -> Bool)?
    }
    
    private func createCollectionView() {
        guard parentView.subviews.count == 0, let data = self.data else {return}
        
        if !alreadyLayouted {
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
        
        if let collectionView = data.collectionView {
            collectionView.removeFromSuperview()
            
            parentView.addSubview(collectionView)
            
        } else {
            let layout:UICollectionViewFlowLayout = .init()
            
            if let inset = data.inset {
                layout.sectionInset = inset
            }
            
            layout.minimumInteritemSpacing = data.interitemSpace
            layout.minimumLineSpacing = data.interitemSpace
            layout.estimatedItemSize = .zero
            layout.scrollDirection = .horizontal
            
            let collectionView:CustomCollectionView = .init(frame: .init(origin: .zero, size: .init(width: self.frame.width, height: data.height + (data.inset?.top ?? 0) + (data.inset?.bottom ?? 0))), collectionViewLayout: layout)
            
            collectionView.backgroundColor = .clear
            
            collectionView.delegate = data
            
            collectionView.dataSource = data
            
            collectionView.scrollIndicatorInsets = .zero
            collectionView.alwaysBounceVertical = false
            collectionView.alwaysBounceHorizontal = true
            collectionView.contentInset = .zero
            
            collectionView.showsVerticalScrollIndicator = false
            collectionView.showsHorizontalScrollIndicator = false
            
            collectionView.register(.init(nibName: "\(GenericTableCollectionViewCell.self)", bundle: .module), forCellWithReuseIdentifier: data.getCellReuseIdentifier())
            
            
            collectionView.tableView = data.tableViewFn?()
            
            parentView.addSubview(collectionView)
            
            data.collectionView = collectionView
        }
        
    }
    
    private func updateData(dataOld: [GenericTableDataEquatable]?, dataNew: [GenericTableDataEquatable]) -> Bool {
        guard let dataOld = dataOld else {return false}
        /*
        let itemsOld = dataOld
        let itemsNew = dataNew
//        if itemsOld.count != itemsNew.count || itemsOld.count == 0 || itemsNew.count == 0 {
//            return false
//        }
        
        var indexes:[Int] = []
        for (index,item) in itemsNew.enumerated() {
            if  !item.isEqual(itemsOld[index]) {
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
        */
        let method = {[weak self] in UIView.performWithoutAnimation {self?.collectionView.reloadData()}}
        DispatchQueue.main.async {
            
            method()
        }
        return true
    }
    
    private func needUpdateData(data: [GenericTableDataEquatable]) -> Bool {
        return updateData(dataOld: self.data?.section.getItems(), dataNew: data)
    }
    
    public override func configure(data: Config) {
        self.data = data
        
        createCollectionView()
        
        data.updateDataMethod = {[weak self] data in return self?.needUpdateData(data: data) ?? false}
        
        
        if data.section.getItemCount() > 0 {
            heightConstraint.constant = data.height + (data.inset?.top ?? 0) + (data.inset?.bottom ?? 0)
            collectionView.alpha = 1
        } else {
            heightConstraint.constant = 0
            collectionView.alpha = 0
        }
        
        if let offset = data.scrollContentOffset {
            collectionView?.setContentOffset(offset, animated: false)
        }
        
    }
    
}

extension GenericTableHorizontalSection.Config: UICollectionViewDelegateFlowLayout {

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.scrollContentOffset = scrollView.contentOffset
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let size:CGSize
        if let cellSize = GenericTableCollectionViewCell.CellSizes.getData(view: collectionView, indexPath: indexPath) {
            size = .init(width: cellSize.width, height: self.height)
            
        } else {
            size = .init(width: 1, height: 1)
        }
        return size
    }
}

extension GenericTableHorizontalSection.Config: UICollectionViewDataSource{
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell:UICollectionViewCell = collectionView.dequeueReusableCell(withReuseIdentifier: getCellReuseIdentifier(), for: indexPath)
        
        let inset = (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset
        
        (cell as? GenericTableCollectionViewCell)?.configureCell(item: self.section.getItems()[indexPath.row], height: self.height, collectionView: collectionView, indexPath: indexPath)
        
        return cell
    }
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {

        let count:Int = self.section.getItemCount()
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
