import SwiftUI

// MARK: - App Sidebar Navigation (220px wide, dark background)
struct SidebarView: View {
    @Binding var selectedModule: AppModule

    var body: some View {
        VStack(spacing: 0) {
            // App Logo + Name
            HStack(spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.brandGreen)
                Text("CCMac")
                    .font(AppFont.heading3)
                    .foregroundColor(.textPrimary)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.section)
            .padding(.vertical, AppSpacing.standard)
            .background(Color.bgDark2)

            Divider().overlay(Color.brandBlue.opacity(0.3))

            // Navigation Items
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(AppModule.allCases) { module in
                        SidebarItem(module: module, isActive: selectedModule == module)
                            .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { selectedModule = module } }
                    }
                }
                .padding(.vertical, AppSpacing.base)
            }

            Spacer()

            Divider().overlay(Color.white.opacity(0.08))

            // Bottom Bar: User + Settings
            HStack(spacing: AppSpacing.base) {
                Circle()
                    .fill(LinearGradient.brandGradient)
                    .frame(width: 28, height: 28)
                    .overlay(Text("K").font(AppFont.labelBadge).foregroundColor(.white))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Plus Plan").font(AppFont.bodySmall).foregroundColor(.textPrimary)
                    Text("Active").font(AppFont.labelBadge).foregroundColor(.successGreen)
                }
                Spacer()
                Button(action: {}) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.section)
            .padding(.vertical, AppSpacing.compact)
        }
        .frame(width: 220)
        .background(Color.bgDark2)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.brandBlue)
                .frame(width: 1)
        }
    }
}

// MARK: - Individual Sidebar Item
struct SidebarItem: View {
    let module: AppModule
    let isActive: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Active indicator (left border)
            Rectangle()
                .fill(isActive ? Color.brandGreen : Color.clear)
                .frame(width: 3)
                .cornerRadius(1.5)

            Image(systemName: module.icon)
                .font(.system(size: 16))
                .foregroundColor(isActive ? .brandGreen : (isHovered ? .textPrimary : .textSecondary))
                .frame(width: 20, height: 20)

            Text(module.rawValue)
                .font(AppFont.bodyDefault)
                .foregroundColor(isActive ? .textPrimary : (isHovered ? .textPrimary : .textSecondary))

            Spacer()
        }
        .frame(height: 38)
        .background(isActive ? Color.brandBlue.opacity(0.12) : (isHovered ? Color.white.opacity(0.05) : Color.clear))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.1), value: isHovered)
    }
}
