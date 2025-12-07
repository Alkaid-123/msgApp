//
//  MessageWidgetView.swift
//  test_msg
//
//  模拟消息小组件 - 轻量触达展示
//

import SwiftUI

/// Widget 显示模式
enum WidgetDisplayMode {
    case small      // 小尺寸
    case medium     // 中尺寸
    case banner     // 横幅通知
}

struct MessageWidgetView: View {
    let message: Message?
    let unreadCount: Int
    let mode: WidgetDisplayMode
    let onTap: () -> Void
    
    @State private var isPressed = false
    @State private var showPulse = false
    
    var body: some View {
        Group {
            switch mode {
            case .small:
                smallWidget
            case .medium:
                mediumWidget
            case .banner:
                bannerWidget
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onTapGesture {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                onTap()
            }
        }
    }
    
    // MARK: - Small Widget
    
    private var smallWidget: some View {
        VStack(spacing: 8) {
            ZStack {
                // 脉冲动画
                if showPulse && unreadCount > 0 {
                    Circle()
                        .stroke(Color.pink.opacity(0.5), lineWidth: 2)
                        .frame(width: 50, height: 50)
                        .scaleEffect(showPulse ? 1.3 : 1.0)
                        .opacity(showPulse ? 0 : 1)
                }
                
                // 图标
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.pink, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        )
                    
                    // 未读角标
                    if unreadCount > 0 {
                        Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .offset(x: 6, y: -6)
                    }
                }
            }
            
            Text("消息")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
        }
        .frame(width: 80, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .onAppear {
            if unreadCount > 0 {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    showPulse = true
                }
            }
        }
    }
    
    // MARK: - Medium Widget
    
    private var mediumWidget: some View {
        HStack(spacing: 12) {
            // 左侧图标
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.pink, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    )
                
                if unreadCount > 0 {
                    Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .offset(x: 6, y: -6)
                }
            }
            
            // 右侧内容
            VStack(alignment: .leading, spacing: 4) {
                Text(message?.displayName ?? "消息中心")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(message?.summary ?? (unreadCount > 0 ? "您有 \(unreadCount) 条新消息" : "暂无新消息"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // 箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
    }
    
    // MARK: - Banner Widget (通知横幅)
    
    private var bannerWidget: some View {
        HStack(spacing: 12) {
            // 应用图标
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [.pink, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                )
            
            // 内容
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("抖音")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(message?.timeText ?? "刚刚")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Text(message?.displayName ?? "新消息")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(message?.summary ?? "您收到一条新消息")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 5)
        )
    }
}

// MARK: - Widget Container (模拟桌面小组件展示)

struct WidgetShowcaseView: View {
    @ObservedObject private var messageCenter = MessageCenter.shared
    @ObservedObject private var analytics = AnalyticsManager.shared
    @Binding var isPresented: Bool
    let onNavigateToMessages: () -> Void
    
    @State private var showBanner = false
    @State private var latestMessage: Message?
    
    var body: some View {
        ZStack {
            // 模拟桌面背景
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.15, green: 0.15, blue: 0.25)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // 顶部通知横幅
                if showBanner, let message = latestMessage {
                    MessageWidgetView(
                        message: message,
                        unreadCount: analytics.todayStats.unreadCount,
                        mode: .banner
                    ) {
                        navigateToMessages()
                    }
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
                
                // 标题
                VStack(spacing: 8) {
                    Text("Widget 模拟")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("点击小组件进入消息页面")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // 小组件展示区
                HStack(spacing: 20) {
                    // 小尺寸 Widget
                    MessageWidgetView(
                        message: latestMessage,
                        unreadCount: analytics.todayStats.unreadCount,
                        mode: .small
                    ) {
                        navigateToMessages()
                    }
                    
                    // 中尺寸 Widget
                    MessageWidgetView(
                        message: latestMessage,
                        unreadCount: analytics.todayStats.unreadCount,
                        mode: .medium
                    ) {
                        navigateToMessages()
                    }
                    .frame(width: 220)
                }
                
                Spacer()
                
                // 模拟推送按钮
                Button {
                    simulatePush()
                } label: {
                    HStack {
                        Image(systemName: "bell.badge.fill")
                        Text("模拟推送新消息")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.pink, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                }
                
                // 关闭按钮
                Button {
                    isPresented = false
                } label: {
                    Text("关闭")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 30)
            }
            .padding(.top, 60)
        }
        .onReceive(messageCenter.$latestMessage) { message in
            if let message = message {
                latestMessage = message
                showBannerNotification()
            }
        }
    }
    
    private func navigateToMessages() {
        isPresented = false
        onNavigateToMessages()
    }
    
    private func simulatePush() {
        messageCenter.pushNewMessage()
    }
    
    private func showBannerNotification() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showBanner = true
        }
        
        // 5秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showBanner = false
            }
        }
    }
}

// MARK: - Preview

#Preview("Small Widget") {
    MessageWidgetView(
        message: nil,
        unreadCount: 5,
        mode: .small
    ) {}
    .padding()
    .background(Color.gray.opacity(0.2))
}

#Preview("Medium Widget") {
    MessageWidgetView(
        message: Message(
            id: "1",
            avatar: "https://picsum.photos/100",
            nickname: "张三",
            timestamp: Date(),
            summary: "在吗？有空聊聊",
            type: .friend,
            isRead: false,
            unreadCount: 1,
            remark: nil
        ),
        unreadCount: 3,
        mode: .medium
    ) {}
    .padding()
}

#Preview("Banner Widget") {
    MessageWidgetView(
        message: Message(
            id: "1",
            avatar: "https://picsum.photos/100",
            nickname: "张三",
            timestamp: Date(),
            summary: "在吗？有空聊聊",
            type: .friend,
            isRead: false,
            unreadCount: 1,
            remark: nil
        ),
        unreadCount: 1,
        mode: .banner
    ) {}
    .padding()
    .background(Color.black.opacity(0.5))
}

#Preview("Widget Showcase") {
    WidgetShowcaseView(isPresented: .constant(true)) {}
}


