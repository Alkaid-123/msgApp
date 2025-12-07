//
//  RemarkView.swift
//  test_msg
//
//  备注页 - 编辑和保存消息备注
//

import SwiftUI

struct RemarkView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: RemarkViewModel
    
    let message: Message
    let onSave: (String, String) -> Void // (messageId, remark)
    
    init(message: Message, onSave: @escaping (String, String) -> Void) {
        self.message = message
        self.onSave = onSave
        self._viewModel = StateObject(wrappedValue: RemarkViewModel(message: message))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 头像和昵称卡片
                        profileCard
                        
                        // 备注编辑卡片
                        remarkCard
                        
                        // 保存按钮
                        saveButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("设置备注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
            .overlay {
                // 保存成功提示
                if viewModel.showSaveSuccess {
                    VStack {
                        Spacer()
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("保存成功")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        .cornerRadius(25)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        Spacer().frame(height: 100)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.3), value: viewModel.showSaveSuccess)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    /// 头像和昵称卡片
    private var profileCard: some View {
        VStack(spacing: 16) {
            // 头像
            avatarView
                .frame(width: 80, height: 80)
                .clipShape(Circle())
            
            // 原始昵称
            VStack(spacing: 4) {
                Text(viewModel.nickname)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("原始昵称")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    /// 头像视图
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
    
    /// 默认头像
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
    
    /// 系统图标名称
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
    
    /// 备注编辑卡片
    private var remarkCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("备注名")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            TextField("输入备注名", text: $viewModel.remark)
                .font(.system(size: 16))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            
            Text("备注名仅自己可见，方便你辨识对方")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    /// 保存按钮
    private var saveButton: some View {
        Button(action: {
            viewModel.saveRemark()
            onSave(viewModel.getMessageId(), viewModel.remark)
            
            // 延迟关闭页面
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                dismiss()
            }
        }) {
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
        .padding(.top, 10)
    }
}

// MARK: - Preview

#Preview {
    RemarkView(
        message: Message(
            id: "1",
            avatar: "https://picsum.photos/100",
            nickname: "张三",
            timestamp: Date(),
            summary: "在吗？有空聊聊",
            type: .friend,
            isRead: false,
            unreadCount: 3,
            remark: nil
        )
    ) { messageId, remark in
        print("保存备注: \(messageId) - \(remark)")
    }
}



