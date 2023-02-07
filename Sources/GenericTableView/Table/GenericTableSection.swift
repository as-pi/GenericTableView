//
//  GenericTableSection.swift
//  saas-ios
//
//  Created by Aleksey on 21.08.2021.
//  Copyright © 2021 Nikita Zhukov. All rights reserved.
//

import Foundation
import UIKit

public protocol GenericTableDataCellProtocol:AnyObject {
    func updateDataInCell(data:GenericTableDataEquatable)
//    func isViewHidden(data:GenericTableDataEquatable) -> Bool
}

public protocol GenericTableDataEquatable {
    func getCellReuseIdentifier() -> String
    func createNewCell() -> UITableViewCell
    func isEqual(_ to: GenericTableDataEquatable) -> Bool
    func isViewHidden() -> Bool
}

public protocol GenericTableSectionProtocol:AnyObject {
    var configFromTable:GenericTableSectionConfigFromTable! {get set}
    
    func getHeaderView() -> UIView?
    func getItemCount() -> Int
    func getReusableCellForRow(tableView:UITableView, row:Int) -> UITableViewCell?
    func getCellReuseIdentifier(row:Int) -> String
    func configureCellForData(cell:GenericTableDataCellProtocol, row:Int)
    
    func getItems() -> [GenericTableDataEquatable]
    func reloadItemsAtIndexes(indexes:[Int])
    func getSectionChangings(for newSection: GenericTableSectionProtocol, sectionIndex: Int) -> SectionChangings?
    func getCurrentSectionNum() -> Int
    
    func isItemHasEmptyView(row:Int) -> Bool
    
    func getOrientation() -> SectionOrientation
    
    func onItemShow(_ data: OnShowItemData)
}

extension GenericTableSection {
    public func getCellReuseIdentifier(row:Int) -> String {
        let cellData = row < config.data.count ? config.data[row] : nil
        if let data = cellData {
            return data.getCellReuseIdentifier()
        }
        return ""
    }
    public func configureCellForData(cell:GenericTableDataCellProtocol, row:Int) {
        let cellData = row < config.data.count ? config.data[row] : nil
        if let data = cellData {
            cell.updateDataInCell(data: data)
        }
    }
}

public struct SectionChangings {
    
    enum ChangingsType {
        case rowsActions, reload, insert, delete, empty
    }
    
    var sectionIndex: Int
    var changingsType: ChangingsType
    var actions: [((UITableView) -> Void)] = []
    var beforeUpdate: (() -> Void)? = nil
    
    func generateMethod() -> ((UITableView) -> Void)? {
        guard changingsType != .empty else {
            return nil
        }
        return {
            tableView in
            
            beforeUpdate?()
            switch changingsType {
            case .rowsActions:
                actions.forEach {$0(tableView)}
            case .reload:
                tableView.reloadSections(.init(integer: sectionIndex), with: .automatic)
            case .insert:
                tableView.insertSections(.init(integer: sectionIndex), with: .automatic)
            case .delete:
                tableView.deleteSections(.init(integer: sectionIndex), with: .automatic)
            case .empty:
                break
            }
        }
    }
}

public struct GenericTableSectionConfigFromTable {
    var updateTableViewMethod: ((_ hasAnimation: Bool, _ methods:[((UITableView) -> Void)], _ beforeUpdate:(() -> Void)?, _ completion:(() -> Void)?) -> Void)?
    var tableView:(() -> UITableView?)?
    var sectionNum:((_ section:Any) -> Int)?
//    var onLastItemShowFn:(() -> Void)?
}

public enum SectionOrientation {
    case vertical
    case horizontal(HorizontalSectionOrientationConfig)
}

public class HorizontalSectionOrientationConfig {
    
    public init(height: CGFloat, inset: UIEdgeInsets? = nil, interitemSpace:CGFloat = 0) {
        self.height = height
        self.inset = inset
        self.interitemSpace = interitemSpace
    }
    let interitemSpace:CGFloat
    let height:CGFloat
    let inset:UIEdgeInsets?
    var dataSection:GenericTableSection<GenericTableHorizontalSection.Config>!
}

public protocol OnShowItemData {
    var index:Int {get}
    var allCount:Int {get}
}

public class GenericTableSection<T:GenericTableDataEquatable>:GenericTableSectionProtocol {
    private(set) var config:Config
    public var configFromTable:GenericTableSectionConfigFromTable!
    
    private let queue:DispatchQueue = .init(label: "GenericTableSection-queue", qos: .userInteractive)
    
//    struct ShowItemData: OnShowItemData {
//        let index:Int
//        let allCount:Int
//    }
    
    public struct Config {
        public init(headerView: UIView? = nil, data: [T] = [], animationType: GenericTableView.AnimationType, orientation:SectionOrientation = .vertical, onShowItem:((OnShowItemData) -> Void)? = nil) {
            self.headerView = headerView
            self.data = data
            self.animationType = animationType
            self.orientation = orientation
            self.onShowItem = onShowItem
        }
        var onShowItem:((OnShowItemData) -> Void)? // index , allCount
        var headerView:UIView?
        var data:[T] = []
        var animationType:GenericTableView.AnimationType
        let orientation:SectionOrientation
        
        func canUpdateData(newData: Any) -> Bool {
            return (newData as? [T]) != nil
        }
        
        fileprivate mutating func updateData(newData:Any) -> Bool {
            if let newData = newData as? [T] {
                data = newData
                return true
            }
            return false
        }
    }
    public init(config:Config) {
        self.config = config
    }
    
    public func getOrientation() -> SectionOrientation {
        return self.config.orientation
    }
    
    public func getHeaderView() -> UIView? {
        return self.config.headerView
    }
    
    public func onItemShow(_ data: OnShowItemData) {
        config.onShowItem?(data)
    }
    
    public func getItemCount() -> Int {
        return config.data.count
        
    }
    public func getItems() -> [GenericTableDataEquatable] {
        return self.config.data
    }
    
    public func reloadItemsAtIndexes(indexes:[Int]) {
        let sectionNum = getCurrentSectionNum()
        let currCount = getItemCount()
        let toReload:[Int] = indexes.compactMap {return (($0 < currCount) ? $0 : nil)}
        var toReloadSet:Set<Int> = .init()
        toReload.forEach {val in toReloadSet.insert(val)}
        
        if (toReloadSet.count == 0) {
            return
        }
        var set = IndexSet()
        
        toReloadSet.forEach({set.insert($0)})
        let paths = set.convertToRows(section: sectionNum)
        
        let action:((UITableView) -> Void) = { tableView in
            tableView.reloadRows(at: paths, with: .fade)
        }
        let hasAnimation = hasAnimation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {[weak self] in
            self?.configFromTable.updateTableViewMethod?(hasAnimation, [action],nil, nil)
            
        })
    }
    
    private func hasAnimation() -> Bool {
        return self.config.animationType != .none
    }
    
    public func isItemHasEmptyView(row:Int) -> Bool {
        if (row < config.data.count) {
            return config.data[row].isViewHidden()
        }
        return false
    }
    
    public func getReusableCellForRow(tableView:UITableView, row:Int) -> UITableViewCell? {
        if (isItemHasEmptyView(row: row)) {
            return UITableViewCell()
        }
        if (row < config.data.count) {
            let identifier = config.data[row].getCellReuseIdentifier()
            var cell = tableView.dequeueReusableCell(withIdentifier: identifier)
            if (cell == nil) {
                cell = config.data[row].createNewCell()
                if let c = cell {
                    tableView.register(type(of: c), forCellReuseIdentifier: identifier)
                }
            }
            (cell as? GenericCellProtocol)?.updateWidth(width: tableView.frame.size.width)
            
            (cell as? GenericTableDataCellProtocol)?.updateDataInCell(data: config.data[row])
            return cell
        }
        return nil
    }
    
    private func updateHorizontalData(data: inout [T], newData:[T]) {
        data.removeAll()
        data.append(contentsOf: newData)
    }
    
    public func getSectionChangings(for newSection: GenericTableSectionProtocol, sectionIndex: Int) -> SectionChangings? {
        guard let newData = newSection.getItems() as? [T] else {
            return nil
        }
        if case .horizontal(_) = self.config.orientation {
            // TODO: надо еще добавить сравнение данных, на случай если они не изменились
            return .init(
                sectionIndex: sectionIndex,
                changingsType: .reload,
                beforeUpdate: {
                    [weak self] in
                    
                    self?.config.data = newData
                })
        }
        
        if (newData.count == 0) {
            return .init(
                sectionIndex: sectionIndex,
                changingsType: .reload,
                beforeUpdate: {
                    [weak self] in
                    
                    self?.config.data = newData
                })
        } else {
            
            let updates = TableViewUpdates(oldData: config.data, newData: newData, animationType: self.config.animationType)
            if(updates.hasUpdates) {
                var actions:[((UITableView) -> Void)] = []
                if (updates.hasMainUpdates) {
                    actions.append({
                        tableView in

                        updates.createUpdateAction(tableView: tableView, sectionNo: sectionIndex)
                    })
                }
                if (updates.hasReloadUpdates) {
                    actions.append({
                        tableView in

                        updates.createReloadAction(tableView: tableView, sectionNo: sectionIndex)
                    })
                }
                
                if actions.count > 0 {
                    return .init(
                        sectionIndex: sectionIndex,
                        changingsType: .rowsActions,
                        actions: actions,
                        beforeUpdate: {
                            [weak self] in
                            
                            self?.config.data = newData
                        })
                }
            }
            
        }
        return SectionChangings(sectionIndex: sectionIndex, changingsType: .empty)
    }
    
    public func updateItemsIfNeeded(newData:[T], afterUpdateMethod:(() -> Void)? = nil) {
        guard let configFromTable = configFromTable, configFromTable.tableView?() != nil else {
            self.config.data = newData
            return
        }
        if case .horizontal(let data) = self.config.orientation {
            let data1 = data.dataSection.config.data
            let section = data1.first?.section
            if let section = section as? GenericTableSection<T> {
                let method1 = data.dataSection.getData().first?.updateDataMethod
                
                if section.config.canUpdateData(newData: newData), let method = data.dataSection.getData().first?.updateDataMethod, method(newData) {
                    section.config.updateData(newData: newData)
                } else if section.config.updateData(newData: newData) {
                    let tableView = data.dataSection.configFromTable.tableView?()
                    let sectNum = data.dataSection.getCurrentSectionNum()
                    
                    tableView?.reloadSections(.init(integer: sectNum), with: .automatic)
                }
            }
            
            return
        }
        
        let hasAnimation = hasAnimation()
        DispatchQueue.global().async {[weak self] in
            guard let queue = self?.queue else {return}
            let group:DispatchGroup = .init()
            
            let afterUpdateMethod = {[weak self] in
                
                group.leave()
                
                guard self != nil else {return}
                DispatchQueue.main.async {
                    afterUpdateMethod?()
                }
            }
            
            queue.sync {[weak self] in
                
                guard let self = self else {return}
                group.enter()
                if (newData.count == 0) {
                    self.removeAllItems(afterUpdateMethod: afterUpdateMethod)
                } else {
                    
                    let updates = TableViewUpdates(oldData: self.config.data, newData: newData, animationType: self.config.animationType)
                    if(updates.hasUpdates) {
                        weak var weakSelf = self
                        let num:Int = self.getCurrentSectionNum()
                        
                        var actions:[((UITableView) -> Void)] = []
                        
                        if (updates.hasReloadUpdates) {
                            actions.append({tableView in
                                updates.createReloadAction(tableView: tableView, sectionNo: num)
                            })
                        }
                        
                        if (updates.hasMoveUpdates) {
                            actions.append({tableView in
                                updates.createMoveAction(tableView: tableView, sectionNo: num)
                            })
                        }
                        
                        if (updates.hasMainUpdates) {
                            actions.append({tableView in
                                updates.createUpdateAction(tableView: tableView, sectionNo: num)
                            })
                        }
                        
                        if actions.count > 0 {
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                            weakSelf?.configFromTable.updateTableViewMethod?(hasAnimation, actions, {[weak self] in
                                   self?.config.data = newData}, afterUpdateMethod)
                                
//                            })
                        } else {
                            afterUpdateMethod()
                        }
                    } else {
                        afterUpdateMethod()
                    }
                    
                }
                group.wait()
            }
        }
        
        
    }
    
    public func getCurrentSectionNum() -> Int {
        return configFromTable.sectionNum?(self) ?? 0
    }
    
    public func getData() -> [T] {
        return config.data
    }
    
    public func addData(newData:[T]) {
        
        if (newData.count == 0) {
            return
        }
        guard configFromTable != nil else {
            self.config.data.append(contentsOf: newData)
            return
        }
        let currCount = config.data.count
        
        let startIndex = currCount
        let endIndex = startIndex + newData.count - 1
        let num:Int = getCurrentSectionNum()
        let anim = config.animationType.getAnimationType(animation: .bottom)
        let hasAnimation = hasAnimation()
        configFromTable.updateTableViewMethod?(hasAnimation, [ { tableView in
            tableView.insertRows(at: IndexSet(integersIn: startIndex...endIndex).convertToRows(section: num), with: anim)
        }], {[weak self] in self?.config.data.append(contentsOf: newData)}, {})
        
    }
    
    public func removeAllItems(afterUpdateMethod:(() -> Void)? = nil) {
        
        guard let configFromTable = configFromTable, configFromTable.tableView?() != nil else {
            self.config.data = []
            afterUpdateMethod?()
            return
        }
        
        if (self.config.data.count > 0) {
            let allCount = config.data.count - 1
            let num:Int = getCurrentSectionNum()
            
            let hasAnimation = hasAnimation()
            configFromTable.updateTableViewMethod?(hasAnimation, [ { tableView in
                tableView.deleteRows(at: IndexSet(integersIn: 0...allCount).convertToRows(section: num), with: .none)
            }], {[weak self] in self?.config.data = []}, { afterUpdateMethod?()})
            
        } else {
            afterUpdateMethod?()
            
        }
        
    }
}

private class TableViewUpdates {
    private var oldData:[GenericTableDataEquatable] = []
    private var newData:[GenericTableDataEquatable] = []
    private var toDelete:TableViewUpdateWithDirection!
    private var toInsert:TableViewUpdateWithDirection!
    private var toMove:[(Int, Int)] = [] // from - to
    private var toReload:TableViewUpdateWithDirection!
    private var animationType:GenericTableView.AnimationType
    var hasUpdates:Bool {
        return (toDelete.hasUpdates || toInsert.hasUpdates || toMove.count > 0 || toReload.hasUpdates)
    }
    var hasMainUpdates:Bool {
        return (toDelete.hasUpdates || toInsert.hasUpdates)
    }
    var hasMoveUpdates:Bool {
        return (toMove.count > 0)
    }
    var hasReloadUpdates:Bool {
        return toReload.hasUpdates
    }
    
    init(oldData:[GenericTableDataEquatable], newData:[GenericTableDataEquatable], animationType: GenericTableView.AnimationType = .auto) {
        self.oldData = oldData
        self.newData = newData
        self.animationType = animationType
        createUpdates()
    }
    private func createUpdates() {
        
        var newDataIndex:Set<Int> = .init()
        var toDeleteIndex:Set<Int> = .init()
        var toReloadIndex:Set<Int> = .init()
        var toMoveIndex:[(Int, Int)] = []// from - to
        
        for (index, item) in oldData.enumerated() { // поиск перемещений и удаления
            if let newItemIndex = newData.firstIndex(where: {$0.isEqual(item)}) {
                if (index != newItemIndex) {
                    toMoveIndex.append((index, newItemIndex))
                }
            } else {
                toDeleteIndex.insert(index)
            }
        }
        for (index, item) in newData.enumerated() { // поиск новых элементов
            if let _ = oldData.firstIndex(where: {$0.isEqual(item)}) {
                
            } else {
                newDataIndex.insert(index)
            }
        }
        
        toDeleteIndex.filter({newDataIndex.contains($0)}).forEach({
            toReloadIndex.insert($0)
        })
        
        toDeleteIndex.filter {toReloadIndex.contains($0)}.forEach({toDeleteIndex.remove($0)})
        newDataIndex.filter {toReloadIndex.contains($0)}.forEach({newDataIndex.remove($0)})
        
        toMoveIndex.enumerated()
            .filter {(index, item) in toDeleteIndex.contains (item.1)}.reversed()
            .forEach {(index, item) in
                toReloadIndex.insert(item.1)
                toDeleteIndex.remove(item.1)
                toDeleteIndex.insert(item.0)
                toMoveIndex.remove(at: index)
        }
        
        toMoveIndex.enumerated()
            .filter {newDataIndex.contains($0.element.0)}.reversed()
            .forEach {(index, item) in
                toReloadIndex.insert(item.0)
                newDataIndex.remove(item.0)
                newDataIndex.insert(item.1)
                toMoveIndex.remove(at: index)
            }
        
        toDelete = TableViewUpdateWithDirection(oldData: oldData, newData: newData, toUpdateIndexItemArray: .init(toDeleteIndex))
        toInsert = TableViewUpdateWithDirection(oldData: oldData, newData: newData, toUpdateIndexItemArray: .init(newDataIndex))
        toReload = TableViewUpdateWithDirection(oldData: oldData, newData: newData, toUpdateIndexItemArray: .init(toReloadIndex))
        
        toMove = toMoveIndex
        
    }
    
    func createUpdateAction(tableView:UITableView, sectionNo:Int) {
        if let set = toInsert.topIndexSet {
            tableView.insertRows(at: set.convertToRows(section: sectionNo), with: animationType.getAnimationType(animation: .top))
        }
        if let set = toInsert.rightIndexSet {
            tableView.insertRows(at: set.convertToRows(section: sectionNo), with: animationType.getAnimationType(animation: .right))
        }
        if let set = toInsert.leftIndexSet {
            tableView.insertRows(at: set.convertToRows(section: sectionNo), with: animationType.getAnimationType(animation: .left))
        }
        if let set = toInsert.bottomIndexSet {
            tableView.insertRows(at: set.convertToRows(section: sectionNo), with: animationType.getAnimationType(animation: .bottom))
        }
        
        if let set = toDelete.topIndexSet {
            tableView.deleteRows(at: set.convertToRows(section: sectionNo), with: animationType.getAnimationType(animation: .top))
        }
        if let set = toDelete.rightIndexSet {
            tableView.deleteRows(at: set.convertToRows(section: sectionNo), with: animationType.getAnimationType(animation: .right))
        }
        if let set = toDelete.leftIndexSet {
            tableView.deleteRows(at: set.convertToRows(section: sectionNo), with: animationType.getAnimationType(animation: .left))
        }
        if let set = toDelete.bottomIndexSet {
            tableView.deleteRows(at: set.convertToRows(section: sectionNo), with: animationType.getAnimationType(animation: .bottom))
        }
    }
    
    func createMoveAction(tableView:UITableView, sectionNo:Int) {
        if (toMove.count > 0) {
            for item in toMove {
                tableView.moveRow(at: IndexPath(item: item.0, section: sectionNo), to: IndexPath(item: item.1, section: sectionNo))
            }
        }
    }
    
    func createReloadAction(tableView:UITableView, sectionNo:Int) {
        if let set = toReload.topIndexSet {
            tableView.reloadRows(at: set.convertToRows(section: sectionNo), with: animationType.getAnimationType(animation: .middle))
        }
        if let set = toReload.rightIndexSet {
            tableView.reloadRows(at: set.convertToRows(section: sectionNo), with: animationType.getAnimationType(animation: .middle))
        }
        if let set = toReload.leftIndexSet {
            tableView.reloadRows(at: set.convertToRows(section: sectionNo), with: animationType.getAnimationType(animation: .middle))
        }
        if let set = toReload.bottomIndexSet {
            tableView.reloadRows(at: set.convertToRows(section: sectionNo), with: animationType.getAnimationType(animation: .middle))
        }
    }
}

private class TableViewUpdateWithDirection {
    private var top:[Int] = []
    private var left:[Int] = [] // не используется
    private var right:[Int] = []
    private var bottom:[Int] = []
    
    var hasUpdates:Bool {
        return (top.count > 0 || left.count > 0 || right.count > 0 || bottom.count > 0)
    }
    
    var topIndexSet:IndexSet? {
        return createIndexSet(data: top)
    }
    var leftIndexSet:IndexSet? {
        return createIndexSet(data: left)
    }
    var rightIndexSet:IndexSet? {
        return createIndexSet(data: right)
    }
    var bottomIndexSet:IndexSet? {
        return createIndexSet(data: bottom)
    }
    
    private func createIndexSet(data:[Int]) -> IndexSet? {
        if (data.count == 0) {
            return nil
        }
        var set = IndexSet()
        data.forEach({set.insert($0)})
        return set
    }
    
    init(oldData:[GenericTableDataEquatable], newData:[GenericTableDataEquatable], toUpdateIndexItemArray:[Int]) {
        createUpdates(oldData: oldData, newData: newData, toUpdateIndexItemArray: toUpdateIndexItemArray)
    }
    private func createUpdates(oldData:[GenericTableDataEquatable], newData:[GenericTableDataEquatable], toUpdateIndexItemArray:[Int]) {
        if(oldData.count == 0) {
            top.append(contentsOf: toUpdateIndexItemArray)
            return
        }
        var toUpdate = toUpdateIndexItemArray
        for i in 0..<oldData.count { // top
            if (toUpdate.contains(i)) {
                top.append(i)
                toUpdate.removeAll(where: {$0 == i})
            } else {
                break
            }
        }
        
        for i in (0..<oldData.count).reversed() { // bottom
            if (toUpdate.contains(i)) {
                bottom.append(i)
                toUpdate.removeAll(where: {$0 == i})
            } else {
                break
            }
        }
        if (oldData.count < newData.count) {
            for i in oldData.count..<newData.count { // bottom
                if (toUpdate.contains(i)) {
                    bottom.append(i)
                    toUpdate.removeAll(where: {$0 == i})
                }
            }
        }

        right.append(contentsOf: toUpdate) // остатки справа
        
    }
}

fileprivate extension IndexSet {
    func convertToRows(section:Int) -> [IndexPath] {
        var paths:[IndexPath] = []
        self.forEach({paths.append(.init(row: $0, section: section))})
        return paths
    }
}
