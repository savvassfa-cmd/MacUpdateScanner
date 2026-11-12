import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: ScannerModel

    var body: some View {
        VStack(spacing: 0) {
            header
            summary
            toolbar
            Divider()
            if model.apps.isEmpty && !model.isScanning {
                emptyState
            } else {
                appList
            }
            footer
        }
        .background(Color(NSColor.windowBackgroundColor))
        .alert(item: Binding(get: { model.alertMessage.map(AlertText.init) }, set: { _ in model.alertMessage = nil })) { item in
            Alert(title: Text("MacUpdate Scanner"), message: Text(item.message), dismissButton: .default(Text("OK")))
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 30)).foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("MacUpdate Scanner").font(.system(size: 22, weight: .semibold))
                Text("Application update discovery for macOS Monterey").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Button(action: model.scan) {
                Label(model.isScanning ? "Scanning…" : "Scan for Updates", systemImage: "arrow.clockwise")
                    .padding(.horizontal, 8).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isScanning)
        }
        .padding(20)
    }

    private var summary: some View {
        HStack(spacing: 12) {
            SummaryTile(title: "Applications", value: "\(model.apps.count)", icon: "square.grid.2x2", tint: .blue)
            SummaryTile(title: "Updates", value: "\(model.updateCount)", icon: "arrow.down.circle", tint: .orange)
            SummaryTile(title: "Up to date", value: "\(model.upToDateCount)", icon: "checkmark.circle", tint: .green)
            SummaryTile(title: "Unverified", value: "\(model.unverifiedCount)", icon: "questionmark.circle", tint: .secondary)
        }
        .padding(.horizontal, 20).padding(.bottom, 16)
    }

    private var toolbar: some View {
        HStack {
            Picker("Filter", selection: $model.selectedFilter) {
                Text("All").tag("All")
                Text("Updates").tag("Updates")
                Text("Up to date").tag("Up to date")
                Text("Unverified").tag("Unverified")
            }
            .frame(width: 150)
            .labelsHidden()
            TextField("Search applications", text: $model.searchText)
                .textFieldStyle(.roundedBorder).frame(maxWidth: 260)
            Spacer()
            if let date = model.lastScan {
                Text("Last scan: \(date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
    }

    private var appList: some View {
        List(model.visibleApps) { app in
            AppRow(app: app, install: { model.install(app) }, reveal: { model.reveal(app) })
                .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
        }
        .listStyle(.inset)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "macwindow.on.rectangle").font(.system(size: 48)).foregroundColor(.secondary)
            Text("Ready to scan your Mac").font(.title2.weight(.semibold))
            Text("The scanner checks application bundles on the startup disk and mounted volumes, then compares versions against sources it can verify.")
                .font(.callout).foregroundColor(.secondary).multilineTextAlignment(.center).frame(maxWidth: 480)
            Button("Start Scan", action: model.scan).buttonStyle(.borderedProminent).padding(.top, 6)
            Spacer()
        }
        .padding(30)
    }

    private var footer: some View {
        HStack {
            if model.isScanning { ProgressView().controlSize(.small) }
            Text(model.statusMessage).font(.caption).foregroundColor(.secondary)
            Spacer()
            Text("Intel · macOS 12+").font(.caption2)..foregroundColor(Color.secondary)
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

private struct SummaryTile: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.title2).foregroundColor(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.title2.weight(.semibold)).monospacedDigit()
                Text(title).font(.caption).foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor)).cornerRadius(10)
    }
}

private struct AppRow: View {
    let app: AppRecord
    let install: () -> Void
    let reveal: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path.path))
                .resizable().frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(app.name).font(.system(size: 13, weight: .semibold))
                    statusBadge
                }
                Text("Installed: \(app.installedVersion)" + (app.latestVersion.map { "  ·  Latest: \($0)" } ?? ""))
                    .font(.caption).foregroundColor(.secondary)
                Text(app.details).font(.caption2).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if app.canInstall {
                Button("Install / Open") { install() }.buttonStyle(.bordered).controlSize(.small)
            }
            Button(action: reveal) { Image(systemName: "folder") }
                .buttonStyle(.borderless).help("Show in Finder")
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var statusBadge: some View {
        switch app.status {
        case .updateAvailable: Text("UPDATE").font(.system(size: 9, weight: .bold)).foregroundColor(.orange)
        case .upToDate: Text("CURRENT").font(.system(size: 9, weight: .bold)).foregroundColor(.green)
        case .checking: Text("CHECKING").font(.system(size: 9, weight: .bold)).foregroundColor(.blue)
        case .unverified, .error: Text("UNVERIFIED").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
        }
    }
}

private struct AlertText: Identifiable {
    let id = UUID()
    let message: String
    init(_ message: String) { self.message = message }
}
