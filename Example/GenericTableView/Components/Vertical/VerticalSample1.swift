//
//  VerticalSample1.swift
//  GenericTableView
//
//  Created by Aleksey on 13.06.2022.
//

import Foundation
import GenericTableView
import UIKit

class VerticalSample1:GenericViewXib<VerticalSample1.Config> {
    override class var bundle: Bundle {return .main}
    
    @IBOutlet weak var nameLabel: UILabel!
    struct Config {
        let id:Int
        let name:String
        let onClick:((Int, String) -> Void)?
    }
    
    override func setupIfNeeded() {
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(clickOnView))
        
        self.addGestureRecognizer(tapGesture)
    }
    
    @objc
    private func clickOnView() {
        self.data.onClick?(self.data.id, self.data.name)
    }
    
    override func configure(data: Config) {
        self.data = data
        nameLabel.text = data.name
        
    }
}

extension VerticalSample1.Config: GenericTableDataEquatable {
    typealias CellDataType = VerticalSample1.Config
    typealias CellView = VerticalSample1
    
    typealias CellType =
    SimpleGenericTableViewCellZeroSpace<CellDataType, CellView>
    
    func isViewHidden() -> Bool {
        return false
    }
    
    func isEqual(_ to: GenericTableDataEquatable) -> Bool {
        if let to = to as? CellDataType, to.id == id, to.name == name {
            return true
        }
        return false
    }
    
    func createNewCell() -> UITableViewCell {
        let cell: CellType = .init()
        return cell
    }
    
    func getCellReuseIdentifier() -> String {
        return "\(CellView.self)"
    }
    
}
