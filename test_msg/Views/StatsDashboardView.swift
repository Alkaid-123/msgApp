//
//  StatsDashboardView.swift
//  test_msg
//
//  数据看板 - 消息召回与增长策略数据展示
//

import SwiftUI

struct StatsDashboardView: View {
    @ObservedObject private var analytics = AnalyticsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 顶部概览卡片
                    overviewCards
                    
                    // Tab 切换
                    segmentedControl
                    
                    // 内容区域
                    if selectedTab == 0 {
                        todayStatsSection
                    } else {
                        weeklyTrendSection
                    }
                    
                    // 按类型统计
                    typeStatsSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("数据看板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        analytics.resetStats()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
            }
        }
    }
    
    // MARK: - Overview Cards
    
    private var overviewCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatCard(
                    title: "今日消息",
                    value: "\(analytics.todayStats.totalReceived)",
                    subtitle: "收到",
                    icon: "envelope.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "未读消息",
                    value: "\(analytics.todayStats.unreadCount)",
                    subtitle: "待处理",
                    icon: "envelope.badge.fill",
                    color: .red
                )
            }
            
            HStack(spacing: 12) {
                StatCard(
                    title: "点击率 CTR",
                    value: String(format: "%.1f%%", analytics.todayStats.ctr),
                    subtitle: "点击/展示",
                    icon: "hand.tap.fill",
                    color: .green
                )
                
                StatCard(
                    title: "已读率",
                    value: String(format: "%.1f%%", analytics.todayStats.readRate),
                    subtitle: "已读/收到",
                    icon: "checkmark.circle.fill",
                    color: .orange
                )
            }
        }
    }
    
    // MARK: - Segmented Control
    
    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(["今日详情", "周趋势"].indices, id: \.self) { index in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                    }
                } label: {
                    Text(["今日详情", "周趋势"][index])
                        .font(.system(size: 14, weight: selectedTab == index ? .semibold : .regular))
                        .foregroundColor(selectedTab == index ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedTab == index ?
                            LinearGradient(colors: [.pink, .red], startPoint: .leading, endPoint: .trailing) :
                            LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
                        )
                }
            }
        }
        .background(Color(.systemGray5))
        .cornerRadius(10)
    }
    
    // MARK: - Today Stats Section
    
    private var todayStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "今日数据", icon: "calendar")
            
            VStack(spacing: 12) {
                DataRow(label: "收到消息", value: "\(analytics.todayStats.totalReceived) 条")
                DataRow(label: "消息展示", value: "\(analytics.todayStats.totalDisplayed) 次")
                DataRow(label: "消息点击", value: "\(analytics.todayStats.totalClicked) 次")
                DataRow(label: "消息已读", value: "\(analytics.todayStats.totalRead) 条")
                
                Divider()
                
                DataRow(
                    label: "点击率 (CTR)",
                    value: String(format: "%.2f%%", analytics.todayStats.ctr),
                    highlight: true
                )
                DataRow(
                    label: "召回率",
                    value: String(format: "%.2f%%", analytics.todayStats.totalReceived > 0 ? Double(analytics.todayStats.totalClicked) / Double(analytics.todayStats.totalReceived) * 100 : 0),
                    highlight: true
                )
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Weekly Trend Section
    
    private var weeklyTrendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "近7日趋势", icon: "chart.line.uptrend.xyaxis")
            
            VStack(spacing: 16) {
                // 简易柱状图
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(analytics.weeklyStats.reversed()) { day in
                        VStack(spacing: 4) {
                            // 柱子
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.pink, .red],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(width: 30, height: barHeight(for: day.totalReceived))
                            
                            // 日期
                            Text(shortDate(day.dateString))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                
                // 图例
                HStack(spacing: 20) {
                    LegendItem(color: .pink, label: "收到消息")
                }
                .font(.system(size: 12))
                
                Divider()
                
                // 周汇总
                let weekTotal = analytics.weeklyStats.reduce(0) { $0 + $1.totalReceived }
                let weekClicked = analytics.weeklyStats.reduce(0) { $0 + $1.totalClicked }
                let weekRead = analytics.weeklyStats.reduce(0) { $0 + $1.totalRead }
                
                DataRow(label: "本周收到", value: "\(weekTotal) 条")
                DataRow(label: "本周点击", value: "\(weekClicked) 次")
                DataRow(label: "本周已读", value: "\(weekRead) 条")
                DataRow(
                    label: "周平均CTR",
                    value: String(format: "%.2f%%", weekTotal > 0 ? Double(weekClicked) / Double(weekTotal) * 100 : 0),
                    highlight: true
                )
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Type Stats Section
    
    private var typeStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "分类型召回率", icon: "chart.pie.fill")
            
            VStack(spacing: 12) {
                ForEach(Array(analytics.totalStats.typeStats.keys.sorted()), id: \.self) { typeKey in
                    if let stats = analytics.totalStats.typeStats[typeKey] {
                        TypeStatsRow(
                            typeName: AnalyticsManager.typeName(for: typeKey),
                            typeColor: colorFor(typeKey),
                            received: stats.received,
                            clicked: stats.clicked,
                            recallRate: stats.recallRate
                        )
                    }
                }
                
                if analytics.totalStats.typeStats.isEmpty {
                    Text("暂无数据")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Helpers
    
    private func barHeight(for value: Int) -> CGFloat {
        let maxValue = analytics.weeklyStats.map { $0.totalReceived }.max() ?? 1
        let ratio = CGFloat(value) / CGFloat(max(maxValue, 1))
        return max(10, ratio * 80)
    }
    
    private func shortDate(_ dateString: String) -> String {
        let parts = dateString.split(separator: "-")
        guard parts.count == 3 else { return dateString }
        return "\(parts[1])/\(parts[2])"
    }
    
    private func colorFor(_ type: String) -> Color {
        switch type {
        case "friend": return .blue
        case "system": return .orange
        case "live": return .pink
        case "comment": return .green
        case "promotion": return .purple
        default: return .gray
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.pink)
            
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}

struct DataRow: View {
    let label: String
    let value: String
    var highlight: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: highlight ? .semibold : .regular))
                .foregroundColor(highlight ? .pink : .primary)
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}

struct TypeStatsRow: View {
    let typeName: String
    let typeColor: Color
    let received: Int
    let clicked: Int
    let recallRate: Double
    
    var body: some View {
        HStack(spacing: 12) {
            // 类型标签
            HStack(spacing: 4) {
                Circle()
                    .fill(typeColor)
                    .frame(width: 8, height: 8)
                
                Text(typeName)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
            }
            .frame(width: 80, alignment: .leading)
            
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(typeColor)
                        .frame(width: geometry.size.width * min(recallRate / 100, 1.0), height: 8)
                }
            }
            .frame(height: 8)
            
            // 召回率
            Text(String(format: "%.1f%%", recallRate))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(typeColor)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    StatsDashboardView()
}


