import SwiftUI

struct HookProgressView: View {
    var loadingMessage: String
    var hookTasks: [HookTask]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(loadingMessage)
                    .font(.headline)
                Spacer()
                AQILoaderView()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.blue)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Output List
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(hookTasks) { task in
                            HookTaskRow(task: task)
                                .id(task.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: hookTasks.count) { _ in
                    if let last = hookTasks.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: hookTasks.last?.rawOutput.count) { _ in
                    if let last = hookTasks.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(width: 450, height: 350)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }
}

struct HookTaskRow: View {
    let task: HookTask
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Image(systemName: task.status.icon)
                    .foregroundStyle(task.status.color)
                    .frame(width: 20)
                
                Text(task.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if task.status == .failed || task.status == .skipped {
                    Text(String(describing: task.status).capitalized)
                        .font(.caption2)
                        .foregroundStyle(task.status.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(task.status.color.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            if task.status == .failed && !task.rawOutput.isEmpty {
                VStack(alignment: .leading) {
                    ForEach(task.rawOutput, id: \.self) { line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 28)
                .padding(.top, 2)
            }
        }
    }
}
