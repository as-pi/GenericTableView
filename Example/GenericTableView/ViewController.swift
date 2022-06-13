//
//  ViewController.swift
//  GenericTableView
//
//  Created by Aleksey on 13.06.2022.
//

import UIKit
import GenericTableView

class ViewController: UIViewController {
    private lazy var horizontalSection:GenericTableSection<HorizontalSample1.Config> = {
        let onClick:((Int, String) -> Void) = {id, name in
            print("horizontalSection clicked \(id) \(name)")
        }
        var data:[HorizontalSample1.Config] = []
        for i in 0...Int.random(in: 5...10) {
            data.append(.init(id: i, name: "name \(i)", onClick: onClick))
        }
        
        let section:GenericTableSection<HorizontalSample1.Config> = .init(config: .init(headerView: nil, data: data, animationType: .auto, orientation: .horizontal(.init(height: 100)) ))
        
        return section
    }()
    
    
    private lazy var verticalSection:GenericTableSection<VerticalSample1.Config> = {
        
        let section:GenericTableSection<VerticalSample1.Config> = .init(config: .init(headerView: nil, data: generateVerticalData(), animationType: .auto, onShowLastItem: {[weak self] index in
            
            guard let self = self else {return}
            
            self.verticalSection.addData(newData: self.generateVerticalData(fromIndex: self.verticalSection.getItemCount()))
        }))
        
        return section
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        createTableView(parentView: self.view, emptyDataViewType: nil, config: .init(emptyDataViewType: nil, sections: [horizontalSection, verticalSection], insets: .zero), refreshClosure: {[weak self] refreshControl in
            self?.updateTable()
        })
        
    }
    
    private func updateTable() {
        if Bool.random() {
            var data = horizontalSection.getData()
            guard data.count > 0 else {return}
            let randomIndex = Int.random(in: 0..<data.count)
            data[randomIndex] = .init(id: randomIndex, name: "changed index", onClick: {id, name in print("changedClick for \(randomIndex) = \(Int.random(in: 0...50))")})
            
            
            horizontalSection.updateItemsIfNeeded(newData: data)
        } else {
            var data = verticalSection.getData()
            guard data.count > 0 else {return}
            let randomIndex = Int.random(in: 0..<data.count)
            data[randomIndex] = .init(id: randomIndex, name: "changed index", onClick: {id, name in print("changedClick for \(randomIndex) = \(Int.random(in: 0...50))")})
            
            
            verticalSection.updateItemsIfNeeded(newData: data)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {[weak self] in
            self?.refreshControl?.endRefreshing()
        })
        
        
    }
    
    private func generateVerticalData(fromIndex:Int = 0, count:Int = Int.random(in: 5...10)) -> [VerticalSample1.Config] {
        let onClick:((Int, String) -> Void) = {id, name in
            print("verticalSection clicked \(id) \(name)")
        }
        var data:[VerticalSample1.Config] = []
        for i in 0...count {
            data.append(.init(id: fromIndex + i, name: "name \(fromIndex + i)", onClick: onClick))
        }
        return data
    }

}

extension ViewController: BaseVCTableView {}
