import SwiftUI

// MARK: - 主题配色（参考房源管理软件深绿色主题）
extension Color {
    static let themeSidebar = Color(hex: "143B34")
    static let themeSidebarDark = Color(hex: "0E2B26")
    static let themeAccent = Color(hex: "0FA48B")
    static let themeAccentDark = Color(hex: "0B7A66")
    static let themeAccentWeak = Color(hex: "E2F4EF")
    static let themeBg = Color(hex: "F4F6F3")
    static let themePanel = Color.white
    static let themeText = Color(hex: "1C2D29")
    static let themeText2 = Color(hex: "5F716C")
    static let themeText3 = Color(hex: "97A49F")
    static let themeBorder = Color(hex: "E3EAE6")
    static let themeBlue = Color(hex: "3E7BFA")
    static let themeAmber = Color(hex: "E09A2F")
    static let themeRed = Color(hex: "DF5555")
}

// 让 Color? 也能使用 .themeXxx 静态成员（foregroundColor 等接受 Color? 的 API）
extension Optional where Wrapped == Color {
    static var themeSidebar: Color? { Color.themeSidebar }
    static var themeSidebarDark: Color? { Color.themeSidebarDark }
    static var themeAccent: Color? { Color.themeAccent }
    static var themeAccentDark: Color? { Color.themeAccentDark }
    static var themeAccentWeak: Color? { Color.themeAccentWeak }
    static var themeBg: Color? { Color.themeBg }
    static var themePanel: Color? { Color.themePanel }
    static var themeText: Color? { Color.themeText }
    static var themeText2: Color? { Color.themeText2 }
    static var themeText3: Color? { Color.themeText3 }
    static var themeBorder: Color? { Color.themeBorder }
    static var themeBlue: Color? { Color.themeBlue }
    static var themeAmber: Color? { Color.themeAmber }
    static var themeRed: Color? { Color.themeRed }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - 通用组件
struct GlowDot: View {
    var color: Color = .themeAccent
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.6), radius: 6)
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String = ""

    var body: some View {
        HStack(spacing: 8) {
            GlowDot()
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.themeText)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.themeText3)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

struct StatusTag: View {
    let text: String
    var style: TagStyle = .renting

    enum TagStyle {
        case renting, vacant, repair, paid, unpaid, ok, expired, warn, managed

        var bgColor: Color {
            switch self {
            case .renting, .paid, .ok: return Color.themeAccentWeak
            case .vacant: return Color(hex: "E8EFFE")
            case .repair, .warn: return Color(hex: "FBF1DE")
            case .unpaid: return Color(hex: "FDF0F0")
            case .expired: return Color(hex: "F0F2F1")
            case .managed: return Color(hex: "F0E8FE")
            }
        }

        var textColor: Color {
            switch self {
            case .renting, .paid, .ok: return Color.themeAccentDark
            case .vacant: return Color(hex: "2F5FD0")
            case .repair, .warn: return Color(hex: "B97A1B")
            case .unpaid: return Color.themeRed
            case .expired: return Color.themeText2
            case .managed: return Color(hex: "6B3FA0")
            }
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(style.textColor)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(style.bgColor)
        .foregroundColor(style.textColor)
        .clipShape(Capsule())
    }
}

struct ThemeCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(Color.themePanel)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.themeBorder, lineWidth: 1)
            )
            .shadow(color: Color.themeSidebar.opacity(0.05), radius: 2, x: 0, y: 1)
            .shadow(color: Color.themeSidebar.opacity(0.07), radius: 14, x: 0, y: 5)
    }
}

struct PrimaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Color.themeAccent)
            .cornerRadius(10)
            .shadow(color: Color.themeAccent.opacity(0.3), radius: 6, x: 0, y: 2)
        }
    }
}

struct GhostButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
            }
            .foregroundColor(.themeText)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Color.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.themeBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - 轮盘式日期选择器
struct WheelDateField: View {
    let label: String
    @Binding var date: Date
    @State private var showPicker = false

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.themeText2)
            Button {
                showPicker = true
            } label: {
                HStack {
                    Text(dateString)
                        .font(.system(size: 15))
                        .foregroundColor(.themeText)
                    Spacer()
                    Image(systemName: "calendar")
                        .foregroundColor(.themeText3)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(Color.themeBg)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.themeBorder, lineWidth: 1))
            }
        }
        .sheet(isPresented: $showPicker) {
            WheelDatePickerSheet(date: $date, isPresented: $showPicker)
        }
    }
}

struct WheelDatePickerSheet: View {
    @Binding var date: Date
    @Binding var isPresented: Bool
    @State private var tempDate: Date

    init(date: Binding<Date>, isPresented: Binding<Bool>) {
        _date = date
        _isPresented = isPresented
        _tempDate = State(initialValue: date.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("", selection: $tempDate, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.themeBg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { isPresented = false }
                        .foregroundColor(.themeText2)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        date = tempDate
                        isPresented = false
                    }
                    .foregroundColor(.themeAccent)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - 轮盘式年月选择器（用于筛选）
struct WheelYearMonthPicker: View {
    @Binding var year: Int?
    @Binding var month: Int?
    @State private var showPicker = false
    @State private var tempYear: Int = Calendar.current.component(.year, from: Date())
    @State private var tempMonth: Int = Calendar.current.component(.month, from: Date())

    private let years = Array(2024...2035)
    private let months = Array(1...12)

    private var displayText: String {
        if year == nil && month == nil { return "全部时间" }
        if let y = year, let m = month { return "\(y)年\(m)月" }
        if let y = year { return "\(y)年" }
        if let m = month { return "\(m)月" }
        return "全部时间"
    }

    var body: some View {
        Button {
            tempYear = year ?? Calendar.current.component(.year, from: Date())
            tempMonth = month ?? Calendar.current.component(.month, from: Date())
            showPicker = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                Text(displayText)
                    .font(.system(size: 13, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .foregroundColor(.themeAccent)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.themeAccentWeak)
            .cornerRadius(8)
        }
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Picker("年份", selection: $tempYear) {
                            Text("全部年").tag(0)
                            ForEach(years, id: \.self) { y in
                                Text("\(y)年").tag(y)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)

                        Picker("月份", selection: $tempMonth) {
                            Text("全部月").tag(0)
                            ForEach(months, id: \.self) { m in
                                Text("\(m)月").tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)

                    Spacer()
                }
                .background(Color.themeBg)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") { showPicker = false }
                            .foregroundColor(.themeText2)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("确定") {
                            year = tempYear == 0 ? nil : tempYear
                            month = tempMonth == 0 ? nil : tempMonth
                            showPicker = false
                        }
                        .foregroundColor(.themeAccent)
                        .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.height(360)])
        }
    }
}

// MARK: - HTML Excel 生成（解决CSV保存后格式乱问题）
func makeExcelHTML(title: String, headers: [String], rows: [[String]]) -> String {
    var html = """
    <html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns="http://www.w3.org/TR/REC-html40">
    <head>
    <meta charset="UTF-8">
    <style>
    table { border-collapse: collapse; }
    td, th { border: 1px solid #999; padding: 4px 8px; font-family: Arial; font-size: 12px; mso-number-format:'\\@'; white-space: nowrap; }
    th { background-color: #143B34; color: white; font-weight: bold; }
    tr:nth-child(even) td { background-color: #F5F7F5; }
    </style>
    </head>
    <body>
    <table>
    """
    html += "<tr>" + headers.map { "<th>\($0)</th>" }.joined() + "</tr>\n"
    for row in rows {
        html += "<tr>" + row.map { "<td>\($0)</td>" }.joined() + "</tr>\n"
    }
    html += "</table></body></html>"
    return html
}
