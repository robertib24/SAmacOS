#if os(macOS)
import AppKit
import RunnerCore
import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var model: LauncherModel
    @State private var running = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Diagnostics").font(.largeTitle.bold())
                Spacer()
                if running { ProgressView().controlSize(.small) }
                Button("Run Again") { Task { await run() } }.disabled(running)
                Button("Copy Report") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(Doctor.render(model.checks), forType: .string)
                }
                .disabled(model.checks.isEmpty)
            }
            .padding(24)

            List(model.checks) { check in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: icon(check.level))
                        .foregroundStyle(color(check.level))
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(check.title)
                        if let detail = check.detail {
                            Text(detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .task { await run() }
    }

    private func run() async {
        running = true
        await model.runDiagnostics()
        running = false
    }

    private func icon(_ level: DiagnosticCheck.Level) -> String {
        switch level {
        case .ok: return "checkmark.circle.fill"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    private func color(_ level: DiagnosticCheck.Level) -> Color {
        switch level {
        case .ok: return .green
        case .info: return .secondary
        case .warning: return .orange
        case .error: return .red
        }
    }
}
#endif
