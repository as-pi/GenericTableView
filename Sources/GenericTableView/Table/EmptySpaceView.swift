//
//  File.swift
//  
//
//  Created by Aleksey on 23.02.2022.
//

import Foundation
import UIKit

public class EmptySpaceView:GenericViewXib<EmptySpaceView.Config> {
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!
    public override class var bundle: Bundle {return .module}
    
    public struct Config:Equatable {
        public init(height: CGFloat, backgroundColor: UIColor?) {
            self.height = height
            self.backgroundColor = backgroundColor
        }
        
        let height:CGFloat
        let backgroundColor:UIColor?
    }
    public override func configure(data: Config) {
        heightConstraint.constant = data.height
        self.backgroundColor = data.backgroundColor
    }
}

extension EmptySpaceView.Config: GenericTableDataEquatable {
    typealias CellDataType = EmptySpaceView.Config
    typealias CellView = EmptySpaceView
    
    typealias CellType =
    SimpleGenericTableViewCellZeroSpace<CellDataType, CellView>
    
    public func isViewHidden() -> Bool {
        return false
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

public extension GenericTableView {
    static func createEmptySpaceSection(height:CGFloat, backgroundColor:UIColor? = nil) -> GenericTableSection<EmptySpaceView.Config> {
        return .init(config: .init(headerView: nil, data: [.init(height: height, backgroundColor: backgroundColor)], animationType: .none))
    }
}
