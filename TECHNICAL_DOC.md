# 抖音简版消息列表 - 技术设计文档

---

## 目录

1. [整体架构设计](#1-整体架构设计)
2. [功能点实现方式](#2-功能点实现方式)
3. [数据库设计与迁移方案](#3-数据库设计与迁移方案)
4. [消息中心与动态插入机制](#4-消息中心与动态插入机制)
5. [问题与解决方案](#5-问题与解决方案)

---

## 1. 整体架构设计

### 1.1 架构模式：MVVM

本项目采用 **MVVM (Model-View-ViewModel)** 架构模式，结合 SwiftUI 的声明式 UI 和 Combine 的响应式编程实现数据驱动的界面更新。

```
┌──────────────────────────────────────────────────────────────────────────┐
│                                View 层                                    │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐          │
│  │ MessageListView │  │ MessageCellView │  │MessageDetailView│          │
│  └────────┬────────┘  └─────────────────┘  └─────────────────┘          │
│           │                                                               │
│           │  @StateObject / @ObservedObject                              │
│           ▼                                                               │
├──────────────────────────────────────────────────────────────────────────┤
│                             ViewModel 层                                  │
│  ┌─────────────────────────┐        ┌─────────────────────────┐         │
│  │  MessageListViewModel   │        │    RemarkViewModel      │         │
│  │  • messages: [Message]  │        │    • remark: String     │         │
│  │  • loadingState         │        │    • saveRemark()       │         │
│  │  • searchText           │        └─────────────────────────┘         │
│  └────────────┬────────────┘                                             │
│               │                                                           │
│               │  方法调用                                                  │
│               ▼                                                           │
├──────────────────────────────────────────────────────────────────────────┤
│                             Service 层                                    │
│  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐ ┌──────────────┐ │
│  │DatabaseManager│ │MockDataService│ │ MessageCenter │ │NetworkManager│ │
│  │  (SQLite)     │ │  (分页数据)    │ │  (消息推送)   │ │  (弱网模拟)  │ │
│  └───────────────┘ └───────────────┘ └───────────────┘ └──────────────┘ │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│                              Model 层                                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐          │
│  │     Message     │  │  MessageContent │  │   MessageType   │          │
│  │  • id, avatar   │  │  • type         │  │  • friend       │          │
│  │  • nickname     │  │  • text         │  │  • system       │          │
│  │  • timestamp    │  │  • imageURL     │  │  • live         │          │
│  │  • content      │  │  • buttonText   │  │  • promotion    │          │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘          │
└──────────────────────────────────────────────────────────────────────────┘
```

### 1.2 各层职责

| 层级 | 职责 | 主要文件 |
|-----|------|---------|
| **View** | 纯 UI 展示，不包含业务逻辑 | `MessageListView.swift`, `MessageCellView.swift` |
| **ViewModel** | 业务逻辑处理，状态管理，数据转换 | `MessageListViewModel.swift`, `RemarkViewModel.swift` |
| **Service** | 数据获取、存储、网络请求、消息推送 | `DatabaseManager.swift`, `MockDataService.swift` |
| **Model** | 数据结构定义，JSON 解析 | `Message.swift` |

### 1.3 数据流向

```
用户操作 → View → ViewModel → Service → Database/Network
                      ↓
              @Published 属性变化
                      ↓
              View 自动刷新 (SwiftUI)
```

### 1.4 依赖关系

```swift
// View 持有 ViewModel
@StateObject private var viewModel = MessageListViewModel()

// ViewModel 持有 Services（单例）
private let dataService = MockDataService.shared
private let databaseManager = DatabaseManager.shared
private let messageCenter = MessageCenter.shared
private let networkManager = NetworkManager.shared
```

---

## 2. 功能点实现方式

### 2.1 消息列表

#### 2.1.1 列表渲染

使用 `LazyVStack` + `ForEach` 实现懒加载列表：

```swift
// MessageListView.swift
ScrollView {
    LazyVStack(spacing: 0) {
        ForEach(viewModel.filteredMessages) { message in
            MessageCellView(message: message, searchKeyword: viewModel.searchText)
                .onTapGesture {
                    handleMessageTap(message)
                }
        }
    }
}
```

#### 2.1.2 下拉刷新

使用 SwiftUI 原生 `.refreshable` 修饰符：

```swift
ScrollView { ... }
    .refreshable {
        await viewModel.refresh()
    }
```

#### 2.1.3 上滑加载更多

在列表底部添加加载触发器：

```swift
if viewModel.hasMore {
    loadMoreView
        .onAppear {
            Task {
                await viewModel.loadMore()
            }
        }
}
```

### 2.2 消息类型化展示

#### 2.2.1 内容类型定义

```swift
enum MessageContentType: String, Codable {
    case text = "text"      // 纯文本
    case image = "image"    // 携带图片
    case button = "button"  // 运营按钮
}

struct MessageContent: Codable {
    let type: MessageContentType
    let text: String
    let imageURL: String?
    let buttonText: String?
    let buttonAction: String?
}
```

#### 2.2.2 Cell 自适应布局

```swift
// MessageCellView.swift
@ViewBuilder
private var contentPreview: some View {
    switch message.content.type {
    case .text:
        textContentView       // 单行文本，高度约 20pt
    case .image:
        imageContentView      // 文本 + 图片，高度约 110pt
    case .button:
        buttonContentView     // 文本 + 按钮，高度约 70pt
    }
}
```

### 2.3 搜索与高亮

#### 2.3.1 搜索过滤

```swift
// MessageListViewModel.swift
var filteredMessages: [Message] {
    if searchText.isEmpty {
        return sortedMessages
    }
    let keyword = searchText.lowercased()
    return sortedMessages.filter { message in
        message.displayName.lowercased().contains(keyword) ||
        message.summary.lowercased().contains(keyword) ||
        message.content.text.lowercased().contains(keyword)
    }
}
```

#### 2.3.2 关键词高亮

```swift
// HighlightedTextView.swift
struct HighlightedTextView: View {
    let text: String
    let keyword: String
    
    var body: some View {
        let parts = splitText()
        parts.reduce(Text("")) { result, part in
            if part.isHighlighted {
                return result + Text(part.text)
                    .foregroundColor(.pink)
                    .fontWeight(.semibold)
            } else {
                return result + Text(part.text)
            }
        }
    }
}
```

### 2.4 备注功能

#### 2.4.1 数据流

```
用户输入 → TextField → @Published remark → 点击保存 → DatabaseManager.saveRemark() → SQLite
                                                              ↓
列表显示 ← applyPersistedData() ← getAllRemarks() ← SQLite
```

#### 2.4.2 持久化读取

```swift
// DatabaseManager.swift
func saveRemark(messageId: String, nickname: String, remark: String) {
    let sql = """
    INSERT OR REPLACE INTO message_remark (message_id, nickname, remark, ...)
    VALUES (?, ?, ?, ...);
    """
    // 执行 SQL
}

func getRemark(messageId: String) -> String? {
    let sql = "SELECT remark FROM message_remark WHERE message_id = ?;"
    // 查询并返回
}
```

### 2.5 置顶功能

#### 2.5.1 排序逻辑

```swift
// MessageListViewModel.swift
private var sortedMessages: [Message] {
    messages.sorted { lhs, rhs in
        // 置顶优先
        if lhs.isPinned != rhs.isPinned {
            return lhs.isPinned
        }
        // 然后按时间倒序
        return lhs.timestamp > rhs.timestamp
    }
}
```

### 2.6 时间文案格式化

```swift
// Message.swift
var timeText: String {
    let now = Date()
    let interval = now.timeIntervalSince(timestamp)
    
    if interval < 60 {
        return "刚刚"
    }
    if interval < 3600 {
        return "\(Int(interval / 60))分钟前"
    }
    if Calendar.current.isDateInToday(timestamp) {
        return DateFormatter("HH:mm").string(from: timestamp)
    }
    if Calendar.current.isDateInYesterday(timestamp) {
        return "昨天 " + DateFormatter("HH:mm").string(from: timestamp)
    }
    let days = Calendar.current.dateComponents([.day], from: timestamp, to: now).day ?? 0
    if days < 7 {
        return "\(days)天前"
    }
    return DateFormatter("MM-dd").string(from: timestamp)
}
```

### 2.7 空态与错误处理

#### 2.7.1 状态枚举

```swift
enum LoadingState: Equatable {
    case idle           // 正常
    case loading        // 首次加载
    case refreshing     // 下拉刷新
    case loadingMore    // 加载更多
    case error(String)  // 错误
    case empty          // 无数据
}
```

#### 2.7.2 状态驱动 UI

```swift
@ViewBuilder
private var contentView: some View {
    switch viewModel.loadingState {
    case .loading:
        SkeletonListView()
    case .empty:
        EmptyStateView(type: .noData) { ... }
    case .error(let message):
        EmptyStateView(type: .error(message)) { ... }
    default:
        messageListView
    }
}
```

---

## 3. 数据库设计与迁移方案

### 3.1 表结构设计

#### 3.1.1 消息状态表

```sql
CREATE TABLE message_state (
    message_id TEXT PRIMARY KEY,    -- 消息唯一标识
    is_read INTEGER DEFAULT 0,      -- 是否已读：0-未读，1-已读
    unread_count INTEGER DEFAULT 0, -- 未读数量
    is_pinned INTEGER DEFAULT 0,    -- 是否置顶：0-否，1-是 (V2新增)
    updated_at REAL                 -- 更新时间戳
);
```

#### 3.1.2 备注表

```sql
CREATE TABLE message_remark (
    message_id TEXT PRIMARY KEY,    -- 消息唯一标识
    nickname TEXT,                  -- 原始昵称
    remark TEXT,                    -- 用户设置的备注
    created_at REAL,                -- 创建时间
    updated_at REAL                 -- 更新时间
);
```

### 3.2 迁移方案设计

#### 3.2.1 版本管理

使用 SQLite 内置的 `PRAGMA user_version` 管理版本：

```swift
private let DB_VERSION = 2  // 当前目标版本

private func getDatabaseVersion() -> Int {
    var version: Int = 0
    sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &statement, nil)
    if sqlite3_step(statement) == SQLITE_ROW {
        version = Int(sqlite3_column_int(statement, 0))
    }
    return version
}

private func setDatabaseVersion(_ version: Int) {
    executeSQL("PRAGMA user_version = \(version);")
}
```

#### 3.2.2 迁移流程

```
App 启动
    ↓
打开数据库
    ↓
获取当前版本号 (PRAGMA user_version)
    ↓
┌─ 版本 < 1 → 执行 migrateToV1() [创建基础表]
│
├─ 版本 < 2 → 执行 migrateToV2() [添加 is_pinned 列]
│
└─ 版本 < N → 执行 migrateToVN() [未来扩展]
    ↓
更新版本号为 DB_VERSION
    ↓
迁移完成
```

#### 3.2.3 迁移代码实现

```swift
// DatabaseManager.swift
private func runMigrations() {
    let currentVersion = getDatabaseVersion()
    print("📊 Current DB version: \(currentVersion), Target: \(DB_VERSION)")
    
    if currentVersion < 1 {
        migrateToV1()
    }
    
    if currentVersion < 2 {
        migrateToV2()
    }
    
    setDatabaseVersion(DB_VERSION)
}

/// V1: 创建基础表
private func migrateToV1() {
    print("🔄 Running migration to V1...")
    
    executeSQL("""
        CREATE TABLE IF NOT EXISTS message_state (
            message_id TEXT PRIMARY KEY,
            is_read INTEGER DEFAULT 0,
            unread_count INTEGER DEFAULT 0,
            updated_at REAL
        );
    """)
    
    executeSQL("""
        CREATE TABLE IF NOT EXISTS message_remark (
            message_id TEXT PRIMARY KEY,
            nickname TEXT,
            remark TEXT,
            created_at REAL,
            updated_at REAL
        );
    """)
    
    print("✅ Migration to V1 completed")
}

/// V2: 添加置顶字段
private func migrateToV2() {
    print("🔄 Running migration to V2 - Adding isPinned field...")
    
    // 检查列是否已存在（幂等性保证）
    if !columnExists(table: "message_state", column: "is_pinned") {
        executeSQL("ALTER TABLE message_state ADD COLUMN is_pinned INTEGER DEFAULT 0;")
        print("✅ Added is_pinned column")
    } else {
        print("ℹ️ is_pinned column already exists")
    }
    
    print("✅ Migration to V2 completed")
}

/// 检查列是否存在
private func columnExists(table: String, column: String) -> Bool {
    var exists = false
    let sql = "PRAGMA table_info(\(table));"
    
    sqlite3_prepare_v2(db, sql, -1, &statement, nil)
    while sqlite3_step(statement) == SQLITE_ROW {
        if let cString = sqlite3_column_text(statement, 1) {
            if String(cString: cString) == column {
                exists = true
                break
            }
        }
    }
    return exists
}
```

#### 3.2.4 迁移设计原则

| 原则 | 说明 |
|-----|------|
| **增量迁移** | 每次只执行未完成的迁移，不重复执行 |
| **幂等性** | 同一迁移可安全重复执行（检查列是否存在） |
| **向后兼容** | 新增字段使用 DEFAULT 值，不影响旧数据 |
| **不删除数据** | 只做 ADD COLUMN，不做 DROP COLUMN |

---

## 4. 消息中心与动态插入机制

### 4.1 消息中心设计

#### 4.1.1 架构图

```
┌──────────────────────────────────────────────────────────────┐
│                      MessageCenter                            │
│  ┌─────────────────────────────────────────────────────┐     │
│  │                   @Published                         │     │
│  │              latestMessage: Message?                 │     │
│  └──────────────────────┬──────────────────────────────┘     │
│                         │                                     │
│  ┌──────────────────────▼──────────────────────────────┐     │
│  │                    Timer                             │     │
│  │           每 5 秒触发 pushNewMessage()               │     │
│  └──────────────────────┬──────────────────────────────┘     │
│                         │                                     │
│  ┌──────────────────────▼──────────────────────────────┐     │
│  │            generateRandomMessage()                   │     │
│  │    生成随机消息（好友/系统/直播/运营等）              │     │
│  └─────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────┘
                          │
                          │ Combine 订阅
                          ▼
┌──────────────────────────────────────────────────────────────┐
│                 MessageListViewModel                          │
│  ┌─────────────────────────────────────────────────────┐     │
│  │           setupMessageCenterSubscription()           │     │
│  │                                                      │     │
│  │  messageCenter.$latestMessage                        │     │
│  │      .compactMap { $0 }                              │     │
│  │      .sink { self.handleNewMessage($0) }             │     │
│  └──────────────────────┬──────────────────────────────┘     │
│                         │                                     │
│  ┌──────────────────────▼──────────────────────────────┐     │
│  │              handleNewMessage()                      │     │
│  │  1. 应用持久化数据                                    │     │
│  │  2. 插入列表顶部                                      │     │
│  │  3. 更新未读数                                        │     │
│  │  4. 触发滚动到顶部                                    │     │
│  └─────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────┘
                          │
                          │ @Published 变化
                          ▼
┌──────────────────────────────────────────────────────────────┐
│                    MessageListView                            │
│                  UI 自动刷新显示新消息                         │
└──────────────────────────────────────────────────────────────┘
```

### 4.2 核心代码实现

#### 4.2.1 消息中心

```swift
// MessageCenter.swift
final class MessageCenter: ObservableObject {
    static let shared = MessageCenter()
    
    /// 最新消息，使用 Combine 发布
    @Published var latestMessage: Message?
    
    private var timer: Timer?
    private var messageId = 1000
    
    /// 启动定时推送
    func startPushing(interval: TimeInterval = 5.0) {
        stopPushing()
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.pushNewMessage()
        }
    }
    
    /// 停止推送
    func stopPushing() {
        timer?.invalidate()
        timer = nil
    }
    
    /// 推送新消息
    func pushNewMessage() {
        let message = generateRandomMessage()
        
        DispatchQueue.main.async { [weak self] in
            self?.latestMessage = message
        }
    }
    
    /// 生成随机消息
    private func generateRandomMessage() -> Message {
        messageId += 1
        
        let templates = [
            // 好友文本消息
            ("老朋友", "https://...", "好久不见！", .friend, .text("好久不见！")),
            // 好友图片消息
            ("摄影师", "https://...", "[图片]", .friend, .image(text: "新拍的照片", imageURL: "...")),
            // 系统消息
            ("系统通知", "system_notification", "您有新的通知", .system, .text("...")),
            // 运营消息
            ("抖音官方", "douyin_official", "专属福利", .promotion, .button(text: "...", buttonText: "领取", action: "claim")),
            // ...
        ]
        
        let template = templates.randomElement()!
        
        return Message(
            id: "msg_push_\(messageId)",
            avatar: template.1,
            nickname: template.0,
            timestamp: Date(),
            summary: template.2,
            type: template.3,
            isRead: false,
            unreadCount: Int.random(in: 1...5),
            remark: nil,
            isPinned: false,
            content: template.4
        )
    }
}
```

#### 4.2.2 ViewModel 订阅

```swift
// MessageListViewModel.swift
private var cancellables = Set<AnyCancellable>()

init() {
    setupMessageCenterSubscription()
}

private func setupMessageCenterSubscription() {
    messageCenter.$latestMessage
        .compactMap { $0 }                    // 过滤 nil
        .receive(on: DispatchQueue.main)      // 主线程接收
        .sink { [weak self] newMessage in
            self?.handleNewMessage(newMessage)
        }
        .store(in: &cancellables)
}
```

### 4.3 动态插入机制

#### 4.3.1 插入流程

```swift
private func handleNewMessage(_ message: Message) {
    // 1. 复制消息并应用持久化数据
    var newMessage = message
    var tempMessages = [newMessage]
    databaseManager.applyPersistedData(to: &tempMessages)
    if let updated = tempMessages.first {
        newMessage = updated
    }
    
    // 2. 记录统计事件
    analytics.trackMessageReceived(newMessage)
    
    // 3. 带动画插入列表顶部
    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
        messages.insert(newMessage, at: 0)
        updateUnreadCount()
        scrollToTop = true  // 触发滚动
    }
    
    // 4. 记录展示事件
    analytics.trackMessageDisplayed(newMessage)
    
    // 5. 重置滚动标志
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.scrollToTop = false
    }
}
```

#### 4.3.2 滚动到顶部实现

```swift
// MessageListView.swift
@State private var scrollProxy: ScrollViewProxy?

ScrollViewReader { proxy in
    ScrollView {
        LazyVStack {
            // 顶部锚点
            Color.clear.frame(height: 1).id("top")
            
            // 消息列表
            ForEach(viewModel.filteredMessages) { ... }
        }
    }
    .onAppear { scrollProxy = proxy }
}
.onChange(of: viewModel.scrollToTop) { _, newValue in
    if newValue {
        withAnimation(.spring(response: 0.3)) {
            scrollProxy?.scrollTo("top", anchor: .top)
        }
    }
}
```

### 4.4 消息推送时序图

```
时间轴 →
    
Timer (5s)          MessageCenter           ViewModel              View
    │                    │                      │                    │
    │──── 触发 ─────────▶│                      │                    │
    │                    │                      │                    │
    │                    │── generateMessage() │                    │
    │                    │                      │                    │
    │                    │── latestMessage = ──▶│                    │
    │                    │      message         │                    │
    │                    │                      │                    │
    │                    │                      │── handleNewMessage │
    │                    │                      │                    │
    │                    │                      │── messages.insert()│
    │                    │                      │                    │
    │                    │                      │── scrollToTop=true─▶│
    │                    │                      │                    │
    │                    │                      │                    │── UI刷新
    │                    │                      │                    │── 滚动动画
    │                    │                      │                    │
```

---

## 5. 问题与解决方案

### 问题1：fullScreenCover 与自定义动画冲突

#### 问题描述

使用 SwiftUI 的 `fullScreenCover` 展示备注页时，实现了自定义的卡片放大进入 + 下滑退出动画。但退出时出现"先弹框消失，后灰色背景消失"的割裂效果。

#### 原因分析

`fullScreenCover` 有自己的系统转场动画（淡入淡出），当我们在内部实现自定义动画并设置 `isPresented = false` 时：

1. 自定义动画执行（卡片消失）
2. `isPresented` 变化触发系统动画（背景消失）

两个动画串行执行，导致割裂感。

#### 解决方案

弃用 `fullScreenCover`，改用 `ZStack` 覆盖层：

```swift
// 修改前 ❌
.fullScreenCover(isPresented: $showDetailSheet) {
    MessageDetailView(...)
}

// 修改后 ✅
var body: some View {
    ZStack {
        NavigationStack { ... }
        
        if showDetailSheet, let message = selectedMessage {
            MessageDetailView(...)
                .transition(.identity)  // 禁用默认转场
                .zIndex(1)
        }
    }
}
```

同时在 `MessageDetailView` 中分离背景和卡片的透明度：

```swift
@State private var backgroundOpacity: Double = 0
@State private var cardOpacity: Double = 0

private func dismissWithAnimation() {
    withAnimation(.easeOut(duration: 0.25)) {
        backgroundOpacity = 0  // 背景同步消失
        cardOpacity = 0        // 卡片同步消失
        offset = CGSize(width: 0, height: 200)
    }
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
        isPresented = false
    }
}
```

#### 效果对比

| 修改前 | 修改后 |
|-------|-------|
| 卡片先消失 → 灰色背景后消失 | 卡片和背景同步消失 |
| 两段式动画，体验割裂 | 一体化动画，流畅自然 |

---

### 问题2：inout 参数传递数组字面量

#### 问题描述

在处理新消息时，需要调用 `applyPersistedData(to: &messages)` 方法，该方法接受 `inout [Message]` 参数。但当尝试传递单个消息时：

```swift
databaseManager.applyPersistedData(to: &[newMessage].self)
// 报错：Cannot pass immutable value of type '[Message]' as inout argument
```

#### 原因分析

`[newMessage]` 是一个临时数组字面量，是不可变的（immutable）。Swift 不允许将不可变值作为 `inout` 参数传递，因为 `inout` 需要能够修改原始值。

#### 解决方案

创建一个可变的临时数组：

```swift
// 修改前 ❌
databaseManager.applyPersistedData(to: &[newMessage].self)

// 修改后 ✅
var tempMessages = [newMessage]  // 创建可变数组
databaseManager.applyPersistedData(to: &tempMessages)
if let updatedMessage = tempMessages.first {
    newMessage = updatedMessage
}
```

---

### 问题3：LoadingState 枚举不支持 != 比较

#### 问题描述

```swift
guard loadingState != .loadingMore else { return }
// 报错：Binary operator '!=' cannot be applied to two 'LoadingState' operands
```

#### 原因分析

`LoadingState` 枚举包含关联值 `error(String)`，Swift 不会自动为包含关联值的枚举生成 `Equatable` 实现。

#### 解决方案

显式声明 `Equatable` 协议：

```swift
// 修改前 ❌
enum LoadingState {
    case idle
    case loading
    case error(String)
    // ...
}

// 修改后 ✅
enum LoadingState: Equatable {  // 添加 Equatable
    case idle
    case loading
    case error(String)
    // ...
}
```

Swift 会自动合成 `Equatable` 实现，比较 `error` case 时会同时比较关联的 `String` 值。

