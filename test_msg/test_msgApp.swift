//
//  test_msgApp.swift
//  test_msg
//
//  抖音简版消息列表应用
//  架构：SwiftUI + MVVM
//

import SwiftUI

@main
struct test_msgApp: App {
    
    init() {
        // 初始化数据库
        _ = DatabaseManager.shared
        
        // 配置导航栏外观
        configureNavigationBar()
        }

    var body: some Scene {
        WindowGroup {
            MessageListView()
        }
    }
    
    /// 配置导航栏外观
    private func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}
