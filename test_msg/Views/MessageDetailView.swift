//
//  MessageDetailView.swift
//  test_msg
//
//  消息详情/备注页 - 支持自定义转场动画
//

import SwiftUI

struct MessageDetailView: View {
    let message: Message
    @Binding var isPresented: Bool
    let onSave: (String, String) -> Void
    
    @StateObject private var viewModel: RemarkViewModel
    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 0.9
    @State private var backgroundOpacity: Double = 0
    @State private var cardOpacity: Double = 0
    @GestureState private var dragOffset: CGSize = .zero
    
    init(message: Message, isPresented: Binding<Bool>, onSave: @escaping (String, String) -> Void) {
        self.message = message
        self._isPresented = isPresented
        self.onSave = onSave
        self._viewModel = StateObject(wrappedValue: RemarkViewModel(message: message))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景遮罩
                Color.black
                    .opacity(backgroundOpacity * (1.0 - abs(currentOffset.height) / 400.0))
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissWithAnimation()
                    }
                
                // 内容卡片
                contentCard(geometry: geometry)
                    .offset(y: currentOffset.height)
                    .scaleEffect(currentScale)
                    .opacity(cardOpacity)
                    .gesture(dismissGesture)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                scale = 1.0
                backgroundOpacity = 0.5
                cardOpacity = 1.0
            }
        }
    }
    
    // MARK: - Content Card
    
    private func contentCard(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // 拖拽指示器
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            ScrollView {
                VStack(spacing: 20) {
                    // 头像和昵称
                    profileSection
                    
                    // 备注编辑
                    remarkSection
                    
                    // 消息详情
                    messageDetailSection
                    
                    // 操作按钮
                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: geometry.size.height * 0.85)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -5)
        .padding(.top, geometry.size.height * 0.15)
    }
    
    // MARK: - Profile Section
    
    private var profileSection: some View {
        VStack(spacing: 16) {
            // 头像
            avatarView
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            
            // 昵称
            VStack(spacing: 4) {
                Text(viewModel.nickname)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("原始昵称")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            // 消息类型标签
            HStack(spacing: 8) {
                messageTypeBadge
                
                if message.isPinned {
                    Label("已置顶", systemImage: "pin.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                }
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Avatar View
    
    @ViewBuilder
    private var avatarView: some View {
        if message.avatar.hasPrefix("http") {
            AsyncImage(url: URL(string: message.avatar)) { phase in
                switch phase {
                case .empty:
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(ProgressView())
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    defaultAvatar
                @unknown default:
                    defaultAvatar
                }
            }
        } else {
            defaultAvatar
        }
    }
    
    private var defaultAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.pink, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: avatarSystemIcon)
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            )
    }
    
    private var avatarSystemIcon: String {
        switch message.avatar {
        case "system_notification": return "bell.fill"
        case "douyin_official": return "checkmark.seal.fill"
        case "security_center": return "shield.fill"
        case "message_helper": return "message.fill"
        case "douyin_helper": return "sparkles"
        case "live_reminder": return "video.fill"
        case "comment_interaction": return "bubble.left.and.bubble.right.fill"
        default: return "person.fill"
        }
    }
    
    // MARK: - Message Type Badge
    
    private var messageTypeBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(messageTypeColor)
                .frame(width: 6, height: 6)
            
            Text(messageTypeText)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(messageTypeColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(messageTypeColor.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var messageTypeText: String {
        switch message.type {
        case .friend: return "好友消息"
        case .system: return "系统消息"
        case .live: return "直播提醒"
        case .comment: return "评论互动"
        case .promotion: return "活动推广"
        }
    }
    
    private var messageTypeColor: Color {
        switch message.type {
        case .friend: return .blue
        case .system: return .orange
        case .live: return .pink
        case .comment: return .green
        case .promotion: return .purple
        }
    }
    
    // MARK: - Remark Section
    
    private var remarkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("备注名")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            TextField("输入备注名", text: $viewModel.remark)
                .font(.system(size: 16))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            
            Text("备注名仅自己可见，方便辨识对方")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Message Detail Section
    
    private var messageDetailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("消息详情")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                // 时间
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text(message.timeText)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .font(.system(size: 13))
                
                Divider()
                
                // 消息内容
                Text(message.content.text)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(nil)
                
                // 图片预览（如果有）
                if message.content.type == .image, let imageURL = message.content.imageURL {
                    AsyncImage(url: URL(string: imageURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .cornerRadius(12)
                        default:
                            EmptyView()
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 保存按钮
            Button {
                saveAndDismiss()
            } label: {
                HStack {
                    if viewModel.isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("保存")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.pink, Color.red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(25)
            }
            .disabled(viewModel.isSaving)
            
            // 取消按钮
            Button {
                dismissWithAnimation()
            } label: {
                Text("取消")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 10)
    }
    
    // MARK: - Gesture & Animation
    
    private var currentOffset: CGSize {
        CGSize(
            width: offset.width + dragOffset.width,
            height: offset.height + dragOffset.height
        )
    }
    
    private var currentScale: CGFloat {
        let dragProgress = abs(dragOffset.height) / 400.0
        return max(0.9, scale - dragProgress * 0.1)
    }
    
    private var dismissGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                // 只允许向下拖拽
                if value.translation.height > 0 {
                    state = value.translation
                }
            }
            .onEnded { value in
                let threshold: CGFloat = 150
                
                if value.translation.height > threshold {
                    dismissWithAnimation()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        offset = .zero
                    }
                }
            }
    }
    
    private func dismissWithAnimation() {
        withAnimation(.easeOut(duration: 0.25)) {
            scale = 0.9
            backgroundOpacity = 0
            cardOpacity = 0
            offset = CGSize(width: 0, height: 200)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isPresented = false
        }
    }
    
    private func saveAndDismiss() {
        viewModel.saveRemark()
        onSave(viewModel.getMessageId(), viewModel.remark)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismissWithAnimation()
        }
    }
}

// MARK: - Preview

#Preview {
    MessageDetailView(
        message: Message(
            id: "1",
            avatar: "https://picsum.photos/100",
            nickname: "张三",
            timestamp: Date(),
            summary: "在吗？有空聊聊",
            type: .friend,
            isRead: false,
            unreadCount: 3,
            remark: nil,
            isPinned: true,
            content: .text("在吗？有空聊聊，我想和你说个事情")
        ),
        isPresented: .constant(true)
    ) { _, _ in }
}

