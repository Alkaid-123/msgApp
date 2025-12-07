//
//  AnalyticsManager.swift
//  test_msg
//
//  数据统计管理器 - 消息召回与增长策略数据分析
//

import Foundation
import Combine

/// 消息事件类型
enum MessageEvent: String, Codable {
    case received = "received"      // 收到消息
    case displayed = "displayed"    // 消息展示
    case clicked = "clicked"        // 消息点击
    case read = "read"              // 消息已读
    case buttonClicked = "button_clicked"  // 按钮点击
}

/// 事件记录
struct EventRecord: Codable, Identifiable {
    let id: String
    let event: MessageEvent
    let messageId: String
    let messageType: MessageType
    let timestamp: Date
    
    init(event: MessageEvent, messageId: String, messageType: MessageType) {
        self.id = UUID().uuidString
        self.event = event
        self.messageId = messageId
        self.messageType = messageType
        self.timestamp = Date()
    }
}

/// 每日统计数据
struct DailyStats: Codable, Identifiable {
    var id: String { dateString }
    let dateString: String
    var totalReceived: Int = 0
    var totalDisplayed: Int = 0
    var totalClicked: Int = 0
    var totalRead: Int = 0
    var unreadCount: Int = 0
    var typeStats: [String: TypeStats] = [:]
    
    /// 消息CTR（点击率）= 点击数 / 展示数
    var ctr: Double {
        guard totalDisplayed > 0 else { return 0 }
        return Double(totalClicked) / Double(totalDisplayed) * 100
    }
    
    /// 已读率 = 已读数 / 收到数
    var readRate: Double {
        guard totalReceived > 0 else { return 0 }
        return Double(totalRead) / Double(totalReceived) * 100
    }
}

/// 按类型统计
struct TypeStats: Codable {
    var received: Int = 0
    var displayed: Int = 0
    var clicked: Int = 0
    var read: Int = 0
    
    /// 召回率 = 点击数 / 收到数
    var recallRate: Double {
        guard received > 0 else { return 0 }
        return Double(clicked) / Double(received) * 100
    }
    
    /// CTR
    var ctr: Double {
        guard displayed > 0 else { return 0 }
        return Double(clicked) / Double(displayed) * 100
    }
}

/// 数据统计管理器
final class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()
    
    // MARK: - Published Properties
    
    @Published var todayStats: DailyStats
    @Published var weeklyStats: [DailyStats] = []
    @Published var totalStats: DailyStats
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let statsKey = "message_analytics_stats"
    private let eventsKey = "message_analytics_events"
    
    private var allEvents: [EventRecord] = []
    
    // MARK: - Initialization
    
    private init() {
        let today = Self.dateString(from: Date())
        self.todayStats = DailyStats(dateString: today)
        self.totalStats = DailyStats(dateString: "total")
        
        loadStats()
        generateMockHistoryData()
    }
    
    // MARK: - Event Tracking
    
    /// 记录消息事件
    func trackEvent(_ event: MessageEvent, messageId: String, messageType: MessageType) {
        let record = EventRecord(event: event, messageId: messageId, messageType: messageType)
        allEvents.append(record)
        
        // 更新今日统计
        updateStats(for: record)
        
        // 持久化
        saveStats()
        
        print("📊 Analytics: \(event.rawValue) - \(messageType.rawValue) - \(messageId)")
    }
    
    /// 记录消息收到
    func trackMessageReceived(_ message: Message) {
        trackEvent(.received, messageId: message.id, messageType: message.type)
    }
    
    /// 记录消息展示
    func trackMessageDisplayed(_ message: Message) {
        trackEvent(.displayed, messageId: message.id, messageType: message.type)
    }
    
    /// 记录消息点击
    func trackMessageClicked(_ message: Message) {
        trackEvent(.clicked, messageId: message.id, messageType: message.type)
    }
    
    /// 记录消息已读
    func trackMessageRead(_ message: Message) {
        trackEvent(.read, messageId: message.id, messageType: message.type)
    }
    
    /// 记录按钮点击
    func trackButtonClicked(_ message: Message, action: String) {
        trackEvent(.buttonClicked, messageId: message.id, messageType: message.type)
    }
    
    // MARK: - Stats Update
    
    private func updateStats(for record: EventRecord) {
        let today = Self.dateString(from: Date())
        
        // 确保今日统计存在
        if todayStats.dateString != today {
            todayStats = DailyStats(dateString: today)
        }
        
        let typeKey = record.messageType.rawValue
        
        // 初始化类型统计
        if todayStats.typeStats[typeKey] == nil {
            todayStats.typeStats[typeKey] = TypeStats()
        }
        if totalStats.typeStats[typeKey] == nil {
            totalStats.typeStats[typeKey] = TypeStats()
        }
        
        // 更新统计
        switch record.event {
        case .received:
            todayStats.totalReceived += 1
            todayStats.unreadCount += 1
            todayStats.typeStats[typeKey]?.received += 1
            totalStats.totalReceived += 1
            totalStats.typeStats[typeKey]?.received += 1
            
        case .displayed:
            todayStats.totalDisplayed += 1
            todayStats.typeStats[typeKey]?.displayed += 1
            totalStats.totalDisplayed += 1
            totalStats.typeStats[typeKey]?.displayed += 1
            
        case .clicked:
            todayStats.totalClicked += 1
            todayStats.typeStats[typeKey]?.clicked += 1
            totalStats.totalClicked += 1
            totalStats.typeStats[typeKey]?.clicked += 1
            
        case .read:
            todayStats.totalRead += 1
            todayStats.unreadCount = max(0, todayStats.unreadCount - 1)
            todayStats.typeStats[typeKey]?.read += 1
            totalStats.totalRead += 1
            totalStats.typeStats[typeKey]?.read += 1
            
        case .buttonClicked:
            todayStats.totalClicked += 1
            todayStats.typeStats[typeKey]?.clicked += 1
            totalStats.totalClicked += 1
            totalStats.typeStats[typeKey]?.clicked += 1
        }
        
        // 触发 UI 更新
        objectWillChange.send()
    }
    
    // MARK: - Persistence
    
    private func saveStats() {
        if let encoded = try? JSONEncoder().encode(todayStats) {
            userDefaults.set(encoded, forKey: statsKey + "_today")
        }
        if let encoded = try? JSONEncoder().encode(totalStats) {
            userDefaults.set(encoded, forKey: statsKey + "_total")
        }
        if let encoded = try? JSONEncoder().encode(weeklyStats) {
            userDefaults.set(encoded, forKey: statsKey + "_weekly")
        }
    }
    
    private func loadStats() {
        let today = Self.dateString(from: Date())
        
        if let data = userDefaults.data(forKey: statsKey + "_today"),
           let stats = try? JSONDecoder().decode(DailyStats.self, from: data),
           stats.dateString == today {
            todayStats = stats
        }
        
        if let data = userDefaults.data(forKey: statsKey + "_total"),
           let stats = try? JSONDecoder().decode(DailyStats.self, from: data) {
            totalStats = stats
        }
        
        if let data = userDefaults.data(forKey: statsKey + "_weekly"),
           let stats = try? JSONDecoder().decode([DailyStats].self, from: data) {
            weeklyStats = stats
        }
    }
    
    // MARK: - Mock Data
    
    /// 生成模拟历史数据用于展示
    private func generateMockHistoryData() {
        guard weeklyStats.isEmpty else { return }
        
        let calendar = Calendar.current
        var stats: [DailyStats] = []
        
        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else { continue }
            let dateStr = Self.dateString(from: date)
            
            var dailyStats = DailyStats(dateString: dateStr)
            
            // 随机生成数据
            dailyStats.totalReceived = Int.random(in: 15...40)
            dailyStats.totalDisplayed = Int.random(in: Int(Double(dailyStats.totalReceived) * 0.8)...dailyStats.totalReceived)
            dailyStats.totalClicked = Int.random(in: Int(Double(dailyStats.totalDisplayed) * 0.3)...Int(Double(dailyStats.totalDisplayed) * 0.7))
            dailyStats.totalRead = Int.random(in: dailyStats.totalClicked...Int(Double(dailyStats.totalReceived) * 0.9))
            dailyStats.unreadCount = dailyStats.totalReceived - dailyStats.totalRead
            
            // 按类型统计
            let types: [MessageType] = [.friend, .system, .live, .comment, .promotion]
            for type in types {
                var typeStats = TypeStats()
                let ratio = type == .friend ? 0.4 : 0.15
                typeStats.received = Int(Double(dailyStats.totalReceived) * ratio)
                typeStats.displayed = Int(Double(dailyStats.totalDisplayed) * ratio)
                typeStats.clicked = Int(Double(dailyStats.totalClicked) * ratio * Double.random(in: 0.8...1.2))
                typeStats.read = Int(Double(dailyStats.totalRead) * ratio)
                dailyStats.typeStats[type.rawValue] = typeStats
            }
            
            stats.append(dailyStats)
        }
        
        weeklyStats = stats
        
        // 更新总计
        if totalStats.totalReceived == 0 {
            for daily in stats {
                totalStats.totalReceived += daily.totalReceived
                totalStats.totalDisplayed += daily.totalDisplayed
                totalStats.totalClicked += daily.totalClicked
                totalStats.totalRead += daily.totalRead
            }
        }
        
        saveStats()
    }
    
    // MARK: - Helpers
    
    static func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    /// 获取类型显示名称
    static func typeName(for type: String) -> String {
        switch type {
        case "friend": return "好友消息"
        case "system": return "系统消息"
        case "live": return "直播提醒"
        case "comment": return "评论互动"
        case "promotion": return "活动推广"
        default: return type
        }
    }
    
    /// 获取类型颜色
    static func typeColor(for type: String) -> String {
        switch type {
        case "friend": return "blue"
        case "system": return "orange"
        case "live": return "pink"
        case "comment": return "green"
        case "promotion": return "purple"
        default: return "gray"
        }
    }
    
    /// 重置统计数据（用于测试）
    func resetStats() {
        let today = Self.dateString(from: Date())
        todayStats = DailyStats(dateString: today)
        totalStats = DailyStats(dateString: "total")
        weeklyStats = []
        allEvents = []
        
        userDefaults.removeObject(forKey: statsKey + "_today")
        userDefaults.removeObject(forKey: statsKey + "_total")
        userDefaults.removeObject(forKey: statsKey + "_weekly")
        
        generateMockHistoryData()
    }
}


