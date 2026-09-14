import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var stats: DashboardStats?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 顶部标题
                    HStack {
                        Text("中介工作台")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Spacer()
                        Text("\(stats?.currentYear ?? 2026)年\(stats?.currentMonth ?? 9)月")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // 核心指标卡片
                    LazyVGrid(columns: columns, spacing: 12) {
                        StatCard(title: "在租房源", value: "\(stats?.activeProperties ?? 0)", icon: "house.fill", color: .blue, subtitle: "共\(stats?.totalProperties ?? 0)套")
                        StatCard(title: "本月应收", value: "¥\(Int(stats?.monthlyRentReceivable ?? 0))", icon: "dollarsign.circle.fill", color: .orange, subtitle: "已收¥\(Int(stats?.monthlyRentCollected ?? 0))")
                        StatCard(title: "本月中介费", value: "¥\(Int(stats?.monthlyDealFee ?? 0))", icon: "handbag.fill", color: .green, subtitle: "累计\(stats?.totalDeals ?? 0)单")
                        StatCard(title: "包租盈亏", value: "¥\(Int(stats?.packageProfit ?? 0))", icon: "chart.line.uptrend.xyaxis", color: (stats?.packageProfit ?? 0) >= 0 ? .mint : .red, subtitle: (stats?.packageProfit ?? 0) >= 0 ? "盈利中" : "亏损")
                    }
                    .padding(.horizontal)

                    // 收租进度
                    VStack(alignment: .leading, spacing: 8) {
                        Text("本月收租进度")
                            .font(.headline)
                        let progress = (stats?.monthlyRentReceivable ?? 0) > 0 ? (stats?.monthlyRentCollected ?? 0) / (stats?.monthlyRentReceivable ?? 1) : 0
                        ProgressView(value: progress)
                            .tint(.green)
                        HStack {
                            Text("已收 ¥\(Int(stats?.monthlyRentCollected ?? 0))")
                                .font(.caption)
                                .foregroundColor(.green)
                            Spacer()
                            Text("未收 ¥\(Int((stats?.monthlyRentReceivable ?? 0) - (stats?.monthlyRentCollected ?? 0)))")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // 即将到期
                    if let expiring = stats?.expiringSoon, !expiring.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("即将到期")
                                    .font(.headline)
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Spacer()
                                Text("\(expiring.count)套")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }
                            ForEach(expiring.prefix(3), id: \.id) { prop in
                                HStack {
                                    Text(prop.roomNumber)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(prop.leaseEnd)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(prop.unitType)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // 快捷入口
                    VStack(alignment: .leading, spacing: 12) {
                        Text("快捷操作")
                            .font(.headline)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            QuickActionButton(icon: "plus.circle.fill", label: "新增成交", color: .green)
                            QuickActionButton(icon: "creditcard.fill", label: "登记收租", color: .blue)
                            QuickActionButton(icon: "arrow.up.circle.fill", label: "包租打租", color: .purple)
                            QuickActionButton(icon: "bolt.fill", label: "水电结算", color: .yellow)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
            }
            .background(Color(.systemGroupedBackground))
            .onAppear {
                stats = DataManager.shared.dashboardStats(modelContext: modelContext)
            }
            .navigationTitle("首页")
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
