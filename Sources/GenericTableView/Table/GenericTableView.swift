//
//  GenericTableView.swift
//  saas-ios
//
//  Created by Pirogov Aleksey on 20.08.2021.
//  Copyright © 2021 Nikita Zhukov. All rights reserved.
//

import Foundation
import UIKit
// import ESPullToRefresh

@objc
public protocol GenericTableViewProtocol {
    func afterLayout(view:GenericTableView, table:UITableView)
}

public class GenericTableView:UIView, UITableViewDataSource {
    private lazy var serialQueue = DispatchQueue(label: "GenericTableQueue")
    public weak var delegate: GenericTableViewDelegate?
    
    class CustomTableView:UITableView {
//        private var updateQueue:DispatchQueue = .init(label: "CustomTableView-update")
//        private var updateCount:Int = 0
//        private var updateUICount:Int = 0
        
        private(set) var isLayouted:Bool = false
        
        var afterLayoutFn:((CGSize, Bool) -> Void)?
        
        private var lastSize:CGSize?

        public override func layoutSubviews() {
            super.layoutSubviews()
            
            let layouted = isLayouted
            if !isLayouted {

                isLayouted = true
                
            }
            if let afterLayoutFn = afterLayoutFn {
                
                if lastSize != self.contentSize {
                    lastSize = self.contentSize
                    afterLayoutFn(self.contentSize, !layouted)
                }
            }
        }
    }
    
    private var tableViewCreationClosure: ((UITableView) -> Void)?

    private var observers:NSHashTable<GenericTableViewProtocol> = .init(options: .weakMemory)
    
    public func addObserver(object:GenericTableViewProtocol) {
        observers.add(object)
    }
    public func removeObserver(object:GenericTableViewProtocol) {
        observers.remove(object)
    }
    
    public enum AnimationType {
        case none
        case auto
        
        func getAnimationType(animation:UITableView.RowAnimation)->UITableView.RowAnimation {
            switch self {
            case .auto:
                return .automatic
            default:
                return .none
            }
        }
    }
    
    public var table:UITableView? {
        if let tableView = tableView {
            return tableView
        } else {
            self.setNeedsLayout()
            self.layoutIfNeeded()
            return tableView
        }
    }
    
    private var registeredIdentifiers:Set<String> = .init()
    weak var tableView:CustomTableView!
    weak var emptyDataView:UIView?
    
    var loadMoreItemsMethod:((_ offset:Int) -> Void)?
    private weak var viewForHeader:UIView?
    
    var isLayouted:Bool = false
    private(set) var config:Config!
    
    private var canScroll:Bool = true
    private var tableViewHeightConstraint:NSLayoutConstraint?
    
    public struct UpdateSet:Hashable {
        let sectionNo:Int
        let index:Int
    }
    
    public struct Config {
        public init(emptyDataViewType: UIView? = nil, sections: [GenericTableSectionProtocol] = [], insets:UIEdgeInsets? = nil) {
            self.emptyDataViewType = emptyDataViewType
            self.insets = insets
//            self.sections = sections
            self.sections = sections.map {section in
                if case .horizontal(let config) = section.getOrientation() {
                    let tableViewFn:(() -> UITableView?) = {[weak section] in
                        return section?.configFromTable?.tableView?()
                    }
                    let testSection:GenericTableSection<GenericTableHorizontalSection.Config> = .init(config: .init(headerView: nil, data: [.init(section: section, tableViewFn: tableViewFn, height: config.height, interitemSpace: config.interitemSpace, inset: config.inset)], animationType: .auto))
                    config.dataSection = testSection
                    return testSection
                } else {
                    return section
                }
            }
        }
        
        var emptyDataViewType:UIView?
        var sections:[GenericTableSectionProtocol] = []
        let insets:UIEdgeInsets?
        
    }
    func realoadTableView() {
        tableView.reloadData()
    }
    
    private func updateSectionConfig( section:inout GenericTableSectionProtocol) {
        weak var weakSelf = self
        section.configFromTable = .init(updateTableViewMethod: {hasAnimation, methods, beforeUpdate, completion in
            weakSelf?.updateTableDataWithAnimation(hasAnimation:hasAnimation, methods: methods, beforeUpdate: beforeUpdate, res: {
                completion?()
            })
        }, tableView: {
            return weakSelf?.tableView  //?? UITableView()
        }, sectionNum: {section in
            
            let s = section as AnyObject
            let index = weakSelf?.config.sections.firstIndex(where: {ss in (ss as AnyObject) === s})
            return index ?? -1
            
        })
        
        (section as? GenericTableSection<GenericTableHorizontalSection.Config>)?.config.data.first?.section.configFromTable = section.configFromTable

    }
    
    public class func createTableView<V:UIView>(
        parentView: UIView,
        emptyDataViewType: V.Type? = EmptyDataView.self as? V.Type,
        config: Config,
        canScroll: Bool = true,
        tableViewCreationClosure: ((UITableView) -> Void)? = nil
    ) -> GenericTableView {
        let table = GenericTableView()
        table.tableViewCreationClosure = tableViewCreationClosure
        table.canScroll = canScroll
        
        table.config = config
        for var section in table.config.sections {
            table.updateSectionConfig(section: &section)
        }
        
        table.translatesAutoresizingMaskIntoConstraints = false
        
        parentView.addSubview(table)
        
        NSLayoutConstraint.activate([
            table.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            canScroll ? table.topAnchor.constraint(equalTo: parentView.topAnchor, constant: 0) : parentView.heightAnchor.constraint(equalTo: table.heightAnchor, constant: 0),
//            table.topAnchor.constraint(equalTo: parentView.topAnchor),
            table.rightAnchor.constraint(equalTo: parentView.rightAnchor),
            table.bottomAnchor.constraint(equalTo: parentView.bottomAnchor)
            
        ])
        table.backgroundColor = UIColor.clear
        
        if let t = emptyDataViewType {
            let view = t.init(frame: .zero)
            
            view.translatesAutoresizingMaskIntoConstraints = false
            parentView.addSubview(view)
//            view.backgroundColor = .blue
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
                view.topAnchor.constraint(equalTo: parentView.topAnchor),
                view.rightAnchor.constraint(equalTo: parentView.rightAnchor),
                view.bottomAnchor.constraint(equalTo: parentView.bottomAnchor)
            ])
            view.alpha = 0
            view.isUserInteractionEnabled = false
            table.emptyDataView = view
        }
        
//        table.layoutIfNeeded()
        
        return table
    }
    
    private func showEmptyData() {
        
        showHideEmptyDataView(isShow: true)
    }
    
    private func hideEmptyData() {
        
        showHideEmptyDataView(isShow: false)
    }
    private func showHideEmptyDataView(isShow:Bool) {
        if let view = emptyDataView {
            let curAlpha = view.alpha
            let nextAlpha:CGFloat = isShow ? 1 : 0
            if (curAlpha != nextAlpha) {
                
                UIView.animate(withDuration: 0.5, animations: {
                    view.alpha = nextAlpha
                })
            }
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        if (!isLayouted) {
            isLayouted = true
            setup()
        }
    }
    public var refreshItemsMethod:(() -> Void)? {
        didSet {
            
        }
        
    }
    var isLoading:Bool = false
    
    private var _tableDataInUpdating:Bool = false
    private var _tableDataInUpdatingQueue:DispatchQueue = .init(label: "_tableDataInUpdatingQueue")
    
    var tableDataInUpdating:Bool {
        get {
            return _tableDataInUpdatingQueue.sync {return _tableDataInUpdating}
        }
        set {
            _tableDataInUpdatingQueue.sync {_tableDataInUpdating = newValue}
        }
    }
    
    private func createTableView() {
        let table = CustomTableView(frame: CGRect.zero)

        if !canScroll {
            table.bounces = false
            table.alwaysBounceVertical = false
            table.alwaysBounceHorizontal = false
            table.isScrollEnabled = false

        }
        
        table.afterLayoutFn = {[weak self] size, isFirst in self?.afterTableViewLayouted(size:size, isFirst: isFirst)}

        table.translatesAutoresizingMaskIntoConstraints = false
        addSubview(table)
        NSLayoutConstraint.activate([
            table.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: 0),
            table.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 0),
            table.topAnchor.constraint(equalTo: self.topAnchor, constant: 0),
            table.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: 0)
        ])
        
        table.backgroundColor = UIColor.clear
        
        if #available(iOS 15.0, *) {
            table.sectionHeaderTopPadding = 0
        }
        if let insets = config.insets {
            table.contentInset = insets
        }
        
        self.tableView = table
        tableViewCreationClosure?(table)
    }
    
    private func afterTableViewLayouted(size:CGSize, isFirst:Bool) {

        if !canScroll {
            
            if let tableViewHeightConstraint = tableViewHeightConstraint {
                tableViewHeightConstraint.constant = size.height
            } else {
                let constraint = self.heightAnchor.constraint(equalToConstant: size.height)
                tableViewHeightConstraint = constraint
                NSLayoutConstraint.activate([
                    constraint
                ])
            }
        }
        
        if isFirst {
            let objects = observers.allObjects
            objects.forEach {_ = $0.afterLayout(view: self, table: tableView) }
        }

    }
    
    private func setup() {
        createTableView()
        weak var weakSelf = self
        tableView.delegate = weakSelf
        tableView.dataSource = weakSelf
        
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = UITableView.automaticDimension
        tableView.rowHeight = UITableView.automaticDimension
        tableView.allowsSelection = false
//        print("create table view:\(tableView)")
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        
    }
    
    public func updateSection(section: GenericTableSectionProtocol, at index:Int) {
//
        DispatchQueue.global().async {[weak self] in
            self?.serialQueue.sync {[weak self] in
                let group:DispatchGroup = .init()
                group.enter()
                
                DispatchQueue.main.async {[weak self] in
                    guard let self = self else {return}
                    
                    let sectionIndex:Int
                    let inserted:Bool
                    if self.config.sections.count > index {
                        self.config.sections[index] = section
                        sectionIndex = index
                        inserted = false
                    } else {
                        self.config.sections.append(section)
                        sectionIndex = self.config.sections.count
                        inserted = true
                    }
                    let indexSet:IndexSet = .init(arrayLiteral: sectionIndex)
                    
                    CATransaction.begin()
                    CATransaction.lock()
                    CATransaction.setDisableActions(true)
                    
                    if inserted {
                        self.tableView.insertSections(indexSet, with: .automatic)
                    } else {
                        self.tableView.reloadSections(indexSet, with: .automatic)
                    }
                    
                    CATransaction.unlock()
                    CATransaction.commit()
                    CATransaction.flush()
                }
                
                group.leave()
            }
        }
    }
    
    public func updateSections(_ sections: [GenericTableSectionProtocol]) {
        if (!Thread.current.isMainThread) {
            DispatchQueue.main.sync {
                [weak self] in
                
                self?.updateSections(sections)
            }
            return
        }
        if self.tableView == nil {
            self.config.sections = sections
            for var section in config.sections {
                updateSectionConfig(section: &section)
            }
            return
        }
        
        var sectionsChangings = [SectionChangings]()
        var index = 0
        for section in sections {
            if config.sections.count > index {
                if let changings = config.sections[index].getSectionChangings(for: section, sectionIndex: index) {
                    sectionsChangings.append(changings)
                } else {
                    sectionsChangings.append(.init(
                        sectionIndex: index,
                        changingsType: .reload,
                        beforeUpdate: {
                            [weak self, index] in
                            
                            self?.config.sections[index] = section
                        }
                    ))
                }
            } else {
                sectionsChangings.append(.init(
                    sectionIndex: index,
                    changingsType: .insert,
                    beforeUpdate: {
                        [weak self] in
                        
                        self?.config.sections.append(section)
                    }
                ))
            }
            index += 1
        }
        if config.sections.count > index {
            (index ..< config.sections.count).reversed().forEach {
                sectionIndex in
                
                sectionsChangings.append(.init(
                    sectionIndex: sectionIndex,
                    changingsType: .delete,
                    beforeUpdate: {
                        [weak self, sectionIndex] in
                        
                        self?.config.sections.remove(at: sectionIndex)
                    }
                ))
            }
        }
        let methods = sectionsChangings.compactMap { $0.generateMethod() }
        if !methods.isEmpty {
            updateTableDataWithAnimation(
                methods: methods,
                beforeUpdate: {}
            )
        }
    }
    
    public func reloadTableData(set:Set<UpdateSet>) {
        if (!Thread.current.isMainThread) {
            DispatchQueue.main.sync {[weak self] in
                self?.reloadTableData(set: set)
            }
            return
        }
        var indexPaths:[IndexPath] = []
        for item in set {
            indexPaths.append(.init(row: item.index, section: item.sectionNo))
        }
        let updateAction:((UITableView) -> Void) = {uiTableView in
            uiTableView.reloadRows(at: indexPaths, with: .middle)
        }
        updateTableDataWithAnimation(method: updateAction, beforeUpdate: nil)
    }
    
    private func updateTableDataWithAnimation(hasAnimation: Bool = true, method:@escaping((UITableView) -> Void),beforeUpdate:(() -> Void)?, res:(() -> Void)? = nil) {
        updateTableDataWithAnimation(hasAnimation: hasAnimation, methods: [method], beforeUpdate: beforeUpdate, res: res)
    }
    private func updateTableDataWithAnimation(hasAnimation: Bool = true, methods:[((UITableView) -> Void)],beforeUpdate:(() -> Void)?, res:(() -> Void)? = nil) {
//        DispatchQueue.global().async {[weak self] in
//            self?.serialQueue.sync {[weak self] in
//                let group:DispatchGroup = .init()
//                group.enter()
                
                DispatchQueue.main.async {[weak self] in
                
                    weak var weakSelf = self
                    var allDataCount:Int = 0
                    self?.config.sections.forEach({allDataCount += $0.getItemCount()})
                    if (allDataCount > 0) {
                        self?.hideEmptyData()
                    } else {
                        self?.showEmptyData()
                    }
                    if let ss = weakSelf {
                        ss.tableDataInUpdating = true
                        
                        let resMethod:(() -> Void) = {
                            weakSelf?.tableDataInUpdating = false
                            DispatchQueue.main.async {
                                res?()
                            }
                        }
                        beforeUpdate?()
                        let group:DispatchGroup = .init()
                        let fn = {[weak tableView = ss.tableView] in
                            guard let tableView = tableView else {resMethod(); return}
                            group.enter()
                            tableView.performBatchUpdates({
                                for method in methods {
                                    method(tableView)
                                }
                            }, completion: {res in
                                group.leave()
                            })
                        }
                        if hasAnimation {
                            fn()
                        } else {
                            UIView.performWithoutAnimation {
                                fn()
                            }
                        }
                        group.notify(queue: .global(), execute: {
                            resMethod()
                        })
                        
                        /*
                        CATransaction.begin()
                        CATransaction.lock()
//                        CATransaction.setDisableActions(true)
                        
//                        ss.tableView.layer.removeAllAnimations()
                        
                        CATransaction.setCompletionBlock(resMethod)
                        
                        beforeUpdate?()
                        
                        ss.tableView.beginUpdates()
                        for method in methods {
                            
                            method(ss.tableView)
                            
                        }
                        ss.tableView.endUpdates()
                        CATransaction.unlock()
                        CATransaction.commit()
                        CATransaction.flush()*/
                    }
                    
                }
//                group.wait()
//            }
//        }
        
        
        
    }
}
