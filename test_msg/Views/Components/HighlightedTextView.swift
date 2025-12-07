//
//  HighlightedTextView.swift
//  test_msg
//
//  高亮文本组件 - 支持关键词高亮显示
//

import SwiftUI

struct HighlightedTextView: View {
    let text: String
    let keyword: String
    
    init(_ text: String, keyword: String = "") {
        self.text = text
        self.keyword = keyword
    }
    
    var body: some View {
        if keyword.isEmpty {
            Text(text)
        } else {
            highlightedText
        }
    }
    
    @ViewBuilder
    private var highlightedText: some View {
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
    
    private func splitText() -> [(text: String, isHighlighted: Bool)] {
        var result: [(String, Bool)] = []
        var currentIndex = text.startIndex
        let lowercasedText = text.lowercased()
        let lowercasedKeyword = keyword.lowercased()
        
        while let range = lowercasedText[currentIndex...].range(of: lowercasedKeyword) {
            // 添加关键词前的文本
            if currentIndex < range.lowerBound {
                let prefix = String(text[currentIndex..<range.lowerBound])
                result.append((prefix, false))
            }
            
            // 添加高亮的关键词（使用原文的大小写）
            let originalRange = Range(uncheckedBounds: (range.lowerBound, range.upperBound))
            let highlightedText = String(text[originalRange])
            result.append((highlightedText, true))
            
            currentIndex = range.upperBound
        }
        
        // 添加剩余文本
        if currentIndex < text.endIndex {
            let suffix = String(text[currentIndex...])
            result.append((suffix, false))
        }
        
        return result.isEmpty ? [(text, false)] : result
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        HighlightedTextView("这是一条测试消息", keyword: "测试")
            .font(.system(size: 16))
        
        HighlightedTextView("Hello World", keyword: "world")
            .font(.system(size: 16))
        
        HighlightedTextView("没有匹配的关键词", keyword: "xyz")
            .font(.system(size: 16))
        
        HighlightedTextView("多次出现test的test消息test", keyword: "test")
            .font(.system(size: 16))
    }
    .padding()
}


