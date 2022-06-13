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

public class GenericTableView:UIView, UITableViewDelegate, UITableViewDataSource {
    private lazy var serialQueue = DispatchQueue(label: "GenericTableQueue")
    
    public class CustomTableView:UITableView {
        private var updateQueue:DispatchQueue = .init(label: "CustomTableView-update")
        private var updateCount:Int = 0
        private var updateUICount:Int = 0
        
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
        /*
        public override func beginUpdates() {
//            print("beginUpdates begin \(Date()) \(hasUncommittedUpdates) \(isLayouted)")
            updateQueue.sync {
                updateCount += 1
//                super.beginUpdates()
            }
//            print("beginUpdates updateCount:\(updateCount)")
            super.beginUpdates()
        }
        
        public override func endUpdates() {
//            print("beginUpdates end \(Date()) \(hasUncommittedUpdates) \(isLayouted)")
            updateQueue.sync {
                updateCount -= 1
//                super.endUpdates()
            }
//            print("endUpdates updateCount:\(updateCount)")
            super.endUpdates()
        }*/
        /*
        public func beginUpdateUI() {
//            print("beginUpdates ui begin \(Date()) \(hasUncommittedUpdates) \(isLayouted)")
            let canUpdate:Bool = updateQueue.sync {
                if updateCount == 0 && isLayouted {
                    updateCount += 1
                    updateUICount += 1
//                    super.beginUpdates()
                    return true
                }
                return false
            }
//            print("beginUpdateUI updateCount:\(updateCount)")
            if canUpdate {
                super.beginUpdates()
            }
        }
        public func endUpdateUI() {
//            print("beginUpdates ui end \(Date()) \(hasUncommittedUpdates) \(isLayouted)")
            let canUpdate:Bool = updateQueue.sync {
                updateUICount -= 1
                if updateCount == 1 {
                    updateCount = 0
                    return true
                }
                return false
            }
//            print("endUpdateUI updateCount:\(updateCount)")
            if canUpdate {
                super.endUpdates()
            }
        }*/
    }
    
    private var tableViewCreationClosure: ((CustomTableView) -> Void)?

    private var observers:NSHashTable<GenericTableViewProtocol> = .init(options: .weakMemory)
    
    public func addObserver(object:GenericTableViewProtocol) {
        observers.add(object)
    }
    public func removeObserver(object:GenericTableViewProtocol) {
        observers.remove(object)
    }
    
//    private enum LocalStringData:String{
//        case loadingState = "Обновление"
//        case releaseToRefresh = "Отпустите"
//        case pullToRefresh = "Потяните вниз"
//    }
    
//    public enum Orientation {
//        case vertical
//        case horizontal
//    }
    
    public enum AnimationType {
        case none
        case auto
        
        func getAnimationType(animation:UITableView.RowAnimation)->UITableView.RowAnimation {
            switch self {
            case .auto:
                return animation
            default:
                return .none
            }
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
    
    /*
    var hasRefresher:Bool = false{
        didSet{
            if (hasRefresher){
                _ = refreshView
            }
            
        }
    }
    
    private lazy var refreshViewAnimator:ESRefreshHeaderAnimator = {
        let t = ESRefreshHeaderAnimator()
        t.loadingDescription = LocalStringData.loadingState.rawValue
        t.releaseToRefreshDescription = LocalStringData.releaseToRefresh.rawValue
        t.pullToRefreshDescription = LocalStringData.pullToRefresh.rawValue
        return t
    }();
    private lazy var refreshView:ESRefreshHeaderView = {
        let tt = tableView.es.addPullToRefresh(animator: refreshViewAnimator, handler: {[weak self] in
            self?.refreshItemsMethod?();
        })
        return tt;
    }()*/
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
                    let testSection:GenericTableSection<GenericTableHorizontalSection.Config> = .init(config: .init(headerView: nil, data: [.init(section: section, tableViewFn: tableViewFn, height: config.height, inset: config.inset)], animationType: .auto))
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
        tableViewCreationClosure: ((CustomTableView) -> Void)? = nil
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
    
    private var tableDataInUpdating:Bool = false
    
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
        
//        if (config.orientation == .horizontal) {
//            tableView.transform = CGAffineTransform(rotationAngle: -.pi / 2 )
//        }
    }
    
    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        if (indexPath.section == config.sections.count && indexPath.row == (config.sections[config.sections.count - 1].getItemCount() - 1) && /*!isLoading && */ !tableDataInUpdating && loadMoreItemsMethod != nil) {
            loadMoreItemsMethod?(config.sections[config.sections.count - 1].getItemCount())
        }
        if let section = (config.sections.count >= indexPath.section ? config.sections[indexPath.section] : nil), indexPath.row == (section.getItemCount() - 1) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {[weak section] in
                section?.onLastItemShow()
            })
        }
        
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
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        let sectionCount = self.config?.sections.count ?? 0
        return sectionCount
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section < self.config.sections.count {
            
            let section = self.config.sections[section]
//            if case .horizontal(let data) = self.config.sections[section].getOrientation() {
////
//            }
            return section.getItemCount()
        }
        return 0
    }
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let hasHeader = (section < self.config.sections.count) ? self.config.sections[section].getHeaderView() != nil : false
//        print("heightForHeaderInSection (\(section)):\(hasHeader)")
        return hasHeader ? UITableView.automaticDimension : 0
    }
    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = (section < self.config.sections.count) ? self.config.sections[section].getHeaderView() : nil
//        print("viewForHeaderInSection: (\(section))\(headerView)")
        return headerView
        
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let sectionNo:Int = indexPath.section
        if (sectionNo < self.config.sections.count && self.config.sections[sectionNo].isItemHasEmptyView(row: indexPath.row)) {
            return 0
        }
        return UITableView.automaticDimension
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
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let index:Int = indexPath.row
        let sectionNo:Int = indexPath.section
        var cell:UITableViewCell?
        if (sectionNo < self.config.sections.count) {
            cell = self.config.sections[sectionNo].getReusableCellForRow(tableView: tableView, row: index)
        }
        return cell ?? UITableViewCell()
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
                        let fn = {[weak tableView = ss.tableView] in
                            guard let tableView = tableView else {return}
                            tableView.beginUpdates()
                            for method in methods {
                                
                                method(tableView)
                                
                            }
                            tableView.endUpdates()
                        }
                        if hasAnimation {
                            UIView.animate(withDuration: 0, animations: {
                                                        
                                fn()
                                
                            }, completion: { res in
                                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1, execute: {
                                    resMethod()
                                })
                            })
                        } else {
                            UIView.performWithoutAnimation {
                                
                                fn()
                                
                                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1, execute: {
                                    resMethod()
                                })
                            }
                        }
                        
                        
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
