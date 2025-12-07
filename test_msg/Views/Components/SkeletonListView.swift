//
//  SkeletonListView.swift
//  test_msg
//
//  骨架屏加载视图 - 占位UI
//

import SwiftUI

/// 骨架屏单元格
struct SkeletonCellView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 头像骨架
            Circle()
                .fill(shimmerGradient)
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 8) {
                // 昵称骨架
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(shimmerGradient)
                        .frame(width: 80, height: 14)
                    
                    Spacer()
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(shimmerGradient)
                        .frame(width: 40, height: 12)
                }
                
                // 消息内容骨架
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(height: 12)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
    
    private var shimmerGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.gray.opacity(isAnimating ? 0.3 : 0.1),
                Color.gray.opacity(isAnimating ? 0.1 : 0.3),
                Color.gray.opacity(isAnimating ? 0.3 : 0.1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

/// 骨架屏列表
struct SkeletonListView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<10, id: \.self) { index in
                    VStack(spacing: 0) {
                        SkeletonCellView()
                        
                        Divider()
                            .padding(.leading, 78)
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .scrollDisabled(true)
    }
}

// MARK: - Preview

#Preview {
    SkeletonListView()
        .background(Color(.systemGroupedBackground))
}


