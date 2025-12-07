//
//  MessageListView.swift
//  test_msg
//
//  消息列表主页面 - 支持搜索、下拉刷新、上滑加载更多
//

import SwiftUI

struct MessageListView: View {
    @StateObject private var viewModel = MessageListViewModel()
    @ObservedObject private var analytics = AnalyticsManager.shared
    @State private var selectedMessage: Message?
    @State private var showDetailSheet = false
    @State private var showStatsSheet = false
    @State private var showWidgetSheet = false
    @State private var scrollProxy: ScrollViewProxy?
    
    var body: some View {
        ZStack {
            NavigationStack {
                ZStack {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                    
                    contentView
                }
                .toolbar {
                    toolbarContent
                }
                .onAppear {
                    viewModel.loadInitialData()
                    viewModel.startMessagePushing()
                }
                .onDisappear {
                    viewModel.stopMessagePushing()
                }
                .onChange(of: viewModel.scrollToTop) { _, newValue in
                    if newValue {
                        withAnimation(.spring(response: 0.3)) {
                            scrollProxy?.scrollTo("top", anchor: .top)
                        }
                    }
                }
                .sheet(isPresented: $showStatsSheet) {
                    StatsDashboardView()
                }
                .fullScreenCover(isPresented: $showWidgetSheet) {
                    WidgetShowcaseView(isPresented: $showWidgetSheet) {
                        // Widget 点击后的回调（已经在消息页，无需操作）
                    }
                }
            }
            
            // 详情页覆盖层（不使用fullScreenCover，避免双重动画）
            if showDetailSheet, let message = selectedMessage {
                MessageDetailView(
                    message: message,
                    isPresented: $showDetailSheet
                ) { messageId, remark in
                    viewModel.updateRemark(for: messageId, remark: remark)
                }
                .transition(.identity)
                .zIndex(1)
            }
        }
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.loadingState {
        case .loading:
            VStack(spacing: 0) {
                SearchBarView(text: $viewModel.searchText)
                SkeletonListView()
            }
            
        case .empty:
            VStack(spacing: 0) {
                SearchBarView(text: $viewModel.searchText)
                EmptyStateView(type: .noData) {
                    Task {
                        viewModel.resetFirstLoad()
                        viewModel.loadInitialData()
                    }
                }
            }
            
        case .error(let message):
            VStack(spacing: 0) {
                SearchBarView(text: $viewModel.searchText)
                EmptyStateView(type: .error(message)) {
                    Task {
                        viewModel.resetFirstLoad()
                        viewModel.loadInitialData()
                    }
                }
            }
            
        default:
            messageListView
        }
    }
    
    /// 消息列表视图
    private var messageListView: some View {
        VStack(spacing: 0) {
            // 搜索框
            SearchBarView(text: $viewModel.searchText)
            
            // 未读数量提示
            if viewModel.totalUnreadCount > 0 && viewModel.searchText.isEmpty {
                unreadBanner
            }
            
            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // 顶部锚点
                        Color.clear
                            .frame(height: 1)
                            .id("top")
                        
                        // 搜索结果为空提示
                        if !viewModel.searchText.isEmpty && viewModel.filteredMessages.isEmpty {
                            searchEmptyView
                        } else {
                            ForEach(viewModel.filteredMessages) { message in
                                VStack(spacing: 0) {
                                    MessageCellView(
                                        message: message,
                                        searchKeyword: viewModel.searchText
                                    ) { action in
                                        handleButtonAction(action, message: message)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        handleMessageTap(message)
                                    }
                                    .contextMenu {
                                        contextMenuItems(for: message)
                                    }
                                    
                                    Divider()
                                        .padding(.leading, 78)
                                }
                            }
                            
                            // 加载更多
                            if viewModel.searchText.isEmpty {
                                if viewModel.hasMore {
                                    loadMoreView
                                        .onAppear {
                                            Task {
                                                await viewModel.loadMore()
                                            }
                                        }
                                } else if !viewModel.messages.isEmpty {
                                    noMoreDataView
                                }
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .refreshable {
                    await viewModel.refresh()
                }
                .onAppear {
                    scrollProxy = proxy
                }
            }
        }
    }
    
    /// 未读消息横幅
    private var unreadBanner: some View {
        HStack {
            Image(systemName: "envelope.badge.fill")
                .foregroundColor(.pink)
            
            Text("您有 \(viewModel.totalUnreadCount) 条未读消息")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.pink.opacity(0.1))
    }
    
    /// 搜索结果为空
    private var searchEmptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("未找到相关消息")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            
            Text("换个关键词试试")
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    /// 加载更多视图
    private var loadMoreView: some View {
        HStack(spacing: 8) {
            if case .loadingMore = viewModel.loadingState {
                ProgressView()
                    .scaleEffect(0.8)
                Text("加载中...")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            } else {
                Text("上滑加载更多")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
    
    /// 没有更多数据视图
    private var noMoreDataView: some View {
        HStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
            
            Text("没有更多消息了")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
            
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                showStatsSheet = true
            } label: {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.pink)
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 16) {
                Button {
                    showWidgetSheet = true
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 16))
                }
                
                Menu {
                    Section("测试功能") {
                        Button {
                            viewModel.resetToEmpty()
                        } label: {
                            Label("模拟空态", systemImage: "tray")
                        }
                        
                        Button {
                            viewModel.triggerError()
                        } label: {
                            Label("模拟错误", systemImage: "exclamationmark.triangle")
                        }
                    }
                    
                    Section("消息推送") {
                        Button {
                            MessageCenter.shared.pushNewMessage()
                        } label: {
                            Label("推送新消息", systemImage: "bell.badge")
                        }
                    }
                    
                    Section("数据统计") {
                        Button {
                            showStatsSheet = true
                        } label: {
                            Label("数据看板", systemImage: "chart.bar.fill")
                        }
                        
                        Button {
                            showWidgetSheet = true
                        } label: {
                            Label("Widget 模拟", systemImage: "square.grid.2x2")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                }
            }
        }
    }
    
    /// 长按菜单
    @ViewBuilder
    private func contextMenuItems(for message: Message) -> some View {
        Button {
            selectedMessage = message
            showDetailSheet = true
        } label: {
            Label("设置备注", systemImage: "pencil")
        }
        
        Button {
            viewModel.togglePinned(message)
        } label: {
            Label(message.isPinned ? "取消置顶" : "置顶", systemImage: message.isPinned ? "pin.slash" : "pin")
        }
        
        if !message.isRead {
            Button {
                viewModel.markAsRead(message)
            } label: {
                Label("标记已读", systemImage: "envelope.open")
            }
        }
        
        Button(role: .destructive) {
            // 删除操作
        } label: {
            Label("删除", systemImage: "trash")
        }
    }
    
    // MARK: - Actions
    
    private func handleMessageTap(_ message: Message) {
        // 记录点击事件
        analytics.trackMessageClicked(message)
        
        viewModel.markAsRead(message)
        
        // 记录已读事件
        analytics.trackMessageRead(message)
        
        selectedMessage = message
        showDetailSheet = true
    }
    
    private func handleButtonAction(_ action: String, message: Message) {
        // 记录按钮点击
        analytics.trackButtonClicked(message, action: action)
        print("Button action: \(action) for message: \(message.id)")
    }
}

// MARK: - Preview

#Preview {
    MessageListView()
}
