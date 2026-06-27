import SwiftUI

struct GitErrorDialog: View {
    let error: GitAnalyzedError
    let onAction: (GitRecoveryAction) -> Void
    
    @State private var showRawOutput = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 16) {
                Image(systemName: error.type.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(error.type.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(error.title)
                        .appFont(.title3, weight: .bold)
                    Text(error.description)
                        .appFont(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.bottom, 8)
            
            // Details (Reason & Fix)
            VStack(alignment: .leading, spacing: 12) {
                if let reason = error.reason {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reason")
                            .appFont(.caption, weight: .semibold)
                            .foregroundStyle(.secondary)
                        Text(reason)
                            .appFont(.body)
                    }
                }
                
                if let suggestedFix = error.suggestedFix {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Suggested Fix")
                            .appFont(.caption, weight: .semibold)
                            .foregroundStyle(.secondary)
                        Text(suggestedFix)
                            .appFont(.body)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // Raw Output Toggle
            DisclosureGroup(isExpanded: $showRawOutput) {
                ScrollView {
                    Text(error.rawOutput)
                        .appFont(.caption, design: .monospaced)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 150)
                .background(Color.black.opacity(0.8))
                .foregroundColor(.green)
                .cornerRadius(6)
            } label: {
                Text("Show Raw Git Output")
                    .appFont(.subheadline, weight: .medium)
            }
            
            // Actions
            HStack(spacing: 12) {
                Spacer()
                
                if let secondary = error.secondaryAction {
                    Button(role: secondary.isDestructive ? .destructive : .cancel) {
                        onAction(secondary)
                    } label: {
                        Text(secondary.title)
                            .frame(minWidth: 80)
                    }
                    .keyboardShortcut(.cancelAction)
                } else {
                    Button("Cancel", role: .cancel) {
                        onAction(.dismiss)
                    }
                    .keyboardShortcut(.cancelAction)
                }
                
                if let primary = error.primaryAction {
                    Button(role: primary.isDestructive ? .destructive : nil) {
                        onAction(primary)
                    } label: {
                        Text(primary.title)
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(primary.isDestructive ? .red : .blue)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}
