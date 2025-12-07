//
//  Message.swift
//  test_msg
//
//  消息模型 - 支持多种消息类型和内容体裁
//

import Foundation

/// 消息类型枚举
enum MessageType: String, Codable {
    case friend = "friend"      // 好友消息
    case system = "system"      // 系统消息
    case live = "live"          // 直播提醒
    case comment = "comment"    // 评论互动
    case promotion = "promotion" // 运营推广
}

/// 消息内容体裁
enum MessageContentType: String, Codable {
    case text = "text"          // 纯文本
    case image = "image"        // 携带图片
    case button = "button"      // 携带按钮（运营类消息）
}

/// 消息内容模型
struct MessageContent: Codable {
    let type: MessageContentType
    let text: String
    let imageURL: String?       // 图片URL（type为image时）
    let buttonText: String?     // 按钮文案（type为button时）
    let buttonAction: String?   // 按钮动作标识
    
    init(type: MessageContentType, text: String, imageURL: String? = nil, buttonText: String? = nil, buttonAction: String? = nil) {
        self.type = type
        self.text = text
        self.imageURL = imageURL
        self.buttonText = buttonText
        self.buttonAction = buttonAction
    }
    
    /// 快捷创建纯文本内容
    static func text(_ text: String) -> MessageContent {
        MessageContent(type: .text, text: text)
    }
    
    /// 快捷创建图片内容
    static func image(text: String, imageURL: String) -> MessageContent {
        MessageContent(type: .image, text: text, imageURL: imageURL)
    }
    
    /// 快捷创建按钮内容
    static func button(text: String, buttonText: String, action: String) -> MessageContent {
        MessageContent(type: .button, text: text, buttonText: buttonText, buttonAction: action)
    }
}

/// 消息模型
struct Message: Identifiable, Codable {
    let id: String
    let avatar: String          // 头像URL或系统图标名
    let nickname: String        // 昵称
    let timestamp: Date         // 时间戳
    let summary: String         // 消息摘要
    let type: MessageType       // 消息类型
    var isRead: Bool            // 是否已读
    var unreadCount: Int        // 未读数量
    var remark: String?         // 备注（从SQLite读取）
    var isPinned: Bool          // 是否置顶
    var content: MessageContent // 消息内容体裁
    
    /// 显示名称：优先显示备注，否则显示昵称
    var displayName: String {
        if let remark = remark, !remark.isEmpty {
            return remark
        }
        return nickname
    }
    
    /// 格式化的时间文案（新规则）
    var timeText: String {
        let now = Date()
        let calendar = Calendar.current
        let interval = now.timeIntervalSince(timestamp)
        
        // 1分钟内：刚刚
        if interval < 60 {
            return "刚刚"
        }
        
        // 1小时内：xx分钟前
        if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        }
        
        // 今天：xx:xx
        if calendar.isDateInToday(timestamp) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: timestamp)
        }
        
        // 昨天：昨天 xx:xx
        if calendar.isDateInYesterday(timestamp) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "昨天 " + formatter.string(from: timestamp)
        }
        
        // 7天内：x天前
        let days = calendar.dateComponents([.day], from: timestamp, to: now).day ?? 0
        if days < 7 {
            return "\(days)天前"
        }
        
        // 其他：MM-dd
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: timestamp)
    }
    
    /// 兼容旧版本的初始化（不含content和isPinned）
    init(id: String, avatar: String, nickname: String, timestamp: Date, summary: String, type: MessageType, isRead: Bool, unreadCount: Int, remark: String?) {
        self.id = id
        self.avatar = avatar
        self.nickname = nickname
        self.timestamp = timestamp
        self.summary = summary
        self.type = type
        self.isRead = isRead
        self.unreadCount = unreadCount
        self.remark = remark
        self.isPinned = false
        self.content = .text(summary)
    }
    
    /// 完整初始化
    init(id: String, avatar: String, nickname: String, timestamp: Date, summary: String, type: MessageType, isRead: Bool, unreadCount: Int, remark: String?, isPinned: Bool, content: MessageContent) {
        self.id = id
        self.avatar = avatar
        self.nickname = nickname
        self.timestamp = timestamp
        self.summary = summary
        self.type = type
        self.isRead = isRead
        self.unreadCount = unreadCount
        self.remark = remark
        self.isPinned = isPinned
        self.content = content
    }
}

/// 用于JSON解码的辅助结构（处理时间戳）
struct MessageDTO: Codable {
    let id: String
    let avatar: String
    let nickname: String
    let timestamp: TimeInterval
    let summary: String
    let type: MessageType
    let isRead: Bool
    let unreadCount: Int
    let isPinned: Bool?
    let content: MessageContent?
    
    func toMessage() -> Message {
        Message(
            id: id,
            avatar: avatar,
            nickname: nickname,
            timestamp: Date(timeIntervalSince1970: timestamp),
            summary: summary,
            type: type,
            isRead: isRead,
            unreadCount: unreadCount,
            remark: nil,
            isPinned: isPinned ?? false,
            content: content ?? .text(summary)
        )
    }
}

/// 分页响应结构
struct MessagePageResponse: Codable {
    let messages: [MessageDTO]
    let hasMore: Bool
    let totalCount: Int
}
