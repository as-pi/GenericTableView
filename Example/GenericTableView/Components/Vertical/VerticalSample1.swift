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
    @IBOutlet weak var descriptionLabel: UILabel!
    
    @IBOutlet weak var descrStackView: UIStackView!
    @IBOutlet weak var nameLabel: UILabel!
    class Config {
        init(id: Int, name: String, showDescription: Bool = false, onClick: ((Int, String) -> Void)?) {
            self.id = id
            self.name = name
            self.description = "This test description to show multiline availability of self sizing cell"
            self.showDescription = showDescription
            self.onClick = onClick
        }
        
        let id:Int
        let name:String
        let description:String
        var showDescription:Bool
        let onClick:((Int, String) -> Void)?
    }
    
    override func setupIfNeeded() {
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(clickOnView))
        
        self.addGestureRecognizer(tapGesture)
    }
    
    @objc
    private func clickOnView() {
        let tableView = self.parentView(of: UITableView.self)
        tableView?.beginUpdates()
        self.data.showDescription = !self.data.showDescription
        descrStackView.isHidden = !data.showDescription
        
        setNeedsLayout()
        layoutIfNeeded()
        
        tableView?.endUpdates()
        
        self.data.onClick?(self.data.id, self.data.name)
    }
    
    override func configure(data: Config) {
        self.data = data
        nameLabel.text = data.name
        descriptionLabel.text = data.description
        descrStackView.isHidden = !data.showDescription
        
        setNeedsLayout()
        layoutIfNeeded()
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
        if let to = to as? CellDataType, to.id == id, to.name == name, to.description == description, to.showDescription == showDescription {
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
