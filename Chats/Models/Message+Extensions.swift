//
//  Message+Extensions.swift
//  Mantras
//
//  Created by Peter Sugihara on 7/31/23.
//

import CoreData
import Foundation

extension Message {
  static let USER_SPEAKER_ID = "user"

  static func create(
    text: String,
    fromId: String,
    conversation: Conversation,
    inContext ctx: NSManagedObjectContext
  ) throws -> Self {
    let record = self.init(context: ctx)
    record.text = text
    record.conversation = conversation
    record.createdAt = Date()
    record.fromId = fromId

    try ctx.save()

    return record
  }
}
