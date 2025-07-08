//
//  ContentView.swift
//  NekoCLI
//
//  Created by StrayVibes on 08/07/25.
//

import SwiftUI
import Charts
import UserNotifications

struct Commit: Codable, Identifiable {
    var id: String { sha }
    let sha: String
    let commit: CommitMessage
    struct CommitMessage: Codable {
        let message: String
        let author: Author
        struct Author: Codable {
            let name: String
            let date: String
        }
    }
}

struct StatEntry: Identifiable {
    let id = UUID()
    let label: String
    let value: Int
}

struct NpmDownload: Codable {
    let downloads: Int
}

func fetchCommits() async throws -> [Commit] {
    let url = URL(string: "https://api.github.com/repos/Neko-CLI/Neko-CLI/commits")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode([Commit].self, from: data)
}

func fetchStats() async throws -> [StatEntry] {
    let base = "https://api.npmjs.org/downloads/point"
    let labels = ["last-day", "last-week", "last-month", "last-year"]
    let enLabels = ["day", "week", "month", "year"]
    var entries = [StatEntry]()
    for (index, label) in labels.enumerated() {
        let url = URL(string: "\(base)/\(label)/neko-cli")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(NpmDownload.self, from: data)
        entries.append(StatEntry(label: enLabels[index], value: decoded.downloads))
    }
    return entries
}

func fetchVersion() async throws -> String {
    let url = URL(string: "https://registry.npmjs.org/neko-cli/latest")!
    let (data, _) = try await URLSession.shared.data(from: url)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    return json?["version"] as? String ?? "unknown"
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

func isoDateToRelative(_ isoDate: String) -> String {
    let formatter = ISO8601DateFormatter()
    guard let date = formatter.date(from: isoDate) else { return "unknown" }
    let interval = Date().timeIntervalSince(date)
    if interval < 60 { return "moments ago" }
    if interval < 3600 { return "\(Int(interval/60))m ago" }
    if interval < 86400 { return "\(Int(interval/3600))h ago" }
    return "\(Int(interval/86400))d ago"
}

struct ContentView: View {
    @State private var npmStats: [StatEntry] = []
    @State private var version: String = ""
    @State private var isLoading = true
    @State private var notificationsEnabled = false
    @State private var commits: [Commit] = []

    let refreshInterval: TimeInterval = 1
    let notificationCenter = UNUserNotificationCenter.current()

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                HStack {
                    AsyncImage(url: URL(string: "https://i.imgur.com/eKHNd3C.png")) { image in
                        image.resizable()
                            .scaledToFit()
                            .frame(height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } placeholder: {
                        ProgressView()
                    }
                    Spacer()
                    if !notificationsEnabled {
                        Button(action: requestNotificationPermissions) {
                            Label("Enable Notifications", systemImage: "bell.badge")
                                .padding(8)
                                .background(Color(hex: "#5292F8"))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        Link(destination: URL(string: "https://neko-cli.com")!) {
                            Label("Site", systemImage: "link")
                                .padding(8)
                                .background(Color(hex: "#5292F8"))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    } else {
                        Spacer()
                        Link(destination: URL(string: "https://neko-cli.com")!) {
                            Label("Site", systemImage: "link")
                                .padding(8)
                                .background(Color(hex: "#5292F8"))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)

                ScrollView {
                    VStack(spacing: 14) {
                        Text("🚀 Neko-CLI Updates")
                            .font(.title2.bold())
                            .foregroundColor(Color(hex: "#5292F8"))

                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#5292F8")))
                                .scaleEffect(1.5)
                                .padding()
                        } else {
                            VersionCard(version: version)
                            ChartCard(stats: npmStats)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("🛠 GitHub Commits")
                                    .font(.headline)
                                    .foregroundColor(Color(hex: "#5292F8"))
                                ScrollView(.vertical, showsIndicators: true) {
                                    LazyVStack(alignment: .leading, spacing: 10) {
                                        ForEach(commits) { commit in
                                            Button(action: {
                                                if let url = URL(string: "https://github.com/Neko-CLI/Neko-CLI/commit/\(commit.sha)") {
                                                    UIApplication.shared.open(url)
                                                }
                                            }) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(commit.commit.message)
                                                        .font(.system(.body, design: .monospaced))
                                                        .foregroundColor(.white)
                                                        .lineLimit(2)
                                                    HStack(spacing: 10) {
                                                        Text("SHA: \(commit.sha.prefix(7))")
                                                            .font(.caption2)
                                                            .foregroundColor(Color.gray.opacity(0.8))
                                                        Text("👤 " + commit.commit.author.name)
                                                        Text("🕒 " + isoDateToRelative(commit.commit.author.date))
                                                    }
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                                }
                                                .padding(10)
                                                .background(Color(hex: "#1F2937"))
                                                .cornerRadius(8)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .frame(maxHeight: 280)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .background(Color(hex: "#111827"))
                .cornerRadius(12)
                .padding(.horizontal)
                .onAppear(perform: startAutoRefresh)

                Spacer()
            }
            .background(Color(hex: "#0F172A"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    func startAutoRefresh() {
        Task {
            await loadAllData()
            isLoading = false
            Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
                Task {
                    await loadCommitsOnly()
                }
            }
        }
    }

    func loadAllData() async {
        do {
            async let commitsTask = fetchCommits()
            async let statsTask = fetchStats()
            async let versionTask = fetchVersion()

            let (fetchedCommits, fetchedStats, fetchedVersion) = try await (commitsTask, statsTask, versionTask)

            DispatchQueue.main.async {
                self.commits = fetchedCommits
                self.npmStats = fetchedStats
                self.version = fetchedVersion
            }
        } catch {
            print("Failed to fetch data: \(error)")
        }
    }

    func loadCommitsOnly() async {
        do {
            let fetchedCommits = try await fetchCommits()
            DispatchQueue.main.async {
                let currentSHAs = Set(self.commits.map { $0.sha })
                let newCommits = fetchedCommits.filter { !currentSHAs.contains($0.sha) }
                if !newCommits.isEmpty {
                    self.commits.insert(contentsOf: newCommits, at: 0)
                    if notificationsEnabled {
                        sendNotification(title: "New commits available!", body: "There are \(newCommits.count) new commits.")
                    }
                }
            }
        } catch {
            print("Failed to fetch commits: \(error)")
        }
    }

    func requestNotificationPermissions() {
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    notificationsEnabled = true
                }
            } else {
                print("Notifications permission denied: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            if let error = error {
                print("Notification error: \(error.localizedDescription)")
            }
        }
    }
}

struct VersionCard: View {
    let version: String
    var body: some View {
        HStack {
            Text("Current Version:")
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Text(version)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(Color(hex: "#5292F8"))
            Spacer()
        }
        .padding()
        .background(Color(hex: "#1F2937"))
        .cornerRadius(10)
    }
}

struct ChartCard: View {
    let stats: [StatEntry]
    var body: some View {
        VStack(alignment: .leading) {
            Text("NPM Downloads")
                .font(.headline)
                .foregroundColor(Color(hex: "#5292F8"))
            Chart(stats) { stat in
                BarMark(
                    x: .value("Period", stat.label),
                    y: .value("Downloads", stat.value)
                )
                .foregroundStyle(Color(hex: "#5292F8"))
                .annotation(position: .top) {
                    Text("\(stat.value)")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }
            .frame(height: 180)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                        .foregroundStyle(Color.white)
                }
            }
        }
        .padding()
        .background(Color(hex: "#1F2937"))
        .cornerRadius(10)
    }
}
