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
