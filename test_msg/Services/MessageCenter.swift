//
//  MessageCenter.swift
//  test_msg
//
//  消息分发中心 - 定时推送新消息
//

import Foundation
import Combine

/// 消息分发中心单例
final class MessageCenter: ObservableObject {
    static let shared = MessageCenter()
    
    /// 最新收到的消息
    @Published var latestMessage: Message?
    
    private var timer: Timer?
    private var messageId = 1000
    
    private init() {}
    
    // MARK: - 定时推送
    
    /// 启动定时推送
    /// - Parameter interval: 推送间隔（秒）
    func startPushing(interval: TimeInterval = 5.0) {
        stopPushing()
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.pushNewMessage()
        }
        
        print("📬 Message center started with interval: \(interval)s")
    }
    
    /// 停止定时推送
    func stopPushing() {
        timer?.invalidate()
        timer = nil
        print("📭 Message center stopped")
    }
    
    /// 手动推送新消息
    func pushNewMessage() {
        let message = generateRandomMessage()
        
        DispatchQueue.main.async { [weak self] in
            self?.latestMessage = message
            print("📨 New message pushed: \(message.nickname) - \(message.summary)")
        }
    }
    
    // MARK: - 随机消息生成
    
    private func generateRandomMessage() -> Message {
        messageId += 1
        
        let templates: [(nickname: String, avatar: String, summary: String, type: MessageType, content: MessageContent)] = [
            // 好友文本消息
            ("陌生人", "https://picsum.photos/id/\(Int.random(in: 20...100))/100/100", "你好，可以认识一下吗？", .friend, .text("你好，可以认识一下吗？")),
            ("老朋友", "https://picsum.photos/id/\(Int.random(in: 20...100))/100/100", "好久不见，最近怎么样？", .friend, .text("好久不见，最近怎么样？")),
            ("工作伙伴", "https://picsum.photos/id/\(Int.random(in: 20...100))/100/100", "文档已经发你邮箱了", .friend, .text("文档已经发你邮箱了")),
            
            // 好友图片消息
            ("摄影师小王", "https://picsum.photos/id/\(Int.random(in: 20...100))/100/100", "[图片]", .friend, .image(text: "看看我今天拍的照片！", imageURL: "https://picsum.photos/\(Int.random(in: 400...600))/\(Int.random(in: 300...400))")),
            ("美食博主", "https://picsum.photos/id/\(Int.random(in: 20...100))/100/100", "[图片]", .friend, .image(text: "这家店超好吃，推荐！", imageURL: "https://picsum.photos/\(Int.random(in: 400...600))/\(Int.random(in: 300...400))")),
            
            // 系统消息
            ("系统通知", "system_notification", "您的订单已发货，请注意查收", .system, .text("您的订单已发货，请注意查收")),
            ("安全中心", "security_center", "检测到异常登录，请及时确认", .system, .text("检测到异常登录，请及时确认")),
            
            // 直播提醒
            ("直播提醒", "live_reminder", "您关注的主播开播了", .live, .text("您关注的主播「\(["小美", "阿杰", "音乐达人"].randomElement()!)」正在直播")),
            
            // 评论互动
            ("评论互动", "comment_interaction", "有人评论了你的作品", .comment, .text("「\(["阳光少年", "快乐小鱼", "追风少年"].randomElement()!)」评论了你的视频：太棒了！")),
            
            // 运营消息（带按钮）
            ("抖音官方", "douyin_official", "专属福利等你领取", .promotion, .button(text: "恭喜您获得专属红包！限时24小时，过期作废~", buttonText: "立即领取", action: "redpacket")),
            ("活动中心", "douyin_helper", "参与活动赢好礼", .promotion, .button(text: "春节活动火热进行中，完成任务即可瓜分百万现金！", buttonText: "参与活动", action: "activity")),
        ]
        
        let template = templates.randomElement()!
        
        return Message(
            id: "msg_push_\(messageId)",
            avatar: template.avatar,
            nickname: template.nickname,
            timestamp: Date(),
            summary: template.summary,
            type: template.type,
            isRead: false,
            unreadCount: Int.random(in: 1...5),
            remark: nil,
            isPinned: false,
            content: template.content
        )
    }
}
