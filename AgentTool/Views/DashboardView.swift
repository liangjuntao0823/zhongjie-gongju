import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var stats: DashboardStats?
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var daysRemainingInMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        let range = calendar.range(of: .day, in: .month, for: now)!
        let currentDay = calendar.component(.day, from: now)
        return range.count - currentDay
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: currentTime)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 顶部标题
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("工作台")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.themeText)
                        Text("经营概览")
                            .font(.system(size: 12.5))
                            .foregroundColor(.themeText2)
                    }
                    Spacer()
                    // 通知图标
                    ZStack {
                        Circle()
                            .fill(Color.themeRed.opacity(0.1))
                            .frame(width: 38, height: 38)
                        Image(systemName: "bell.fill")
                            .foregroundColor(.themeRed)
                            .font(.system(size: 16))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // 时间卡片（渐变绿色）
                VStack(spacing: 6) {
                    Text(timeString)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .fontDesign(.rounded)
                    Text(dateString)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                    Text("本月还剩\(daysRemainingInMonth)天，加油！")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(gradient: Gradient(colors: [Color.themeAccent, Color.themeAccentDark]),
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .cornerRadius(14)
                .padding(.horizontal)

                // KPI 网格
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    KpiCard(
                        label: "在租房源",
                        value: "\(stats?.activeProperties ?? 0)",
                        unit: "套",
                        foot: "共\(stats?.totalProperties ?? 0)套",
                        style: .normal
                    )
                    KpiCard(
                        label: "本月应收",
                        value: "\(Int(stats?.monthlyRentReceivable ?? 0))",
                        unit: "元",
                        foot: "已收\(Int(stats?.monthlyRentCollected ?? 0))",
                        style: .accent
                    )
                    KpiCard(
                        label: "本月中介费",
                        value: "\(Int(stats?.monthlyDealFee ?? 0))",
                        unit: "元",
                        foot: "累计\(stats?.totalDeals ?? 0)单",
                        style: .normal
                    )
                    KpiCard(
                        label: "包租盈亏",
                        value: "\(Int(stats?.packageProfit ?? 0))",
                        unit: "元",
                        foot: (stats?.packageProfit ?? 0) >= 0 ? "盈利中" : "亏损",
                        style: (stats?.packageProfit ?? 0) >= 0 ? .normal : .alert
                    )
                    KpiCard(
                        label: "托管房源",
                        value: "\(stats?.managedProperties ?? 0)",
                        unit: "套",
                        foot: "包租+托管",
                        style: .normal
                    )
                    KpiCard(
                        label: "即将到期",
                        value: "\(stats?.expiringSoon.count ?? 0)",
                        unit: "套",
                        foot: "30天内",
                        style: (stats?.expiringSoon.count ?? 0) > 0 ? .alert : .normal
                    )
                }
                .padding(.horizontal)

                // 收租进度
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(title: "收租进度", subtitle: "本月")
                    let progress = (stats?.monthlyRentReceivable ?? 0) > 0 ? (stats?.monthlyRentCollected ?? 0) / (stats?.monthlyRentReceivable ?? 1) : 0
                    ProgressView(value: progress)
                        .tint(Color.themeAccent)
                        .scaleEffect(x: 1, y: 1.5)
                    HStack {
                        Label("已收 ¥\(Int(stats?.monthlyRentCollected ?? 0))", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.themeAccentDark)
                        Spacer()
                        Label("未收 ¥\(Int((stats?.monthlyRentReceivable ?? 0) - (stats?.monthlyRentCollected ?? 0)))", systemImage: "clock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.themeAmber)
                    }
                }
                .padding(16)
                .background(Color.themePanel)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.themeBorder, lineWidth: 1))
                .padding(.horizontal)

                // 即将到期
                if let expiring = stats?.expiringSoon, !expiring.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(title: "即将到期", subtitle: "\(expiring.count)套")
                        ForEach(expiring.prefix(3), id: \.id) { prop in
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.themeAccentWeak)
                                        .frame(width: 36, height: 36)
                                    Text(String(prop.roomNumber.prefix(2)))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.themeAccentDark)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(prop.roomNumber)
                                        .font(.system(size: 13.5, weight: .semibold))
                                        .foregroundColor(.themeText)
                                    Text("\(prop.unitType) · 房东\(prop.landlord)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.themeText3)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(prop.leaseEnd)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.themeAmber)
                                    StatusTag(text: "待续约", style: .warn)
                                }
                            }
                            .padding(.vertical, 4)
                            if prop.id != expiring.prefix(3).last?.id {
                                Divider().background(Color.themeBorder)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.themePanel)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.themeBorder, lineWidth: 1))
                    .padding(.horizontal)
                }

                // 快捷操作
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: "快捷操作")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        QuickActionItem(icon: "plus.circle.fill", label: "新增成交", color: .themeAccent)
                        QuickActionItem(icon: "creditcard.fill", label: "登记收租", color: .themeBlue)
                        QuickActionItem(icon: "arrow.up.circle.fill", label: "包租打租", color: Color(hex: "6B3FA0"))
                        QuickActionItem(icon: "bolt.fill", label: "水电结算", color: .themeAmber)
                    }
                }
                .padding(16)
                .background(Color.themePanel)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.themeBorder, lineWidth: 1))
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .background(Color.themeBg)
        .onAppear {
            stats = DataManager.shared.dashboardStats(modelContext: modelContext)
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .navigationTitle("工作台")
        .navigationBarHidden(true)
    }
}

// MARK: - KPI 卡片
struct KpiCard: View {
    let label: String
    let value: String
    let unit: String
    let foot: String
    var style: KpiStyle = .normal

    enum KpiStyle {
        case normal, accent, alert
    }

    private var dotColor: Color {
        switch style {
        case .accent: return .white
        case .alert: return .themeRed
        case .normal: return .themeAccent
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 7, height: 7)
                    .shadow(color: dotColor.opacity(0.6), radius: 4)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(style == .accent ? .white.opacity(0.9) : .themeText2)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(style == .accent ? .white : (style == .alert ? .themeRed : .themeText))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundColor(style == .accent ? .white.opacity(0.7) : .themeText3)
            }
            Text(foot)
                .font(.system(size: 11))
                .foregroundColor(style == .accent ? .white.opacity(0.7) : .themeText3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            Group {
                if style == .accent {
                    LinearGradient(gradient: Gradient(colors: [Color.themeAccent, Color.themeAccentDark]),
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                } else if style == .alert {
                    Color(hex: "FDF5F5")
                } else {
                    Color.themePanel
                }
            }
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(style == .normal ? Color.themeBorder : (style == .alert ? Color(hex: "F4D9D9") : Color.clear), lineWidth: 1)
        )
    }
}

struct QuickActionItem: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.themeText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
