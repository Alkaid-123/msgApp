//
//  EmptyStateView.swift
//  test_msg
//
//  空态页面 - 无数据和请求失败状态
//

import SwiftUI

/// 空态类型
enum EmptyStateType {
    case noData       // 无数据
    case error(String) // 请求失败
}

struct EmptyStateView: View {
    let type: EmptyStateType
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // 图标
            Image(systemName: iconName)
                .font(.system(size: 60))
                .foregroundColor(iconColor)
            
            // 标题
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primary)
            
            // 描述
            Text(description)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // 重试按钮
            Button(action: onRetry) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text(buttonText)
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.pink, Color.red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(25)
            }
            .padding(.top, 10)
            
            Spacer()
        }
    }
    
    // MARK: - Computed Properties
    
    private var iconName: String {
        switch type {
        case .noData:
            return "tray"
        case .error:
            return "wifi.exclamationmark"
        }
    }
    
    private var iconColor: Color {
        switch type {
        case .noData:
            return .gray
        case .error:
            return .red.opacity(0.7)
        }
    }
    
    private var title: String {
        switch type {
        case .noData:
            return "暂无消息"
        case .error:
            return "加载失败"
        }
    }
    
    private var description: String {
        switch type {
        case .noData:
            return "还没有收到任何消息\n快去关注感兴趣的人吧"
        case .error(let message):
            return message
        }
    }
    
    private var buttonText: String {
        switch type {
        case .noData:
            return "刷新试试"
        case .error:
            return "重新加载"
        }
    }
}

// MARK: - Preview

#Preview("无数据") {
    EmptyStateView(type: .noData) {
        print("重试")
    }
}

#Preview("请求失败") {
    EmptyStateView(type: .error("网络连接失败，请检查网络设置后重试")) {
        print("重试")
    }
}



