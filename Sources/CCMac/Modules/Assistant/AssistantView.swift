import SwiftUI

struct AssistantView: View {
    @State private var report: HealthReport = Self.generateReport()
    @State private var showInsightsPanel = false
    @State private var selectedInsight: HealthRecommendation? = nil

    static func generateReport() -> HealthReport {
        // Build real-ish health report from system data
        let diskAttrs = try? FileManager.default.attributesOfFileSystem(forPath: "/")
        let diskTotal = diskAttrs?[.systemSize] as? Int64 ?? 512_000_000_000
        let diskFree  = diskAttrs?[.systemFreeSize] as? Int64 ?? 50_000_000_000
        let diskPercent = Double(diskFree) / Double(diskTotal)
        let diskScore = Int(diskPercent * 100)

        let ramTotal = ProcessInfo.processInfo.physicalMemory
        let perfScore = ramTotal > 16_000_000_000 ? 85 : 60

        let overall = (diskScore + perfScore + 80 + 90) / 4

        return HealthReport(
            overallScore: overall,
            diskHealth: diskScore,
            securityScore: 80,
            performanceScore: perfScore,
            updatesScore: 90,
            recommendations: [
                HealthRecommendation(title: "Free up disk space",
                    description: "Your disk is \(Int((1 - diskPercent) * 100))% full. Consider removing old files.",
                    priority: diskPercent < 0.2 ? .high : .low,
                    icon: "internaldrive.fill",
                    actionLabel: "Clean Now"),
                HealthRecommendation(title: "Run malware scan",
                    description: "No scan has been performed recently. Keep your Mac protected.",
                    priority: .medium,
                    icon: "shield.fill",
                    actionLabel: "Scan Now"),
                HealthRecommendation(title: "Flush DNS Cache",
                    description: "Clearing DNS cache can fix network issues and speed up browsing.",
                    priority: .low,
                    icon: "network",
                    actionLabel: "Flush Now"),
            ]
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderView(
                module: .assistant,
                subtitle: "Personalized Mac health insights powered by AI"
            )

            HStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: AppSpacing.section) {
                        // Health Score Ring
                        VStack(spacing: AppSpacing.compact) {
                            HealthScoreRing(score: report.overallScore)
                                .shadow(color: report.labelColor.opacity(0.25), radius: 25)
                            Text("Your Mac's Health")
                                .font(AppFont.heading2).foregroundColor(.textSecondary)
                        }
                        .padding(.top, AppSpacing.section)

                        // Category score cards
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.compact) {
                            HealthCategoryCard(title: "Disk Health", score: report.diskHealth, icon: "internaldrive.fill", color: .infoBlue)
                            HealthCategoryCard(title: "Security", score: report.securityScore, icon: "shield.fill", color: .successGreen)
                            HealthCategoryCard(title: "Performance", score: report.performanceScore, icon: "bolt.fill", color: .warningOrange)
                            HealthCategoryCard(title: "Updates", score: report.updatesScore, icon: "arrow.clockwise", color: .brandGreen)
                        }
                        .padding(.horizontal, AppSpacing.section)

                        // Recommendations
                        SectionHeader(title: "Recommendations", trailing: "\(report.recommendations.count) items")
                        VStack(spacing: AppSpacing.compact) {
                            ForEach(report.recommendations) { rec in
                                RecommendationCard(rec: rec) {
                                    selectedInsight = rec
                                    withAnimation(.easeOut(duration: 0.28)) { showInsightsPanel = true }
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.section)
                        .padding(.bottom, AppSpacing.section)
                    }
                }
                .frame(maxWidth: .infinity)

                // Smart Insights Panel
                if showInsightsPanel, let insight = selectedInsight {
                    Divider().overlay(Color.white.opacity(0.06))
                    SmartInsightsPanel(insight: insight) {
                        withAnimation { showInsightsPanel = false }
                    }
                    .transition(.move(edge: .trailing))
                }
            }
        }
        .background(Color.bgDark)
    }
}

struct HealthCategoryCard: View {
    let title: String; let score: Int; let icon: String; let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            HStack {
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(color)
                Text(title).font(AppFont.heading3).foregroundColor(.textPrimary)
                Spacer()
                Text("\(score)").font(AppFont.heading2).foregroundColor(color).monospacedDigit()
            }
            CMProgressBar(progress: Double(score) / 100.0, showLabel: false)
        }
        .padding(AppSpacing.standard)
        .background(Color.surfaceDark)
        .cornerRadius(AppRadius.medium)
    }
}

struct RecommendationCard: View {
    let rec: HealthRecommendation
    var onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: AppSpacing.standard) {
            Image(systemName: rec.icon)
                .font(.system(size: 20)).foregroundColor(rec.priority.color)
                .frame(width: 36, height: 36)
                .background(rec.priority.color.opacity(0.12))
                .cornerRadius(AppRadius.small)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(rec.title).font(AppFont.heading3).foregroundColor(.textPrimary)
                    Text(rec.priority.rawValue.uppercased())
                        .font(AppFont.labelBadge).foregroundColor(rec.priority.color)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(rec.priority.color.opacity(0.12)).cornerRadius(AppRadius.small)
                }
                Text(rec.description).font(AppFont.bodyDefault).foregroundColor(.textSecondary).lineLimit(2)
            }
            Spacer()
            CMButton(rec.actionLabel, style: .secondary) { onTap() }
            Button("Dismiss") {}.buttonStyle(.plain).font(AppFont.bodySmall).foregroundColor(.textDisabled)
        }
        .padding(AppSpacing.standard)
        .background(isHovered ? Color.surfaceDarkHover : Color.surfaceDark)
        .cornerRadius(AppRadius.medium)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

struct SmartInsightsPanel: View {
    let insight: HealthRecommendation
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.standard) {
            // Apple Intelligence badge header
            HStack {
                Image(systemName: "brain").font(.system(size: 14)).foregroundColor(.assistantPurple)
                Text("Smart Insights").font(AppFont.labelBadge).foregroundColor(.assistantPurple)
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark").foregroundColor(.textDisabled) }.buttonStyle(.plain)
            }
            .padding(.bottom, AppSpacing.compact)

            Image(systemName: insight.icon).font(.system(size: 36)).foregroundColor(insight.priority.color)
            Text(insight.title).font(AppFont.heading2).foregroundColor(.textPrimary)

            Divider().overlay(Color.white.opacity(0.06))

            Text(insight.description).font(AppFont.bodyLarge).foregroundColor(.textSecondary)

            // Safe to action badge
            HStack {
                Image(systemName: insight.priority == .high ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                    .foregroundColor(insight.priority.color)
                Text(insight.priority == .high ? "Attention needed" : "Safe to fix automatically")
                    .font(AppFont.bodyDefault).foregroundColor(insight.priority.color)
            }
            .padding(AppSpacing.compact)
            .background(insight.priority.color.opacity(0.1))
            .cornerRadius(AppRadius.small)

            Spacer()

            CMButton(insight.actionLabel) {}
            CMButton("Add to Ignore List", style: .secondary) { onClose() }
        }
        .padding(AppSpacing.standard)
        .frame(width: 300)
        .background(Color.bgDark2)
    }
}
