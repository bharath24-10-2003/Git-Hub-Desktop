import SwiftUI

struct GitCommandLogView: View {
    @Bindable var viewModel: GitCommandLogViewModel
    @Binding var isPresented: Bool
    
    @State private var selectedTab: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(viewModel.title)
                    .font(.headline)
                
                if viewModel.isRunning {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, 8)
                }
                
                Spacer()
                
                Picker("", selection: $selectedTab) {
                    Text("Rich Log").tag(0)
                    Text("Raw Output").tag(1)
                }
                .pickerStyle(.radioGroup)
                .frame(width: 200)
                
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
            
            Divider()
            
            if selectedTab == 0 {
                richLogView
            } else {
                rawLogView
            }
            
            if viewModel.hasFailed {
                Divider()
                HStack {
                    Spacer()
                    Button("Done") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding()
                }
                .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(.regularMaterial)
    }
    
    // MARK: - Rich Log View
    
    private var richLogView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    let grouped = groupedEntries()
                    ForEach(0..<grouped.count, id: \.self) { sectionIndex in
                        let section = grouped[sectionIndex]
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.0)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(section.1) { entry in
                                    LogEntryCell(entry: entry)
                                        .id(entry.id)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .onChange(of: viewModel.entries) { _, newEntries in
                // Auto-scroll to bottom on new entries
                if let lastId = newEntries.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Raw Log View
    
    private var rawLogView: some View {
        ScrollView {
            Text(viewModel.rawLogText)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .textSelection(.enabled)
        }
        .background(Color(NSColor.textBackgroundColor))
    }
    
    // MARK: - Helpers
    
    private func groupedEntries() -> [(String, [GitLogEntry])] {
        var groups: [(String, [GitLogEntry])] = []
        for entry in viewModel.entries {
            let groupName = entry.groupName
            if let last = groups.last, last.0 == groupName {
                groups[groups.count - 1].1.append(entry)
            } else {
                groups.append((groupName, [entry]))
            }
        }
        return groups
    }
}

// MARK: - Cell View

struct LogEntryCell: View {
    let entry: GitLogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 24, alignment: .center)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.message)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                if let progress = entry.progress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                        .frame(maxWidth: 300)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    private var iconName: String {
        switch entry.kind {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .preCommitCheck: return entry.message.contains("Passed") ? "checkmark.circle.fill" : "xmark.circle.fill"
        case .preCommitRunning: return "arrow.triangle.2.circlepath"
        case .remote: return "cloud.fill"
        case .gitProgress:
            if entry.message.lowercased().contains("counting") { return "shippingbox.fill" }
            if entry.message.lowercased().contains("compressing") { return "archivebox.fill" }
            if entry.message.lowercased().contains("writing") { return "arrow.up.doc.fill" }
            return "arrow.triangle.2.circlepath"
        case .normal: return "terminal.fill"
        }
    }
    
    private var iconColor: Color {
        switch entry.kind {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        case .preCommitCheck: return entry.message.contains("Passed") ? .green : .red
        case .preCommitRunning: return .blue
        case .remote: return .cyan
        case .gitProgress: return .blue
        case .normal: return .secondary
        }
    }
}

// MARK: - Extensions

extension GitLogEntry {
    var groupName: String {
        switch kind {
        case .preCommitCheck, .preCommitRunning: return "Pre-commit Hooks"
        case .gitProgress, .remote: return "Git Operations"
        case .success: return "Completed"
        default: return "General Logs"
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var mockViewModel = GitCommandLogViewModel()
        
        var body: some View {
            GitCommandLogView(viewModel: mockViewModel, isPresented: .constant(true))
                .onAppear {
                    mockViewModel.title = "Pushing commits..."
                    mockViewModel.isRunning = true
                    
                    let sampleLog = """
                    [WARNING] Unstaged files detected.
                    [INFO] Stashing unstaged files to /Users/bharath/.cache/pre-commit/patch1783427837-51760.
                    Pre-push clean build.....................................................Passed
                    Pre-push SwiftLint analyze...............................................Passed
                    Pre-push xcodebuild test.................................................Passed
                    [INFO] Restored changes from /Users/bharath/.cache/pre-commit/patch1783427837-51760.
                    Enumerating objects: 67, done.
                    Counting objects: 100% (67/67), done.
                    Delta compression using up to 10 threads
                    Compressing objects: 100% (41/41), done.
                    Writing objects: 100% (43/43), 6.77 KiB | 6.77 MiB/s, done.
                    Total 43 (delta 24), reused 0 (delta 0), pack-reused 0 (from 0)
                    remote: Resolving deltas: 100% (24/24), completed with 21 local objects.
                    To github.com:cnbc/tvOS-Beacon.git
                       e6a7ba88..366cd478  bugfix/VOTA-2252-datadog-long-task-issues -> bugfix/VOTA-2252-datadog-long-task-issues
                    """
                    
                    mockViewModel.parseAndAppend(sampleLog)
                }
        }
    }
    
    return PreviewWrapper()
}
