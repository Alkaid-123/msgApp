//
//  RemarkViewModel.swift
//  test_msg
//
//  备注页ViewModel - 管理备注的编辑和持久化
//

import Foundation
import Combine

/// 备注页ViewModel
@MainActor
final class RemarkViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var nickname: String = ""
    @Published var remark: String = ""
    @Published var isSaving: Bool = false
    @Published var showSaveSuccess: Bool = false
    
    // MARK: - Private Properties
    
    private let messageId: String
    private let databaseManager = DatabaseManager.shared
    
    // MARK: - Initialization
    
    init(message: Message) {
        self.messageId = message.id
        self.nickname = message.nickname
        
        // 从SQLite读取已保存的备注
        if let savedRemark = databaseManager.getRemark(messageId: messageId) {
            self.remark = savedRemark
        } else if let existingRemark = message.remark {
            self.remark = existingRemark
        }
    }
    
    // MARK: - Public Methods
    
    /// 保存备注到SQLite
    func saveRemark() {
        isSaving = true
        
        // 模拟保存延迟
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            
            self.databaseManager.saveRemark(
                messageId: self.messageId,
                nickname: self.nickname,
                remark: self.remark
            )
            
            self.isSaving = false
            self.showSaveSuccess = true
            
            // 自动隐藏保存成功提示
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.showSaveSuccess = false
            }
        }
    }
    
    /// 获取当前消息ID
    func getMessageId() -> String {
        return messageId
    }
    
    /// 检查备注是否有变化
    func hasChanges(originalRemark: String?) -> Bool {
        return remark != (originalRemark ?? "")
    }
}

