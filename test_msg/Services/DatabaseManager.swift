//
//  DatabaseManager.swift
//  test_msg
//
//  SQLite数据库管理器 - 管理消息未读状态和备注持久化
//  支持Schema Migration
//

import Foundation
import SQLite3

/// 数据库版本
private let DB_VERSION = 2

/// 数据库管理器单例
final class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var db: OpaquePointer?
    private let dbName = "message_store.sqlite"
    
    private init() {
        openDatabase()
        runMigrations()
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    // MARK: - 数据库连接
    
    private func openDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(dbName)
        
        print("📁 Database path: \(fileURL.path)")
        
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("❌ Error opening database")
            return
        }
        
        print("✅ Database opened successfully")
    }
    
    // MARK: - Migration 系统
    
    private func runMigrations() {
        let currentVersion = getDatabaseVersion()
        print("📊 Current DB version: \(currentVersion), Target version: \(DB_VERSION)")
        
        if currentVersion < 1 {
            migrateToV1()
        }
        
        if currentVersion < 2 {
            migrateToV2()
        }
        
        setDatabaseVersion(DB_VERSION)
    }
    
    /// 获取当前数据库版本
    private func getDatabaseVersion() -> Int {
        var version: Int = 0
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                version = Int(sqlite3_column_int(statement, 0))
            }
        }
        sqlite3_finalize(statement)
        return version
    }
    
    /// 设置数据库版本
    private func setDatabaseVersion(_ version: Int) {
        executeSQL("PRAGMA user_version = \(version);")
        print("✅ Database version set to: \(version)")
    }
    
    /// Migration V1: 初始表结构
    private func migrateToV1() {
        print("🔄 Running migration to V1...")
        
        // 消息状态表
        let createMessageStateTable = """
        CREATE TABLE IF NOT EXISTS message_state (
            message_id TEXT PRIMARY KEY,
            is_read INTEGER DEFAULT 0,
            unread_count INTEGER DEFAULT 0,
            updated_at REAL
        );
        """
        
        // 备注表
        let createRemarkTable = """
        CREATE TABLE IF NOT EXISTS message_remark (
            message_id TEXT PRIMARY KEY,
            nickname TEXT,
            remark TEXT,
            created_at REAL,
            updated_at REAL
        );
        """
        
        executeSQL(createMessageStateTable)
        executeSQL(createRemarkTable)
        print("✅ Migration to V1 completed")
    }
    
    /// Migration V2: 添加 isPinned 字段
    private func migrateToV2() {
        print("🔄 Running migration to V2 - Adding isPinned field...")
        
        // 检查列是否已存在
        if !columnExists(table: "message_state", column: "is_pinned") {
            let alterSQL = "ALTER TABLE message_state ADD COLUMN is_pinned INTEGER DEFAULT 0;"
            executeSQL(alterSQL)
            print("✅ Added is_pinned column to message_state")
        } else {
            print("ℹ️ is_pinned column already exists")
        }
        
        print("✅ Migration to V2 completed")
    }
    
    /// 检查列是否存在
    private func columnExists(table: String, column: String) -> Bool {
        var exists = false
        var statement: OpaquePointer?
        let sql = "PRAGMA table_info(\(table));"
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let cString = sqlite3_column_text(statement, 1) {
                    let columnName = String(cString: cString)
                    if columnName == column {
                        exists = true
                        break
                    }
                }
            }
        }
        sqlite3_finalize(statement)
        return exists
    }
    
    private func executeSQL(_ sql: String) {
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ SQL executed: \(sql.prefix(50))...")
            } else {
                print("❌ SQL execution failed")
            }
        } else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ SQL prepare failed: \(errorMessage)")
        }
        
        sqlite3_finalize(statement)
    }
    
    // MARK: - 消息状态操作
    
    /// 保存消息的已读状态和置顶状态
    func saveMessageState(messageId: String, isRead: Bool, unreadCount: Int, isPinned: Bool) {
        let sql = """
        INSERT OR REPLACE INTO message_state (message_id, is_read, unread_count, is_pinned, updated_at)
        VALUES (?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (messageId as NSString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 2, isRead ? 1 : 0)
            sqlite3_bind_int(statement, 3, Int32(unreadCount))
            sqlite3_bind_int(statement, 4, isPinned ? 1 : 0)
            sqlite3_bind_double(statement, 5, Date().timeIntervalSince1970)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Message state saved: \(messageId)")
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    /// 保存消息的已读状态（兼容旧接口）
    func saveMessageReadState(messageId: String, isRead: Bool, unreadCount: Int) {
        // 先获取现有的置顶状态
        let currentState = getMessageState(messageId: messageId)
        let isPinned = currentState?.isPinned ?? false
        saveMessageState(messageId: messageId, isRead: isRead, unreadCount: unreadCount, isPinned: isPinned)
    }
    
    /// 更新置顶状态
    func updatePinnedState(messageId: String, isPinned: Bool) {
        let currentState = getMessageState(messageId: messageId)
        saveMessageState(
            messageId: messageId,
            isRead: currentState?.isRead ?? false,
            unreadCount: currentState?.unreadCount ?? 0,
            isPinned: isPinned
        )
    }
    
    /// 获取消息状态
    func getMessageState(messageId: String) -> (isRead: Bool, unreadCount: Int, isPinned: Bool)? {
        let sql = "SELECT is_read, unread_count, COALESCE(is_pinned, 0) FROM message_state WHERE message_id = ?;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (messageId as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                let isRead = sqlite3_column_int(statement, 0) == 1
                let unreadCount = Int(sqlite3_column_int(statement, 1))
                let isPinned = sqlite3_column_int(statement, 2) == 1
                sqlite3_finalize(statement)
                return (isRead, unreadCount, isPinned)
            }
        }
        
        sqlite3_finalize(statement)
        return nil
    }
    
    /// 获取消息的已读状态（兼容旧接口）
    func getMessageReadState(messageId: String) -> (isRead: Bool, unreadCount: Int)? {
        if let state = getMessageState(messageId: messageId) {
            return (state.isRead, state.unreadCount)
        }
        return nil
    }
    
    /// 获取所有已保存的消息状态
    func getAllMessageStates() -> [String: (isRead: Bool, unreadCount: Int, isPinned: Bool)] {
        var states: [String: (isRead: Bool, unreadCount: Int, isPinned: Bool)] = [:]
        let sql = "SELECT message_id, is_read, unread_count, COALESCE(is_pinned, 0) FROM message_state;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let cString = sqlite3_column_text(statement, 0) {
                    let messageId = String(cString: cString)
                    let isRead = sqlite3_column_int(statement, 1) == 1
                    let unreadCount = Int(sqlite3_column_int(statement, 2))
                    let isPinned = sqlite3_column_int(statement, 3) == 1
                    states[messageId] = (isRead, unreadCount, isPinned)
                }
            }
        }
        
        sqlite3_finalize(statement)
        return states
    }
    
    // MARK: - 备注操作
    
    /// 保存备注
    func saveRemark(messageId: String, nickname: String, remark: String) {
        let sql = """
        INSERT OR REPLACE INTO message_remark (message_id, nickname, remark, created_at, updated_at)
        VALUES (?, ?, ?, COALESCE((SELECT created_at FROM message_remark WHERE message_id = ?), ?), ?);
        """
        
        var statement: OpaquePointer?
        let now = Date().timeIntervalSince1970
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (messageId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (nickname as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (remark as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 4, (messageId as NSString).utf8String, -1, nil)
            sqlite3_bind_double(statement, 5, now)
            sqlite3_bind_double(statement, 6, now)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Remark saved for: \(messageId)")
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    /// 获取备注
    func getRemark(messageId: String) -> String? {
        let sql = "SELECT remark FROM message_remark WHERE message_id = ?;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (messageId as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                if let cString = sqlite3_column_text(statement, 0) {
                    let remark = String(cString: cString)
                    sqlite3_finalize(statement)
                    return remark
                }
            }
        }
        
        sqlite3_finalize(statement)
        return nil
    }
    
    /// 获取所有备注
    func getAllRemarks() -> [String: String] {
        var remarks: [String: String] = [:]
        let sql = "SELECT message_id, remark FROM message_remark;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let idCString = sqlite3_column_text(statement, 0),
                   let remarkCString = sqlite3_column_text(statement, 1) {
                    let messageId = String(cString: idCString)
                    let remark = String(cString: remarkCString)
                    remarks[messageId] = remark
                }
            }
        }
        
        sqlite3_finalize(statement)
        return remarks
    }
    
    // MARK: - 批量操作
    
    /// 批量保存消息状态
    func batchSaveMessageStates(_ messages: [Message]) {
        for message in messages {
            saveMessageState(messageId: message.id, isRead: message.isRead, unreadCount: message.unreadCount, isPinned: message.isPinned)
        }
    }
    
    /// 将持久化数据应用到消息列表
    func applyPersistedData(to messages: inout [Message]) {
        let states = getAllMessageStates()
        let remarks = getAllRemarks()
        
        for i in 0..<messages.count {
            let id = messages[i].id
            
            // 应用已读状态和置顶状态
            if let state = states[id] {
                messages[i].isRead = state.isRead
                messages[i].unreadCount = state.unreadCount
                messages[i].isPinned = state.isPinned
            }
            
            // 应用备注
            if let remark = remarks[id] {
                messages[i].remark = remark
            }
        }
    }
}
