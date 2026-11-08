import SwiftUI
import AppKit
import ServiceManagement

// Reads ChatGPT's saved dictations from ~/.codex/dictation-history/*/metadata.json
struct Recording: Identifiable, Equatable {
    let id: String
    let date: Date
    let text: String?
    var failed: Bool { (text ?? "").isEmpty }
}

final class Store: ObservableObject {
    @Published var items: [Recording] = []
    private let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/dictation-history")
    private var timer: Timer?

    init() {
        load()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.load() }
    }

    func load() {
        let fm = FileManager.default
        let folders = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        var out: [Recording] = []
        for f in folders {
            guard let data = try? Data(contentsOf: f.appendingPathComponent("metadata.json")),
                  let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ms = j["createdAtMs"] as? Double else { continue }
            let text = (j["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            out.append(Recording(id: (j["id"] as? String) ?? f.lastPathComponent,
                                 date: Date(timeIntervalSince1970: ms / 1000), text: text))
        }
        out.sort { $0.date > $1.date }
        let top = Array(out.prefix(20))
        if top != items { items = top }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }
    static let pageBG = Color(hex: 0x181818)
    static let cardBG = Color(hex: 0x232323)
    static let cardBorder = Color(hex: 0x353535)
    static let rowLine = Color(hex: 0x2e2e2e)
    static let primaryText = Color(hex: 0xececec)
    static let secondaryText = Color(hex: 0x9b9b9b)
    static let pill = Color(hex: 0x2e2e2e)
}

let dateFormat: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMM d, h:mm a"
    return f
}()

func copy(_ s: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(s, forType: .string)
}

func openChatGPT() {
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") {
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }
}

struct IconButton: View {
    let symbol: String
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(hover ? .primaryText : .secondaryText)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 7).fill(hover ? Color.pill : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

struct Row: View {
    let item: Recording
    let expanded: Bool
    let toggle: () -> Void
    @State private var copied = false

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.failed ? "Recording saved" : item.text!)
                    .font(.system(size: 13))
                    .foregroundColor(.primaryText)
                    .lineLimit(expanded ? nil : 1)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: expanded)
                    .textSelection(.enabled)
                Text(dateFormat.string(from: item.date))
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { if !item.failed { toggle() } }

            if item.failed {
                Button("Retry") { openChatGPT() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primaryText)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Color.pill))
                    .help("Open ChatGPT to retry this recording")
            } else {
                IconButton(symbol: copied ? "checkmark" : "square.on.square") {
                    copy(item.text!)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                }
                .help("Copy")
            }
            Menu {
                if !item.failed {
                    Button("Copy") { copy(item.text!) }
                    Button(expanded ? "Collapse" : "Show full text") { toggle() }
                } else {
                    Button("Retry in ChatGPT") { openChatGPT() }
                }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 13)).foregroundColor(.secondaryText)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 28, height: 28)
        }
        .padding(.vertical, 9)
    }
}

struct ContentView: View {
    @ObservedObject var store: Store
    @State private var expanded: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Recent recordings")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primaryText)
                Text("Your last 20 recordings saved on this device")
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 12)

            Rectangle().fill(Color.rowLine).frame(height: 1).padding(.horizontal, 16)

            if store.items.isEmpty {
                Text("No recordings yet")
                    .font(.system(size: 13)).foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity).padding(.vertical, 30)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(store.items.enumerated()), id: \.element.id) { i, item in
                            Row(item: item, expanded: expanded == item.id) {
                                withAnimation(.easeOut(duration: 0.15)) { expanded = expanded == item.id ? nil : item.id }
                            }
                            if i < store.items.count - 1 {
                                Rectangle().fill(Color.rowLine).frame(height: 1)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: min(CGFloat(store.items.count) * 54, 560))
            }
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.cardBG))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cardBorder, lineWidth: 1))
        .padding(10)
        .frame(width: 520)
        .background(Color.pageBG)
        .environment(\.colorScheme, .dark)
        .onAppear { store.load() }
        .background(Button("") { NSApp.terminate(nil) }.keyboardShortcut("q").opacity(0))
    }
}

@main
struct TranscriptsApp: App {
    @StateObject private var store = Store()
    init() {
        // Start with the Mac, so the icon is always in the menu bar.
        try? SMAppService.mainApp.register()
    }
    var body: some Scene {
        MenuBarExtra {
            ContentView(store: store)
        } label: {
            Image(systemName: "waveform")
        }
        .menuBarExtraStyle(.window)
    }
}
