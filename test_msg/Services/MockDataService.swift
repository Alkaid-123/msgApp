//
//  MockDataService.swift
//  test_msg
//
//  模拟数据服务 - 从JSON加载消息数据，支持分页
//

import Foundation

/// 模拟数据服务
final class MockDataService {
    static let shared = MockDataService()
    
    private var allMessages: [Message] = []
    private let pageSize = 10
    
    private init() {
        loadMessagesFromJSON()
    }
    
    // MARK: - 数据加载
    
    private func loadMessagesFromJSON() {
        guard let url = Bundle.main.url(forResource: "messages", withExtension: "json") else {
            print("❌ messages.json not found, using generated data")
            allMessages = generateMockMessages()
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode([MessageDTO].self, from: data)
            allMessages = response.map { $0.toMessage() }
            print("✅ Loaded \(allMessages.count) messages from JSON")
        } catch {
            print("❌ Failed to load JSON: \(error), using generated data")
            allMessages = generateMockMessages()
        }
    }
    
    /// 生成模拟消息数据（支持多种内容类型）
    private func generateMockMessages() -> [Message] {
        var messages: [Message] = []
        let now = Date()
        var id = 1
        
        // 好友文本消息模板
        let friendTextMessages: [(name: String, avatar: String, text: String)] = [
            ("张三", "https://picsum.photos/id/1/100/100", "在吗？有空聊聊"),
            ("李四", "https://picsum.photos/id/2/100/100", "刚看到你的视频，太有趣了！"),
            ("王五", "https://picsum.photos/id/3/100/100", "周末一起出去玩吧"),
            ("小红", "https://picsum.photos/id/4/100/100", "你发的那个教程太有用了，谢谢分享！"),
            ("小明", "https://picsum.photos/id/5/100/100", "收到你的礼物了，非常感谢！"),
            ("老王", "https://picsum.photos/id/6/100/100", "项目的事情聊一下"),
        ]
        
        // 好友图片消息模板
        let friendImageMessages: [(name: String, avatar: String, text: String, imageURL: String)] = [
            ("美食达人", "https://picsum.photos/id/7/100/100", "这家餐厅真的很好吃！", "https://picsum.photos/400/300?food"),
            ("旅行博主", "https://picsum.photos/id/8/100/100", "今天拍的日落超美", "https://picsum.photos/400/300?sunset"),
            ("摄影师小李", "https://picsum.photos/id/10/100/100", "照片修好了，发给你", "https://picsum.photos/400/300?portrait"),
            ("宠物博主", "https://picsum.photos/id/17/100/100", "我家猫咪太可爱了", "https://picsum.photos/400/300?cat"),
        ]
        
        // 系统文本消息模板
        let systemMessages: [(name: String, avatar: String, text: String)] = [
            ("系统通知", "system_notification", "您的账号已完成安全认证，请妥善保管账号信息"),
            ("安全中心", "security_center", "检测到您的账号在新设备登录，如非本人操作请及时修改密码"),
            ("消息助手", "message_helper", "您有3条新的评论待查看"),
        ]
        
        // 运营按钮消息模板
        let promotionMessages: [(name: String, avatar: String, text: String, buttonText: String, action: String)] = [
            ("抖音官方", "douyin_official", "恭喜获得新人专属礼包！限时24小时，过期作废~", "立即领取", "claim_gift"),
            ("活动中心", "douyin_helper", "春节红包活动火热进行中，完成任务瓜分百万现金！", "参与活动", "activity"),
            ("会员中心", "douyin_official", "您的会员即将到期，续费享8折优惠", "立即续费", "renew"),
        ]
        
        // 直播提醒模板
        let liveMessages: [(name: String, avatar: String, text: String)] = [
            ("直播提醒", "live_reminder", "您关注的主播「音乐达人」正在直播"),
            ("直播提醒", "live_reminder", "您关注的主播「美食探店」开播了"),
            ("直播提醒", "live_reminder", "您关注的主播「游戏高手」正在直播王者荣耀"),
        ]
        
        // 评论互动模板
        let commentMessages: [(name: String, avatar: String, text: String)] = [
            ("评论互动", "comment_interaction", "用户「阳光少年」评论了你的视频：太棒了！"),
            ("评论互动", "comment_interaction", "用户「快乐小鱼」回复了你的评论"),
            ("评论互动", "comment_interaction", "你的视频收到了100+个新评论"),
        ]
        
        // 生成30条消息
        for i in 0..<30 {
            let hoursAgo = Double(i * 2 + Int.random(in: 0...3))
            let timestamp = now.addingTimeInterval(-hoursAgo * 3600)
            let isRead = i > 5 ? Bool.random() : false
            let unreadCount = isRead ? 0 : Int.random(in: 1...10)
            let isPinned = i < 2 // 前2条置顶
            
            let message: Message
            let messageTypeIndex = i % 12 // 12种情况循环
            
            switch messageTypeIndex {
            case 0...2:
                // 好友文本消息
                let template = friendTextMessages[i % friendTextMessages.count]
                message = Message(
                    id: "msg_\(id)",
                    avatar: template.avatar,
                    nickname: template.name,
                    timestamp: timestamp,
                    summary: template.text,
                    type: .friend,
                    isRead: isRead,
                    unreadCount: unreadCount,
                    remark: nil,
                    isPinned: isPinned,
                    content: .text(template.text)
                )
                
            case 3, 4:
                // 好友图片消息
                let template = friendImageMessages[i % friendImageMessages.count]
                message = Message(
                    id: "msg_\(id)",
                    avatar: template.avatar,
                    nickname: template.name,
                    timestamp: timestamp,
                    summary: "[图片] \(template.text)",
                    type: .friend,
                    isRead: isRead,
                    unreadCount: unreadCount,
                    remark: nil,
                    isPinned: isPinned,
                    content: .image(text: template.text, imageURL: template.imageURL)
                )
                
            case 5, 6:
                // 系统消息
                let template = systemMessages[i % systemMessages.count]
                message = Message(
                    id: "msg_\(id)",
                    avatar: template.avatar,
                    nickname: template.name,
                    timestamp: timestamp,
                    summary: template.text,
                    type: .system,
                    isRead: isRead,
                    unreadCount: unreadCount,
                    remark: nil,
                    isPinned: false,
                    content: .text(template.text)
                )
                
            case 7, 8:
                // 运营按钮消息
                let template = promotionMessages[i % promotionMessages.count]
                message = Message(
                    id: "msg_\(id)",
                    avatar: template.avatar,
                    nickname: template.name,
                    timestamp: timestamp,
                    summary: template.text,
                    type: .promotion,
                    isRead: isRead,
                    unreadCount: unreadCount,
                    remark: nil,
                    isPinned: false,
                    content: .button(text: template.text, buttonText: template.buttonText, action: template.action)
                )
                
            case 9:
                // 直播提醒
                let template = liveMessages[i % liveMessages.count]
                message = Message(
                    id: "msg_\(id)",
                    avatar: template.avatar,
                    nickname: template.name,
                    timestamp: timestamp,
                    summary: template.text,
                    type: .live,
                    isRead: isRead,
                    unreadCount: unreadCount,
                    remark: nil,
                    isPinned: false,
                    content: .text(template.text)
                )
                
            default:
                // 评论互动
                let template = commentMessages[i % commentMessages.count]
                message = Message(
                    id: "msg_\(id)",
                    avatar: template.avatar,
                    nickname: template.name,
                    timestamp: timestamp,
                    summary: template.text,
                    type: .comment,
                    isRead: isRead,
                    unreadCount: unreadCount,
                    remark: nil,
                    isPinned: false,
                    content: .text(template.text)
                )
            }
            
            messages.append(message)
            id += 1
        }
        
        return messages
    }
    
    // MARK: - 分页获取
    
    /// 获取消息列表（支持分页）
    func fetchMessages(page: Int, completion: @escaping ([Message], Bool) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            let startIndex = page * self.pageSize
            let endIndex = min(startIndex + self.pageSize, self.allMessages.count)
            
            guard startIndex < self.allMessages.count else {
                completion([], false)
                return
            }
            
            let pageMessages = Array(self.allMessages[startIndex..<endIndex])
            let hasMore = endIndex < self.allMessages.count
            
            completion(pageMessages, hasMore)
        }
    }
    
    /// 刷新并获取第一页数据
    func refreshMessages(completion: @escaping ([Message], Bool) -> Void) {
        // 随机添加新消息
        if Bool.random() {
            let newMessage = Message(
                id: "msg_new_\(Int(Date().timeIntervalSince1970))",
                avatar: "https://picsum.photos/id/\(Int.random(in: 20...50))/100/100",
                nickname: "新好友",
                timestamp: Date(),
                summary: "刚刚发来了一条新消息",
                type: .friend,
                isRead: false,
                unreadCount: 1,
                remark: nil,
                isPinned: false,
                content: .text("刚刚发来了一条新消息")
            )
            allMessages.insert(newMessage, at: 0)
        }
        
        fetchMessages(page: 0, completion: completion)
    }
    
    /// 模拟请求失败
    func fetchMessagesWithError(completion: @escaping (Result<([Message], Bool), Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if Int.random(in: 0...9) == 0 {
                completion(.failure(NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "网络连接失败，请重试"])))
            } else {
                self.fetchMessages(page: 0) { messages, hasMore in
                    completion(.success((messages, hasMore)))
                }
            }
        }
    }
}
