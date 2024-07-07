//
//  ConversationManager.swift
//  FreeChat
//
//  Created by Peter Sugihara on 9/11/23.
//

import Foundation
import CoreData
import SwiftUI

@MainActor
class ConversationManager: ObservableObject {
  static let shared = ConversationManager()
  
  var summonRegistered = false
  
  @AppStorage("systemPrompt") private var systemPrompt: String = DEFAULT_SYSTEM_PROMPT
  @AppStorage("contextLength") private var contextLength: Int = DEFAULT_CONTEXT_LENGTH
  
  @Published var agent: Agent = Agent(id: "Llama", systemPrompt: "", modelPath: "", contextLength: DEFAULT_CONTEXT_LENGTH)
  @Published var loadingModelId: String?
  
  @Published var rootFolders: [Folder] = []
  @Published var rootConversations: [Conversation] = []
  
  private static var dummyConversation: Conversation = {
    let tempMoc = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    return Conversation(context: tempMoc)
  }()
  
  // in the foreground
  @Published var currentConversation: Conversation = ConversationManager.dummyConversation
  
  func showConversation() -> Bool {
    return currentConversation != ConversationManager.dummyConversation
  }
  
  func unsetConversation() {
    currentConversation = ConversationManager.dummyConversation
  }
  
  func bringConversationToFront(openWindow: OpenWindowAction) {
    // bring conversation window to front
    if let conversationWindow = NSApp.windows.first(where: { $0.title == currentConversation.titleWithDefault || $0.title == "FreeChat" }) {
      conversationWindow.makeKeyAndOrderFront(self)
    } else {
      // conversation window is not open, so open it
      openWindow(id: "main")
    }
  }
  
  func newConversation(viewContext: NSManagedObjectContext, openWindow: OpenWindowAction) {
    bringConversationToFront(openWindow: openWindow)
    
    do {
      // delete old conversations with no messages
      let fetchRequest = Conversation.fetchRequest()
      let conversations = try viewContext.fetch(fetchRequest)
      for conversation in conversations {
        if conversation.messages?.count == 0 {
          viewContext.delete(conversation)
        }
      }
      
      // make a new convo
      try withAnimation {
        let c = try Conversation.create(ctx: viewContext)
        currentConversation = c
      }
    } catch (let error) {
      print("error creating new conversation", error.localizedDescription)
    }
  }
  
  func newFolder(viewContext: NSManagedObjectContext, openWindow: OpenWindowAction, parent: Folder? = nil) {
    do{
      try _ = withAnimation {
        let folder = try Folder.create(ctx: viewContext, name: "New Folder", parent: parent)
        
        // Save the changes
        try viewContext.save()
        return folder
      }
    }
    catch (let error){
      print("no folder created",error.localizedDescription)
    }
  }
  
  func fetchRootItems(viewContext: NSManagedObjectContext) {
      let folderFetch: NSFetchRequest<Folder> = Folder.fetchRequest()
      folderFetch.predicate = NSPredicate(format: "parent == nil")
      rootFolders = (try? viewContext.fetch(folderFetch)) ?? []
      
      let conversationFetch: NSFetchRequest<Conversation> = Conversation.fetchRequest()
      conversationFetch.predicate = NSPredicate(format: "folder == nil")
      rootConversations = (try? viewContext.fetch(conversationFetch)) ?? []
  }
  
      
  func createFolder(name: String, parent: Folder?, viewContext: NSManagedObjectContext) {
    do {
      let newFolder = try Folder.create(ctx: viewContext, name: name, parent: parent)
      if parent == nil {
          rootFolders.append(newFolder)
      }
    } catch {
      print("Error creating folder:", error)
    }
  }
      
  func moveConversation(_ conversation: Conversation, to folder: Folder?, viewContext: NSManagedObjectContext) {
    conversation.folder = folder
    if folder == nil {
      rootConversations.append(conversation)
    } else {
      rootConversations.removeAll { $0 == conversation }
    }
    try? viewContext.save()
  }
  
  @MainActor
  func rebootAgent(systemPrompt: String? = nil, model: Model, viewContext: NSManagedObjectContext) {
    let systemPrompt = systemPrompt ?? self.systemPrompt
    guard let url = model.url else {
      return
    }
    
    Task {
      await agent.llama.stopServer()
      
      agent = Agent(id: "Llama", systemPrompt: systemPrompt, modelPath: url.path, contextLength: contextLength)
      loadingModelId = model.id?.uuidString
      
      model.error = nil
      
      loadingModelId = nil
      try? viewContext.save()
    }
  }
}

