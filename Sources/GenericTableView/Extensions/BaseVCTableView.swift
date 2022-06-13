//
//  File.swift
//  
//
//  Created by Aleksey on 13.06.2022.
//

import Foundation
import UIKit

private class RefreshControl: UIRefreshControl {
    var onValueChanged: ((UIRefreshControl) -> Void)?

    override init() {
        super.init()
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        self.addTarget(self, action: #selector(self.refresh), for: .valueChanged)
    }

    @objc
    private func refresh(_ sender: UIRefreshControl) {
        onValueChanged?(self)
    }
}

private class BaseVCTableViewConfig {
    init(tableView: GenericTableView? = nil,
         refreshControl: UIRefreshControl? = nil,
         refreshClosure: ((UIRefreshControl) -> Void)? = nil) {
        self.tableView = tableView
        self.refreshControl = refreshControl
        self.refreshClosure = refreshClosure
    }

    weak var tableView: GenericTableView?
    weak var refreshControl: UIRefreshControl?
    var refreshClosure: ((_ sender: UIRefreshControl) -> Void)?
}

private let tableViewConfigs: NSMapTable<UIViewController, BaseVCTableViewConfig> = .init(keyOptions: .weakMemory, valueOptions: .strongMemory)

public protocol BaseVCTableView {}

public extension BaseVCTableView where Self: UIViewController {
    weak var tableView: GenericTableView? {return tableViewConfigs.object(forKey: self)?.tableView}
    weak var refreshControl: UIRefreshControl? {return tableViewConfigs.object(forKey: self)?.refreshControl}
    var refreshClosure: ((_ sender: UIRefreshControl) -> Void)? {return tableViewConfigs.object(forKey: self)?.refreshClosure}
    
    func createTableView<V: UIView>(
        parentView: UIView,
        emptyDataViewType: V.Type? = nil,
        config: GenericTableView.Config,
        canScroll: Bool = true,
        refreshClosure: ((_ sender: UIRefreshControl) -> Void)? = nil
    ) {
        let control: RefreshControl? = refreshClosure == nil ? nil : .init()
        control?.onValueChanged = refreshClosure
        
        let tableView = GenericTableView.createTableView(
            parentView: parentView,
            emptyDataViewType: emptyDataViewType,
            config: config,
            canScroll: canScroll,
            tableViewCreationClosure: {tableView in
                if let control = control {
                    tableView.addSubview(control)
                }
            }
        )
        let config: BaseVCTableViewConfig = .init(tableView: tableView,
                                                 refreshControl: control,
                                                 refreshClosure: refreshClosure)
        tableViewConfigs.setObject(config, forKey: self)
    }

    func updateSections(_ sections: [GenericTableSectionProtocol]) {
        tableView?.updateSections(sections)
    }

    func endRefreshing() {
        refreshControl?.endRefreshing()
    }
}
