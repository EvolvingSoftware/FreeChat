//
//  ConversationView.swift
//  Mantras
//
//  Created by Peter Sugihara on 7/31/23.
//

import SwiftUI
import MarkdownUI
import Foundation

struct SidebarView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Folder.name, ascending: true)],
        predicate: NSPredicate(format: "parent == nil"),
        animation: .default)
    private var rootFolders: FetchedResults<Folder>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Conversation.lastMessageAt, ascending: false)],
        predicate: NSPredicate(format: "folder == nil"),
        animation: .default)
    private var rootConversations: FetchedResults<Conversation>

    @Binding var selectedConversation: Conversation?

    var body: some View {
        List {
            ForEach(rootFolders) { folder in
                FolderView(folder: folder, selectedConversation: $selectedConversation)
            }
            ForEach(rootConversations) { conversation in
                Button(action: {
                    selectedConversation = conversation
                }) {
                    Text(conversation.titleWithDefault)
                }
            }
        }
    }
}

struct FolderView: View {
    let folder: Folder
    @State private var isExpanded = false
    @Binding var selectedConversation: Conversation?

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(folder.child?.allObjects as? [Folder] ?? [], id: \.self) { subfolder in
                FolderView(folder: subfolder, selectedConversation: $selectedConversation)
            }
            if let conversations = folder.conversation?.allObjects as? [Conversation] {
                ForEach(conversations, id: \.self) { conversation in
                    Button(action: {
                        selectedConversation = conversation
                    }) {
                        Text(conversation.titleWithDefault)
                    }
                }
            }
        } label: {
            Label(folder.name ?? "Untitled Folder", systemImage: "folder")
        }
    }
}


struct ConversationLink: View {
    let conversation: Conversation
    @EnvironmentObject private var conversationManager: ConversationManager

    var body: some View {
        Button(action: {
            conversationManager.currentConversation = conversation
        }) {
            Text(conversation.titleWithDefault)
                .foregroundColor(conversation == conversationManager.currentConversation ? .accentColor : .primary)
        }
    }
}
struct ConversationView: View {
    @EnvironmentObject private var conversationManager: ConversationManager
    @State private var selectedConversation: Conversation?

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedConversation: $selectedConversation)
        } detail: {
            if let conversation = selectedConversation {
                ConversationDetailView(conversation: conversation)
            } else {
                Text("Select a conversation")
            }
        }
        .onChange(of: selectedConversation) { newConversation in
            if let newConversation = newConversation {
                conversationManager.currentConversation = newConversation
            }
        }
    }
}

#Preview {
  let ctx = PersistenceController.preview.container.viewContext
  let c = try! Conversation.create(ctx: ctx)
  let cm = ConversationManager()
  cm.currentConversation = c
  cm.agent = Agent(id: "llama", systemPrompt: "", modelPath: "", contextLength: DEFAULT_CONTEXT_LENGTH)

  let question = Message(context: ctx)
  question.conversation = c
  question.text = "how can i check file size in swift?"

  let response = Message(context: ctx)
  response.conversation = c
  response.fromId = "llama"
  response.text = """
      Hi! You can use `FileManager` to get information about files, including their sizes. Here's an example of getting the size of a text file:
      ```swift
      let path = "path/to/file"
      do {
          let attributes = try FileManager.default.attributesOfItem(atPath: path)
          if let fileSize = attributes[FileAttributeKey.size] as? UInt64 {
              print("The file is \\(ByteCountFormatter().string(fromByteCount: Int64(fileSize)))")
          }
      } catch {
          // Handle any errors
      }
      ```
      """


  return ConversationView()
    .environment(\.managedObjectContext, ctx)
    .environmentObject(cm)
}


#Preview("null state") {
  let ctx = PersistenceController.preview.container.viewContext
  let c = try! Conversation.create(ctx: ctx)
  let cm = ConversationManager()
  cm.currentConversation = c
  cm.agent = Agent(id: "llama", systemPrompt: "", modelPath: "", contextLength: DEFAULT_CONTEXT_LENGTH)

  return ConversationView()
    .environment(\.managedObjectContext, ctx)
    .environmentObject(cm)
}
/*
 #Preview {
 let previewContext = PersistenceController.preview.container.viewContext
 let mockConversation = Conversation(context: previewContext)
 mockConversation.title = "Mock Conversation"
 
 let mockMessage = Message(context: previewContext)
 mockMessage.text = "Hello, this is a mock message"
 mockMessage.fromId = Message.USER_SPEAKER_ID
 mockMessage.conversation = mockConversation
 
 let mockConversationManager = ConversationManager()
 mockConversationManager.currentConversation = mockConversation
 
 return ConversationView()
 .environment(\.managedObjectContext, previewContext)
 .environmentObject(mockConversationManager)
 }
 */
