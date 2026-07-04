import SwiftUI
import AppKit
import IOKit.ps

/// A compact widget strip: clock, battery, and quick access to recent Downloads.
/// All local; no network. Time updates on a 1s timer while visible.
struct WidgetsView: View {
    @State private var now = Date.distantPast
    @State private var battery: (level: Int, charging: Bool)?
    @State private var recentDownloads: [URL] = []

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().opacity(0.4)
            HStack(spacing: 14) {
                clock
                if let battery { batteryView(battery) }
                Spacer()
            }
            .padding(.horizontal, PanelLayout.padding)

            if !recentDownloads.isEmpty {
                downloadsRow
            }
        }
        .padding(.bottom, 6)
        .onAppear { refresh() }
        .onReceive(timer) { _ in refresh() }
    }

    private var clock: some View {
        Label(now.formatted(date: .omitted, time: .shortened), systemImage: "clock")
            .font(.caption).monospacedDigit()
    }

    private func batteryView(_ b: (level: Int, charging: Bool)) -> some View {
        Label("\(b.level)%", systemImage: b.charging ? "battery.100.bolt" : batterySymbol(b.level))
            .font(.caption).monospacedDigit()
    }

    private var downloadsRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Recent Downloads")
                .font(.caption2).bold().foregroundStyle(.secondary)
                .padding(.horizontal, PanelLayout.padding)
            ForEach(recentDownloads, id: \.self) { url in
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label(url.lastPathComponent, systemImage: "arrow.down.doc")
                        .font(.caption).lineLimit(1).truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, PanelLayout.padding)
            }
        }
    }

    private func batterySymbol(_ level: Int) -> String {
        switch level {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }

    private func refresh() {
        now = Date()
        battery = Self.readBattery()
        recentDownloads = Self.readRecentDownloads()
    }

    static func readBattery() -> (level: Int, charging: Bool)? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  let capacity = desc[kIOPSCurrentCapacityKey] as? Int,
                  let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            let state = desc[kIOPSPowerSourceStateKey] as? String
            return (Int(Double(capacity) / Double(max) * 100), state == kIOPSACPowerValue)
        }
        return nil
    }

    static func readRecentDownloads() -> [URL] {
        guard let downloads = try? FileManager.default.url(for: .downloadsDirectory, in: .userDomainMask,
                                                           appropriateFor: nil, create: false) else { return [] }
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isHiddenKey]
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: downloads, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return [] }
        return items
            .filter { !(($0.lastPathComponent).hasSuffix(".download")) }
            .sorted {
                let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return a > b
            }
            .prefix(3)
            .map { $0 }
    }
}
