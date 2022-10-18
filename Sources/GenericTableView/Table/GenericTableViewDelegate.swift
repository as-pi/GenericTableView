//
//  File.swift
//  
//
//  Created by Aleksey on 14.10.2022.
//

import Foundation
import UIKit

public protocol GenericTableViewDelegate:AnyObject {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView)
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>)
    func scrollViewDidScroll(_ scrollView: UIScrollView)
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView)
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool)
}

public extension GenericTableViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {}
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {}
    func scrollViewDidScroll(_ scrollView: UIScrollView) {}
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {}
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {}
}

extension GenericTableView {
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.delegate?.scrollViewDidEndDecelerating(scrollView)
    }
    
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        self.delegate?.scrollViewWillEndDragging(scrollView, withVelocity: velocity, targetContentOffset: targetContentOffset)
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.delegate?.scrollViewDidScroll(scrollView)
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.delegate?.scrollViewWillBeginDragging(scrollView)
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        self.delegate?.scrollViewDidEndDragging(scrollView, willDecelerate: decelerate)
    }
}

extension GenericTableView: UITableViewDelegate {
    
    private struct ShowItemData: OnShowItemData {
        let index:Int
        let allCount:Int
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
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        let sectionCount = self.config?.sections.count ?? 0
        return sectionCount
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section < self.config.sections.count {
            
            let section = self.config.sections[section]
            return section.getItemCount()
        }
        return 0
    }
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let hasHeader = (section < self.config.sections.count) ? self.config.sections[section].getHeaderView() != nil : false
        return hasHeader ? UITableView.automaticDimension : 0
    }
    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = (section < self.config.sections.count) ? self.config.sections[section].getHeaderView() : nil
        
        return headerView
        
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let sectionNo:Int = indexPath.section
        if (sectionNo < self.config.sections.count && self.config.sections[sectionNo].isItemHasEmptyView(row: indexPath.row)) {
            return 0
        }
        return UITableView.automaticDimension
    }
    
    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let inUpdate = tableDataInUpdating
        
        if !inUpdate, let loadMoreItemsMethod = loadMoreItemsMethod, (indexPath.section == config.sections.count && indexPath.row == (config.sections[config.sections.count - 1].getItemCount() - 1)) {
            loadMoreItemsMethod(config.sections[config.sections.count - 1].getItemCount())
        }
        
        if !inUpdate, let section = (config.sections.count >= indexPath.section ? config.sections[indexPath.section] : nil) /*, indexPath.row == (section.getItemCount() - 1)*/ {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {[weak section] in
                guard let section = section else {return}
                section.onItemShow(ShowItemData.init(index: indexPath.row, allCount: section.getItemCount()))
            })
        }
        
    }
    
}
