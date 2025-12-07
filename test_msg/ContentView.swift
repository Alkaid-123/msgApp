//
//  ContentView.swift
//  test_msg
//
//  主视图入口（重定向到消息列表）
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        MessageListView()
    }
}

#Preview {
    ContentView()
}
