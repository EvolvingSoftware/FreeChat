//
//  ConversationDetailView.swift
//  FreeChat
//
//  Created by Sebastian Gray on 7/7/2024.
//

import SwiftUI
import MarkdownUI
import Foundation

struct ConversationDetailView: View {
    let conversation: Conversation
    @EnvironmentObject private var conversationManager: ConversationManager
    @Environment(\.managedObjectContext) private var viewContext

    @AppStorage("selectedModelId") private var selectedModelId: String?
    @AppStorage("systemPrompt") private var systemPrompt: String = DEFAULT_SYSTEM_PROMPT
    @AppStorage("contextLength") private var contextLength: Int = DEFAULT_CONTEXT_LENGTH
    @AppStorage("playSoundEffects") private var playSoundEffects = true
    @AppStorage("temperature") private var temperature: Double?
    @AppStorage("useGPU") private var useGPU: Bool = DEFAULT_USE_GPU
    @AppStorage("serverHost") private var serverHost: String?
    @AppStorage("serverPort") private var serverPort: String?
    @AppStorage("serverTLS") private var serverTLS: Bool?
    @AppStorage("fontSizeOption") private var fontSizeOption: Int = 12

    @State var pendingMessage: Message?
    @State var messages: [Message] = []
    @State var showUserMessage = true
    @State var showResponse = true
    @State var pendingMessageText = ""
    @State var scrollOffset = CGFloat.zero
    @State var scrollHeight = CGFloat.zero
    @State var autoScrollOffset = CGFloat.zero
    @State var autoScrollHeight = CGFloat.zero
    @State var llamaError: LlamaServerError? = nil
    @State var showErrorAlert = false

    private static let SEND = NSDataAsset(name: "ESM_Perfect_App_Button_2_Organic_Simple_Classic_Game_Click")
    private static let PING = NSDataAsset(name: "ESM_POWER_ON_SYNTH")
    let sendSound = NSSound(data: SEND!.data)
    let receiveSound = NSSound(data: PING!.data)

    var agent: Agent {
        conversationManager.agent
    }

    var body: some View {
        ObservableScrollView(scrollOffset: $scrollOffset, scrollHeight: $scrollHeight) { proxy in
            VStack(alignment: .leading) {
                ForEach(messages) { m in
                    if !messages.isEmpty, m == messages.last {
                        if m == pendingMessage {
                            MessageView(pendingMessage!, overrideText: pendingMessageText, agentStatus: agent.status)
                                .onAppear {
                                    scrollToLastIfRecent(proxy)
                                }
                                .opacity(showResponse ? 1 : 0)
                                .animation(.interpolatingSpring(stiffness: 170, damping: 20), value: showResponse)
                                .id("\(m.id)\(m.updatedAt?.description ?? "")")
                        } else {
                            MessageView(m, agentStatus: nil)
                                .id("\(m.id)\(m.updatedAt?.description ?? "")")
                                .opacity(showUserMessage ? 1 : 0)
                                .animation(.interpolatingSpring(stiffness: 170, damping: 20), value: showUserMessage)
                        }
                    } else {
                        MessageView(m, agentStatus: nil)
                            .transition(.identity)
                            .id("\(m.id)\(m.updatedAt?.description ?? "")")
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .textSelection(.enabled)
        .font(.system(size: CGFloat(fontSizeOption)))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MessageTextField { s in
                submit(s)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            showConversation(conversation)
        }
        .onChange(of: selectedModelId) { showConversation(conversation, modelId: $0) }
        .navigationTitle(conversation.titleWithDefault)
        .alert(isPresented: $showErrorAlert, error: llamaError) { _ in
            Button("OK") {
                llamaError = nil
            }
        } message: { error in
            Text(error.recoverySuggestion ?? "")
        }
        .background(Color.textBackground)
    }

    private func playSendSound() {
        guard let sendSound, playSoundEffects else { return }
        sendSound.volume = 0.3
        sendSound.play()
    }

    private func playReceiveSound() {
        guard let receiveSound, playSoundEffects else { return }
        receiveSound.volume = 0.5
        receiveSound.play()
    }

    private func showConversation(_ c: Conversation, modelId: String? = nil) {
        guard
            let selectedModelId = modelId ?? self.selectedModelId,
            !selectedModelId.isEmpty
        else { return }

        messages = c.orderedMessages

        Task {
            if selectedModelId == AISettingsView.remoteModelOption {
                await initializeServerRemote()
            } else {
                await initializeServerLocal(modelId: selectedModelId)
            }
        }
    }

    private func initializeServerLocal(modelId: String) async {
        guard let id = UUID(uuidString: modelId)
        else { return }
        
        let llamaPath = await agent.llama.modelPath
        let req = Model.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let model = try? viewContext.fetch(req).first,
           let modelPath = model.url?.path(percentEncoded: false),
           modelPath != llamaPath {
            await agent.llama.stopServer()
            agent.llama = LlamaServer(modelPath: modelPath, contextLength: contextLength)
        }
    }

    private func initializeServerRemote() async {
        guard let tls = serverTLS,
              let host = serverHost,
              let port = serverPort
        else { return }
        await agent.llama.stopServer()
        agent.llama = LlamaServer(contextLength: contextLength, tls: tls, host: host, port: port)
    }

    private func scrollToLastIfRecent(_ proxy: ScrollViewProxy) {
        let fiveSecondsAgo = Date() - TimeInterval(5)
        let last = messages.last
        if last?.updatedAt != nil, last!.updatedAt! >= fiveSecondsAgo {
            proxy.scrollTo(last!.id, anchor: .bottom)
        }
    }

    private func shouldAutoScroll() -> Bool {
        scrollOffset >= autoScrollOffset - 40 && scrollHeight > autoScrollHeight
    }

    private func engageAutoScroll() {
        autoScrollOffset = scrollOffset
        autoScrollHeight = scrollHeight
    }

    @MainActor
    func handleResponseError(_ e: LlamaServerError) {
        print("handle response error", e.localizedDescription)
        if let m = pendingMessage {
            viewContext.delete(m)
        }
        llamaError = e
        showResponse = false
        showErrorAlert = true
    }

    func submit(_ input: String) {
        if (agent.status == .processing || agent.status == .coldProcessing) {
            Task {
                await agent.interrupt()

                Task.detached(priority: .userInitiated) {
                    try? await Task.sleep(for: .seconds(1))
                    await submit(input)
                }
            }
            return
        }

        playSendSound()

        showUserMessage = false
        engageAutoScroll()

        // Create user's message
        do {
            _ = try Message.create(text: input, fromId: Message.USER_SPEAKER_ID, conversation: conversation, systemPrompt: systemPrompt, inContext: viewContext)
        } catch (let error) {
            print("Error creating message", error.localizedDescription)
        }
        showResponse = false

        messages = conversation.orderedMessages
        withAnimation {
            showUserMessage = true
        }

        // Pending message for bot's reply
        let m = Message(context: viewContext)
        m.fromId = agent.id
        m.createdAt = Date()
        m.updatedAt = m.createdAt
        m.systemPrompt = systemPrompt
        m.text = ""
        pendingMessage = m

        agent.systemPrompt = systemPrompt

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard !m.isDeleted,
                m.managedObjectContext == conversation.managedObjectContext else {
                return
            }

            m.conversation = conversation
            messages = conversation.orderedMessages

            withAnimation {
                showResponse = true
            }
        }

        Task {
            var response: LlamaServer.CompleteResponse
            do {
                response = try await agent.listenThinkRespond(speakerId: Message.USER_SPEAKER_ID, messages: messages, temperature: temperature)
            } catch let error as LlamaServerError {
                handleResponseError(error)
                return
            } catch {
                print("agent listen threw unexpected error", error as Any)
                return
            }

            await MainActor.run {
                m.text = response.text
                m.predictedPerSecond = response.predictedPerSecond ?? -1
                m.responseStartSeconds = response.responseStartSeconds
                m.nPredicted = Int64(response.nPredicted ?? -1)
                m.modelName = response.modelName
                m.updatedAt = Date()

                playReceiveSound()
                do {
                    try viewContext.save()
                } catch {
                    print("error creating message", error.localizedDescription)
                }

                if pendingMessage?.text != nil,
                   !pendingMessage!.text!.isEmpty,
                   response.text.hasPrefix(agent.pendingMessage),
                   m == pendingMessage {
                    pendingMessage = nil
                    agent.pendingMessage = ""
                }

                messages = conversation.orderedMessages
            }
        }
    }
}
