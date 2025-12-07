//
//  MessageListViewModel.swift
//  test_msg
//
//  消息列表ViewModel - 管理消息列表数据和状态
//

import Foundation
import Combine
import SwiftUI

/// 列表加载状态
enum LoadingState: Equatable {
    case idle
    case loading
    case refreshing
    case loadingMore
    case error(String)
    case empty
}

/// 消息列表ViewModel
@MainActor
final class MessageListViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var messages: [Message] = []
    @Published var loadingState: LoadingState = .idle
    @Published var hasMore: Bool = true
    @Published var searchText: String = ""
    @Published var scrollToTop: Bool = false
    @Published var totalUnreadCount: Int = 0
    
    /// 过滤后的消息列表（搜索结果）
    var filteredMessages: [Message] {
        if searchText.isEmpty {
            return sortedMessages
        }
        let keyword = searchText.lowercased()
        return sortedMessages.filter { message in
            message.displayName.lowercased().contains(keyword) ||
            message.summary.lowercased().contains(keyword) ||
            message.content.text.lowercased().contains(keyword)
        }
    }
    
    /// 排序后的消息（置顶优先）
    private var sortedMessages: [Message] {
        messages.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            return lhs.timestamp > rhs.timestamp
        }
    }
    
    // MARK: - Private Properties
    
    private let dataService = MockDataService.shared
    private let databaseManager = DatabaseManager.shared
    private let messageCenter = MessageCenter.shared
    private let networkManager = NetworkManager.shared
    private let analytics = AnalyticsManager.shared
    
    private var currentPage = 0
    private var isFirstLoad = true
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupMessageCenterSubscription()
    }
    
    // MARK: - Message Center Integration
    
    private func setupMessageCenterSubscription() {
        messageCenter.$latestMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newMessage in
                self?.handleNewMessage(newMessage)
            }
            .store(in: &cancellables)
    }
    
    private func handleNewMessage(_ message: Message) {
        // 插入新消息到列表顶部
        var newMessage = message
        
        // 应用持久化数据到单个消息
        var tempMessages = [newMessage]
        databaseManager.applyPersistedData(to: &tempMessages)
        if let updatedMessage = tempMessages.first {
            newMessage = updatedMessage
        }
        
        // 记录消息收到事件
        analytics.trackMessageReceived(newMessage)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            messages.insert(newMessage, at: 0)
            updateUnreadCount()
            scrollToTop = true
        }
        
        // 记录消息展示事件
        analytics.trackMessageDisplayed(newMessage)
        
        // 重置滚动标志
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.scrollToTop = false
        }
    }
    
    /// 启动消息推送
    func startMessagePushing() {
        messageCenter.startPushing(interval: 5.0)
    }
    
    /// 停止消息推送
    func stopMessagePushing() {
        messageCenter.stopPushing()
    }
    
    // MARK: - Data Loading
    
    /// 首次加载数据
    func loadInitialData() {
        guard isFirstLoad else { return }
        isFirstLoad = false
        
        loadingState = .loading
        currentPage = 0
        
        Task {
            do {
                let (loadedMessages, hasMore) = try await networkManager.simulateRequest(
                    timeout: 5.0,
                    simulateDelay: 1.0,
                    failureRate: 0.0
                ) {
                    var result: ([Message], Bool) = ([], false)
                    let semaphore = DispatchSemaphore(value: 0)
                    
                    self.dataService.fetchMessages(page: 0) { messages, more in
                        result = (messages, more)
                        semaphore.signal()
                    }
                    semaphore.wait()
                    return result
                }
                
                if loadedMessages.isEmpty {
                    self.loadingState = .empty
                } else {
                    var finalMessages = loadedMessages
                    self.databaseManager.applyPersistedData(to: &finalMessages)
                    self.messages = finalMessages
                    self.hasMore = hasMore
                    self.loadingState = .idle
                    self.updateUnreadCount()
                    
                    // 记录消息展示事件
                    for msg in finalMessages {
                        self.analytics.trackMessageDisplayed(msg)
                    }
                }
            } catch {
                self.loadingState = .error(error.localizedDescription)
            }
        }
    }
    
    /// 下拉刷新
    func refresh() async {
        loadingState = .refreshing
        currentPage = 0
        
        do {
            let (loadedMessages, hasMore) = try await networkManager.simulateRequest(
                timeout: 5.0,
                simulateDelay: 0.8,
                failureRate: 0.1
            ) {
                var result: ([Message], Bool) = ([], false)
                let semaphore = DispatchSemaphore(value: 0)
                
                self.dataService.refreshMessages { messages, more in
                    result = (messages, more)
                    semaphore.signal()
                }
                semaphore.wait()
                return result
            }
            
            if loadedMessages.isEmpty {
                self.loadingState = .empty
            } else {
                var finalMessages = loadedMessages
                self.databaseManager.applyPersistedData(to: &finalMessages)
                self.messages = finalMessages
                self.hasMore = hasMore
                self.loadingState = .idle
                self.updateUnreadCount()
            }
        } catch {
            // 刷新失败时保持现有数据
            if messages.isEmpty {
                loadingState = .error(error.localizedDescription)
            } else {
                loadingState = .idle
            }
        }
    }
    
    /// 加载更多
    func loadMore() async {
        guard hasMore, loadingState != .loadingMore else { return }
        
        loadingState = .loadingMore
        let nextPage = currentPage + 1
        
        await withCheckedContinuation { continuation in
            dataService.fetchMessages(page: nextPage) { [weak self] messages, hasMore in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                if !messages.isEmpty {
                    var loadedMessages = messages
                    self.databaseManager.applyPersistedData(to: &loadedMessages)
                    self.messages.append(contentsOf: loadedMessages)
                    self.currentPage = nextPage
                    self.updateUnreadCount()
                }
                self.hasMore = hasMore
                self.loadingState = .idle
                continuation.resume()
            }
        }
    }
    
    // MARK: - Message Operations
    
    /// 标记消息为已读
    func markAsRead(_ message: Message) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        
        messages[index].isRead = true
        messages[index].unreadCount = 0
        
        databaseManager.saveMessageReadState(
            messageId: message.id,
            isRead: true,
            unreadCount: 0
        )
        
        updateUnreadCount()
    }
    
    /// 切换置顶状态
    func togglePinned(_ message: Message) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        
        messages[index].isPinned.toggle()
        
        databaseManager.updatePinnedState(
            messageId: message.id,
            isPinned: messages[index].isPinned
        )
    }
    
    /// 更新消息备注
    func updateRemark(for messageId: String, remark: String) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        messages[index].remark = remark
    }
    
    /// 获取指定消息
    func getMessage(by id: String) -> Message? {
        messages.first { $0.id == id }
    }
    
    /// 更新未读总数
    private func updateUnreadCount() {
        totalUnreadCount = messages.filter { !$0.isRead }.reduce(0) { $0 + $1.unreadCount }
    }
    
    // MARK: - Search
    
    /// 高亮搜索关键词
    func highlightedText(_ text: String, keyword: String) -> [(text: String, isHighlighted: Bool)] {
        guard !keyword.isEmpty else {
            return [(text, false)]
        }
        
        var result: [(String, Bool)] = []
        var currentIndex = text.startIndex
        let lowercasedText = text.lowercased()
        let lowercasedKeyword = keyword.lowercased()
        
        while let range = lowercasedText[currentIndex...].range(of: lowercasedKeyword) {
            // 添加关键词前的文本
            if currentIndex < range.lowerBound {
                let prefix = String(text[currentIndex..<range.lowerBound])
                result.append((prefix, false))
            }
            
            // 添加高亮的关键词
            let highlightedText = String(text[range])
            result.append((highlightedText, true))
            
            currentIndex = range.upperBound
        }
        
        // 添加剩余文本
        if currentIndex < text.endIndex {
            let suffix = String(text[currentIndex...])
            result.append((suffix, false))
        }
        
        return result.isEmpty ? [(text, false)] : result
    }
    
    // MARK: - Test Methods
    
    /// 重置为初始状态（用于测试空态）
    func resetToEmpty() {
        messages = []
        loadingState = .empty
    }
    
    /// 触发错误状态（用于测试）
    func triggerError() {
        loadingState = .error("网络连接失败，请检查网络后重试")
    }
    
    /// 重置首次加载标志（用于测试）
    func resetFirstLoad() {
        isFirstLoad = true
        messages = []
        loadingState = .idle
    }
}
