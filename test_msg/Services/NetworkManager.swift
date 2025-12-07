//
//  NetworkManager.swift
//  test_msg
//
//  网络管理器 - 模拟弱网/无网体验
//

import Foundation

/// 网络错误类型
enum NetworkError: LocalizedError {
    case timeout
    case noConnection
    case serverError(Int)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return "请求超时，请检查网络后重试"
        case .noConnection:
            return "网络连接失败，请检查网络设置"
        case .serverError(let code):
            return "服务器错误 (\(code))，请稍后重试"
        case .unknown:
            return "未知错误，请稍后重试"
        }
    }
}

/// 网络管理器单例
final class NetworkManager {
    static let shared = NetworkManager()
    
    /// 是否模拟弱网环境
    var simulateWeakNetwork: Bool = false
    
    /// 弱网延迟（秒）
    var weakNetworkDelay: TimeInterval = 3.0
    
    private init() {}
    
    // MARK: - 模拟请求
    
    /// 模拟网络请求
    /// - Parameters:
    ///   - timeout: 超时时间（秒）
    ///   - simulateDelay: 模拟延迟（秒）
    ///   - failureRate: 失败概率（0.0 - 1.0）
    ///   - operation: 实际操作闭包
    /// - Returns: 操作结果
    func simulateRequest<T>(
        timeout: TimeInterval = 5.0,
        simulateDelay: TimeInterval = 1.0,
        failureRate: Double = 0.1,
        operation: @escaping () -> T
    ) async throws -> T {
        
        // 计算实际延迟
        let actualDelay = simulateWeakNetwork ? weakNetworkDelay : simulateDelay
        
        // 检查是否超时
        let startTime = Date()
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + actualDelay) {
                // 检查超时
                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed > timeout {
                    continuation.resume(throwing: NetworkError.timeout)
                    return
                }
                
                // 随机失败
                let shouldFail = Double.random(in: 0...1) < failureRate
                if shouldFail {
                    let errors: [NetworkError] = [.noConnection, .serverError(500), .timeout]
                    continuation.resume(throwing: errors.randomElement()!)
                    return
                }
                
                // 成功返回
                let result = operation()
                continuation.resume(returning: result)
            }
        }
    }
    
    /// 带重试的请求
    func requestWithRetry<T>(
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                print("⚠️ Request failed (attempt \(attempt + 1)/\(maxRetries)): \(error.localizedDescription)")
                
                if attempt < maxRetries - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? NetworkError.unknown
    }
}
