//
//  File.swift
//  
//
//  Created by Aleksey on 05.03.2022.
//

import Foundation
import UIKit

public class LoadingView:GenericViewXib<LoadingView.Config> {
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    public override class var bundle: Bundle {return .module}
    
    public struct Config {
        public init() {
            
        }
    }
    public override func configure(data: Config) {
        if !activityIndicator.isAnimating {
            activityIndicator.startAnimating()
        }
    }
}

extension LoadingView.Config: GenericTableDataEquatable {
    typealias CellDataType = LoadingView.Config
    typealias CellView = LoadingView
    
    typealias CellType =
    SimpleGenericTableViewCellZeroSpace<CellDataType, CellView>
    
    public func isViewHidden() -> Bool {
        return false
    }
    
    public func isEqual(_ to: GenericTableDataEquatable) -> Bool {
        return (to as? LoadingView.Config) != nil
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
    static func createLoadingSection() -> GenericTableSection<LoadingView.Config> {
        return GenericTableSection<LoadingView.Config>.init(config: .init(headerView: nil, data: [.init()], animationType: .auto))
    }
}
