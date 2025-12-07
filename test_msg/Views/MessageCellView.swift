//
//  MessageCellView.swift
//  test_msg
//
//  消息单元格视图 - 支持多种内容类型展示
//

import SwiftUI

struct MessageCellView: View {
    let message: Message
    var searchKeyword: String = ""
    var onButtonTap: ((String) -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 头像
            ZStack(alignment: .topTrailing) {
                avatarView
                
                // 未读角标
                if !message.isRead && message.unreadCount > 0 {
                    unreadBadge
                }
            }
            
            // 消息内容
            VStack(alignment: .leading, spacing: 6) {
                // 第一行：昵称 + 时间
                HStack {
                    HStack(spacing: 4) {
                        // 置顶图标
                        if message.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                        }
                        
                        // 昵称/备注（支持高亮）
                        HighlightedTextView(message.displayName, keyword: searchKeyword)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // 时间
                    Text(message.timeText)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                // 第二行：内容预览
                contentPreview
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(message.isRead ? Color.clear : Color.blue.opacity(0.03))
    }
    
    // MARK: - Content Preview (根据内容类型展示)
    
    @ViewBuilder
    private var contentPreview: some View {
        switch message.content.type {
        case .text:
            textContentView
            
        case .image:
            imageContentView
            
        case .button:
            buttonContentView
        }
    }
    
    /// 纯文本内容
    private var textContentView: some View {
        HStack(spacing: 4) {
            if message.type != .friend {
                messageTypeTag
            }
            
            HighlightedTextView(message.content.text, keyword: searchKeyword)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
    
    /// 图片内容
    private var imageContentView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "photo")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                HighlightedTextView(message.content.text, keyword: searchKeyword)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            // 图片预览
            if let imageURL = message.content.imageURL {
                AsyncImage(url: URL(string: imageURL)) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 120, height: 80)
                            .overlay(ProgressView().scaleEffect(0.6))
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 120, height: 80)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
    }
    
    /// 带按钮的运营内容
    private var buttonContentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HighlightedTextView(message.content.text, keyword: searchKeyword)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            if let buttonText = message.content.buttonText {
                Button {
                    if let action = message.content.buttonAction {
                        onButtonTap?(action)
                    }
                } label: {
                    Text(buttonText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [.pink, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(15)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Subviews
    
    /// 头像视图
    @ViewBuilder
    private var avatarView: some View {
        Group {
            if message.avatar.hasPrefix("http") {
                AsyncImage(url: URL(string: message.avatar)) { phase in
                    switch phase {
                    case .empty:
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(ProgressView().scaleEffect(0.5))
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        systemAvatarView
                    @unknown default:
                        systemAvatarView
                    }
                }
            } else {
                systemAvatarView
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(Circle())
    }
    
    /// 系统图标头像
    private var systemAvatarView: some View {
        Circle()
            .fill(avatarBackgroundColor)
            .overlay(
                Image(systemName: avatarSystemIcon)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
            )
    }
    
    /// 未读角标
    private var unreadBadge: some View {
        Group {
            if message.unreadCount > 99 {
                Text("99+")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .clipShape(Capsule())
            } else {
                Text("\(message.unreadCount)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Color.red)
                    .clipShape(Circle())
            }
        }
        .offset(x: 4, y: -4)
    }
    
    /// 消息类型标签
    private var messageTypeTag: some View {
        Text(messageTypeText)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(messageTypeColor)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(messageTypeColor.opacity(0.1))
            .cornerRadius(3)
    }
    
    // MARK: - Computed Properties
    
    private var avatarBackgroundColor: Color {
        switch message.type {
        case .friend:
            return .blue
        case .system:
            return .orange
        case .live:
            return .pink
        case .comment:
            return .green
        case .promotion:
            return .purple
        }
    }
    
    private var avatarSystemIcon: String {
        switch message.avatar {
        case "system_notification":
            return "bell.fill"
        case "douyin_official":
            return "checkmark.seal.fill"
        case "security_center":
            return "shield.fill"
        case "message_helper":
            return "message.fill"
        case "douyin_helper":
            return "sparkles"
        case "live_reminder":
            return "video.fill"
        case "comment_interaction":
            return "bubble.left.and.bubble.right.fill"
        default:
            return "person.fill"
        }
    }
    
    private var messageTypeText: String {
        switch message.type {
        case .friend:
            return ""
        case .system:
            return "系统"
        case .live:
            return "直播"
        case .comment:
            return "互动"
        case .promotion:
            return "活动"
        }
    }
    
    private var messageTypeColor: Color {
        switch message.type {
        case .friend:
            return .blue
        case .system:
            return .orange
        case .live:
            return .pink
        case .comment:
            return .green
        case .promotion:
            return .purple
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 0) {
            // 纯文本消息
            MessageCellView(message: Message(
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
                content: .text("在吗？有空聊聊")
            ))
            
            Divider()
            
            // 图片消息
            MessageCellView(message: Message(
                id: "2",
                avatar: "https://picsum.photos/id/2/100/100",
                nickname: "李四",
                timestamp: Date().addingTimeInterval(-3600),
                summary: "看看这张照片！",
                type: .friend,
                isRead: false,
                unreadCount: 1,
                remark: nil,
                isPinned: false,
                content: .image(text: "看看这张照片！", imageURL: "https://picsum.photos/400/300")
            ))
            
            Divider()
            
            // 运营按钮消息
            MessageCellView(message: Message(
                id: "3",
                avatar: "douyin_official",
                nickname: "抖音官方",
                timestamp: Date().addingTimeInterval(-7200),
                summary: "恭喜获得新人礼包！",
                type: .promotion,
                isRead: true,
                unreadCount: 0,
                remark: nil,
                isPinned: false,
                content: .button(text: "恭喜获得新人礼包！点击立即领取专属福利", buttonText: "立即领取", action: "claim")
            ))
        }
    }
}
