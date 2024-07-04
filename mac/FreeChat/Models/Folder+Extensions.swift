//
//  Folder+Extensions.swift
//  FreeChat
//
//  Created by Sebastian Gray on 5/7/2024.
//

import Foundation
import CoreData

extension Folder {
    
    static func create(ctx: NSManagedObjectContext, name: String, parent: Folder? = nil) throws -> Self {
        let folder = self.init(context: ctx)
        folder.name = name
        //folder.createdAt = Date()
        //folder.updatedAt = folder.createdAt
      if let parent = parent {
                  folder.addToParent(parent)
              }
        
        try ctx.save()
        return folder
    }
    
    var subfolders: [Folder] {
          let set = child as? Set<Folder> ?? []
          return set.sorted {
              ($0.name ?? "") < ($1.name ?? "")
          }
      }
      
      func addSubfolder(_ subfolder: Folder) {
          addToChild(subfolder)
          subfolder.addToParent(self)
      }
      
      func removeSubfolder(_ subfolder: Folder) {
          removeFromChild(subfolder)
          subfolder.removeFromParent(self)
      }
      
      func moveTo(_ newParent: Folder?) {
          if let currentParents = parent as? Set<Folder> {
              for currentParent in currentParents {
                  removeFromParent(currentParent)
              }
          }
          if let newParent = newParent {
              addToParent(newParent)
          }
      }
      
      var allConversations: [Conversation] {
          let directConversations = conversation as? Set<Conversation> ?? []
          let subfolderConversations = subfolders.flatMap { $0.allConversations }
          return (directConversations + subfolderConversations).sorted {
              ($0.lastMessageAt ?? Date()) > ($1.lastMessageAt ?? Date())
          }
      }
      
      func setSysPrompt(_ prompt: String?) {
          self.sysPrompt = prompt
      }
      
      public override func willSave() {
          super.willSave()
          
          if !isDeleted, changedValues()["updatedAt"] == nil {
              self.setValue(Date(), forKey: "updatedAt")
          }
      }
}



// MARK: - CoreData generated accessors
extension Folder {
    @objc(addChildObject:)
    @NSManaged public func addToChild(_ value: Folder)

    @objc(removeChildObject:)
    @NSManaged public func removeFromChild(_ value: Folder)

    @objc(addChild:)
    @NSManaged public func addToChild(_ values: NSSet)

    @objc(removeChild:)
    @NSManaged public func removeFromChild(_ values: NSSet)
}
