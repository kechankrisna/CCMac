import SwiftUI

// MARK: - Module Header (full width, 80px)
struct ModuleHeaderView: View {
    let module: AppModule
    let subtitle: String
    let actionLabel: String
    var isScanning: Bool = false
    var onAction: () -> Void
    var onSettings: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: AppSpacing.compact) {
            Image(systemName: module.icon)
                .font(.system(size: 28))
                .foregroundColor(module.accentColor)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(module.rawValue).font(AppFont.heading1).foregroundColor(.textPrimary)
                Text(subtitle).font(AppFont.bodyDefault).foregroundColor(.textSecondary)
            }
            Spacer()
            if let settings = onSettings {
                Button(action: settings) {
                    Image(systemName: "gearshape").font(.system(size: 16)).foregroundColor(.textSecondary)
                }
                .buttonStyle(.plain)
            }
            CMButton(isScanning ? "Scanning…" : actionLabel, icon: isScanning ? "arrow.triangle.2.circlepath" : nil) {
                if !isScanning { onAction() }
            }
            .disabled(isScanning)
        }
        .padding(.horizontal, AppSpacing.section)
        .frame(height: 80)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.brandBlue.opacity(0.18)).frame(height: 1)
        }
    }
}

// MARK: - Primary Button (Green CTA)
struct CMButton: View {
    let title: String
    let icon: String?
    var style: ButtonStyle2 = .primary
    var isDestructive: Bool = false
    var action: () -> Void

    enum ButtonStyle2 { case primary, secondary }

    @State private var isHovered = false
    @State private var isPressed = false

    init(_ title: String, icon: String? = nil, style: ButtonStyle2 = .primary, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.style = style
        self.isDestructive = isDestructive; self.action = action
    }

    var bgColor: Color {
        if isDestructive { return isHovered ? Color(hex: "#F06262") : .dangerRed }
        if style == .secondary { return isHovered ? Color.brandBlue.opacity(0.10) : Color.clear }
        return isHovered ? Color(hex: "#35B57A") : .brandGreen
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 13)) }
                Text(title).font(AppFont.heading3)
            }
            .foregroundColor(style == .secondary ? .infoBlue : .white)
            .padding(.horizontal, style == .secondary ? 20 : 24)
            .frame(height: 40)
            .background(bgColor)
            .cornerRadius(AppRadius.medium)
            .overlay(
                style == .secondary
                    ? RoundedRectangle(cornerRadius: AppRadius.medium).stroke(Color.brandBlue, lineWidth: 1)
                    : nil
            )
            .shadow(color: isDestructive ? Color.dangerRed.opacity(0.25) : (style == .primary ? Color.brandGreen.opacity(0.25) : .clear),
                    radius: isHovered ? 8 : 0, x: 0, y: 0)
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in isPressed = true }.onEnded { _ in isPressed = false })
        .animation(.easeOut(duration: 0.1), value: isHovered)
        .animation(.easeOut(duration: 0.08), value: isPressed)
    }
}

// MARK: - Circular Progress Ring
struct CircularProgressView: View {
    var progress: Double  // 0-1
    var size: CGFloat = 160
    var lineWidth: CGFloat = 8
    var centerContent: AnyView? = nil

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: lineWidth)
            // Progress ring
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(LinearGradient.brandGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.0), value: progress)
            // Center
            if let content = centerContent { content }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Progress Bar
struct CMProgressBar: View {
    var progress: Double  // 0-1
    var isError: Bool = false
    var showLabel: Bool = true

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if showLabel {
                Text("\(Int(progress * 100))%")
                    .font(AppFont.bodySmall)
                    .foregroundColor(.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isError ? AnyShapeStyle(Color.dangerRed) : AnyShapeStyle(LinearGradient.brandGradient))
                        .frame(width: geo.size.width * CGFloat(min(progress, 1.0)), height: 6)
                        .animation(.easeOut(duration: 0.4), value: progress)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Threat / Status Badge
struct ThreatBadge: View {
    let severity: ThreatItem.ThreatSeverity

    var body: some View {
        Text(severity.rawValue.uppercased())
            .font(AppFont.labelBadge)
            .foregroundColor(severity.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(severity.bgColor)
            .cornerRadius(AppRadius.small)
            .overlay(RoundedRectangle(cornerRadius: AppRadius.small).stroke(severity.borderColor, lineWidth: 1))
    }
}

// MARK: - Metric Widget (Menu Bar style)
struct MetricWidget: View {
    let title: String
    let value: String
    let icon: String
    let accent: Color
    var history: [Double] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).font(.system(size: 12)).foregroundColor(accent)
                Text(title).font(AppFont.bodySmall).foregroundColor(.textSecondary)
                Spacer()
            }
            Text(value).font(AppFont.heading2).foregroundColor(.textPrimary)
            // Mini sparkline
            if !history.isEmpty {
                SparklineView(data: history, color: accent).frame(height: 30)
            }
        }
        .padding(AppSpacing.compact)
        .frame(width: 160, height: 100)
        .background(Color.surfaceDark)
        .cornerRadius(AppRadius.medium)
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Sparkline Chart
struct SparklineView: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let maxVal = data.max() ?? 1
            let points = data.enumerated().map { i, v -> CGPoint in
                let x = geo.size.width * CGFloat(i) / CGFloat(Swift.max(data.count - 1, 1))
                let y = geo.size.height * (1 - CGFloat(v) / CGFloat(maxVal > 0 ? maxVal : 1))
                return CGPoint(x: x, y: y)
            }
            if points.count > 1 {
                Path { path in
                    path.move(to: points[0])
                    for p in points.dropFirst() { path.addLine(to: p) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

// MARK: - File List Row
struct FileListRow: View {
    var file: FileItem
    @Binding var isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $isSelected).toggleStyle(.checkbox).labelsHidden()
            Image(systemName: fileIcon(for: file.name))
                .font(.system(size: 16)).foregroundColor(.textSecondary).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name).font(AppFont.bodyLarge).foregroundColor(.textPrimary).lineLimit(1)
                Text(file.path).font(AppFont.mono).foregroundColor(.textDisabled).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text(file.sizeString).font(AppFont.bodyDefault).foregroundColor(.brandBlue).monospacedDigit()
        }
        .padding(.horizontal, AppSpacing.standard)
        .frame(height: 48)
        .background(
            isSelected
                ? Color.brandGreen.opacity(0.04)
                : (isHovered ? Color.white.opacity(0.04) : Color.clear)
        )
        .overlay(alignment: .leading) {
            if isSelected { Rectangle().fill(Color.brandGreen).frame(width: 3) }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private func fileIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "gif", "heic": return "photo"
        case "mp4", "mov", "mkv": return "film"
        case "mp3", "m4a", "wav": return "music.note"
        case "pdf": return "doc.richtext"
        case "zip", "tar", "gz": return "archivebox"
        case "log": return "doc.text"
        case "app": return "app.badge"
        default: return "doc"
        }
    }
}

// MARK: - Scan Result Card
struct ScanResultCard: View {
    var category: ScanCategory
    @Binding var isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            HStack {
                Image(systemName: category.icon).font(.system(size: 20)).foregroundColor(category.color)
                Text(category.name).font(AppFont.heading3).foregroundColor(.textPrimary)
                Spacer()
                Toggle("", isOn: $isSelected).toggleStyle(.checkbox).labelsHidden()
            }
            Text("\(category.files.count) items").font(AppFont.bodySmall).foregroundColor(.textSecondary)
            Spacer()
            HStack {
                // File path previews
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(category.files.prefix(3)) { f in
                        Text(f.name).font(AppFont.mono).foregroundColor(.textDisabled).lineLimit(1)
                    }
                }
                Spacer()
                Text(category.totalSizeString).font(AppFont.heading2).foregroundColor(.brandGreen).monospacedDigit()
            }
        }
        .padding(AppSpacing.standard)
        .frame(height: 130)
        .background(Color.surfaceDark)
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(isSelected ? Color.brandGreen.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
        .shadow(color: isHovered ? Color.black.opacity(0.4) : Color.black.opacity(0.25), radius: isHovered ? 16 : 8, x: 0, y: isHovered ? 6 : 4)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Health Score Ring with label
struct HealthScoreRing: View {
    let score: Int

    var color: Color {
        switch score {
        case 80...100: return .successGreen
        case 60..<80:  return .brandGreen
        case 40..<60:  return .warningOrange
        default:       return .dangerRed
        }
    }

    var label: String {
        switch score {
        case 80...100: return "Excellent"
        case 60..<80:  return "Good"
        case 40..<60:  return "Needs Attention"
        default:       return "Critical"
        }
    }

    var body: some View {
        CircularProgressView(
            progress: Double(score) / 100.0,
            size: 160,
            centerContent: AnyView(
                VStack(spacing: 4) {
                    Text("\(score)").font(AppFont.numberHero).foregroundColor(.textPrimary)
                    Text(label).font(AppFont.bodySmall).foregroundColor(color)
                }
            )
        )
    }
}

// MARK: - Empty State Placeholder
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: AppSpacing.standard) {
            Image(systemName: icon)
                .font(.system(size: 48)).foregroundColor(.textDisabled)
            Text(title).font(AppFont.heading2).foregroundColor(.textSecondary)
            Text(subtitle).font(AppFont.bodyDefault).foregroundColor(.textDisabled).multilineTextAlignment(.center)
        }
        .padding(AppSpacing.hero)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title).font(AppFont.heading3).foregroundColor(.textSecondary)
            Spacer()
            if let t = trailing { Text(t).font(AppFont.bodySmall).foregroundColor(.textDisabled) }
        }
        .padding(.horizontal, AppSpacing.section)
        .padding(.top, AppSpacing.standard)
        .padding(.bottom, AppSpacing.base)
    }
}
