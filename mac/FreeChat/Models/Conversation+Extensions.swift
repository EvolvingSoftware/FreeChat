//
//  Conversation+Extensions.swift
//  Mantras
//
//  Created by Peter Sugihara on 7/31/23.
//

import Foundation
import CoreData


extension Conversation {
  static func create(ctx: NSManagedObjectContext, folder: Folder? = nil) throws -> Self {
      let record = self.init(context: ctx)
      record.createdAt = Date()
      record.lastMessageAt = record.createdAt
      record.folder = folder

      try ctx.save()
      return record
  }

  var orderedMessages: [Message] {
    let set = messages as? Set<Message> ?? []
    return set.sorted {
      ($0.createdAt ?? Date()) < ($1.createdAt ?? Date())
    }
  }

  var titleWithDefault: String {
    if title != nil {
      return title!
    } else if messages?.count ?? 0 > 0 {
      let firstMessage = orderedMessages.first!
      let prefix = firstMessage.text?.prefix(200)
      if let firstLine = prefix?.split(separator: "\n").first {
        return String(firstLine)
      } else {
        return dateTitle
      }
    } else {
      return dateTitle
    }
  }

  var dateTitle: String {
    (createdAt ?? Date())!.formatted(Conversation.titleFormat)
  }

  static let titleFormat = Date.FormatStyle()
    .year()
    .day()
    .month()
    .hour()
    .minute()
    .locale(Locale(identifier: "en_US"))

  public override func willSave() {
    super.willSave()

    if !isDeleted, changedValues()["updatedAt"] == nil {
      self.setValue(Date(), forKey: "updatedAt")
    }
  }
  func setFolder(_ folder: Folder?) {
      self.folder = folder
      self.updatedAt = Date()
  }
}
