import AppKit
import Combine
import SwiftUI

// MARK: - 更新数据模型（对应 Gitee Releases API 返回结构）

struct ReleaseAsset: Codable {
    let name: String
    let downloadURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case downloadURL = "browser_download_url"
    }
}

struct GiteeLatestRelease: Codable {
    let tagName: String
    let name: String?
    let body: String?
    let prerelease: Bool?
    let assets: [ReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case prerelease
        case assets
    }
}

/// 已解析的可安装更新
struct AppUpdate: Identifiable {
    let version: String
    let name: String?
    let releaseNotes: String?
    let releaseURL: URL
    let downloadURL: URL

    var id: String { version }
}

// MARK: - 更新状态

enum UpdateStatus {
    case idle
    case checking
    case upToDate
    case available(AppUpdate)
    case downloading(AppUpdate)
    case installing(AppUpdate)
    case failed(String)
}

enum UpdateError: LocalizedError {
    case unreachable(String)
    case noAsset
    case mountFailed(String)
    case missingApp

    var errorDescription: String? {
        switch self {
        case .unreachable(let message): return message
        case .noAsset: return "未找到可下载的 MouseDance.dmg 安装包。"
        case .mountFailed(let message): return "挂载更新包失败：\(message)"
        case .missingApp: return "更新包中未找到 MouseDance.app。"
        }
    }
}

// MARK: - 更新管理器

@MainActor
final class UpdateManager: ObservableObject {
    // Gitee 仓库与版本信息来源（如需切换到 GitHub 仅需改这里与 latestReleaseURL）
    private static let repoOwner = "qianxunclub"
    private static let repoName = "mouse-dance"
    private static let dmgName = "MouseDance.dmg"
    private static let latestReleaseURL =
        URL(string: "https://gitee.com/api/v5/repos/\(repoOwner)/\(repoName)/releases/latest")!

    @Published private(set) var status: UpdateStatus = .idle
    @Published private(set) var currentVersion: String = "0"

    init() {
        currentVersion = Self.readCurrentVersion()
    }

    func checkForUpdates() async {
        guard !isChecking else { return }
        status = .checking
        do {
            var request = URLRequest(url: Self.latestReleaseURL)
            request.setValue("MouseDance/\(currentVersion)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard statusCode == 200 else {
                throw UpdateError.unreachable("服务器返回异常状态（HTTP \(statusCode)）。")
            }

            let release = try JSONDecoder().decode(GiteeLatestRelease.self, from: data)

            // 优先取 dmg 资产，其次兜底任一 .dmg 后缀资产
            guard let asset = release.assets.first(where: { $0.name.lowercased() == Self.dmgName.lowercased() })
                ?? release.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") }) else {
                throw UpdateError.noAsset
            }

            let tag = Self.normalizeVersion(release.tagName)
            let hasNewer = Self.isNewer(tag, than: currentVersion)
            let isPrerelease = release.prerelease ?? false

            if hasNewer && !isPrerelease {
                status = .available(AppUpdate(
                    version: tag,
                    name: release.name,
                    releaseNotes: release.body,
                    releaseURL: Self.releasePageURL(for: release.tagName),
                    downloadURL: asset.downloadURL
                ))
            } else {
                status = .upToDate
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func downloadAndInstall() async {
        guard case .available(let update) = status else { return }
        status = .downloading(update)
        do {
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(Self.dmgName)-\(update.version)")
            try await downloadDMG(from: update.downloadURL, to: destination)

            status = .installing(update)
            let mount = try mountDMG(at: destination)
            let newApp = mount.appendingPathComponent("MouseDance.app")
            guard FileManager.default.fileExists(atPath: newApp.path) else {
                throw UpdateError.missingApp
            }

            performInstall(currentBundle: Bundle.main.bundleURL, newApp: newApp, mount: mount)
        } catch {
            status = .failed("更新安装失败：\(error.localizedDescription)")
        }
    }

    // MARK: - 下载

    private func downloadDMG(from url: URL, to destination: URL) async throws {
        var request = URLRequest(url: url)
        request.setValue("MouseDance/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        let (tempURL, response) = try await URLSession.shared.download(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard statusCode == 200 else {
            throw UpdateError.unreachable("下载安装包失败（HTTP \(statusCode)）。")
        }

        let fileManager = FileManager.default
        try? fileManager.removeItem(at: destination)
        try fileManager.moveItem(at: tempURL, to: destination)
    }

    // MARK: - 挂载

    private func mountDMG(at dmgPath: URL) throws -> URL {
        let mount = FileManager.default.temporaryDirectory
            .appendingPathComponent("MouseDanceUpdate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", "-nobrowse", "-readonly", "-mountpoint", mount.path, dmgPath.path]
        process.standardOutput = FileHandle.nullDevice

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw UpdateError.mountFailed(message.isEmpty ? "hdiutil 退出码 \(process.terminationStatus)" : message)
        }
        return mount
    }

    // MARK: - 安装

    /// 启动一个独立的 shell 进程执行替换与重启，随后退出当前应用。
    /// 这样即使当前进程退出，替换/重启流程也能继续完成（未签名 app 无法原地自替换）。
    private func performInstall(currentBundle: URL, newApp: URL, mount: URL) {
        let script =
            "sleep 1; rm -rf \(Self.shellQuote(currentBundle.path)); " +
            "/usr/bin/ditto \(Self.shellQuote(newApp.path)) \(Self.shellQuote(currentBundle.path)); " +
            "/usr/bin/xattr -cr \(Self.shellQuote(currentBundle.path)); " +
            "/usr/bin/hdiutil detach \(Self.shellQuote(mount.path)) -quiet || true; " +
            "/usr/bin/open \(Self.shellQuote(currentBundle.path))"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            // 稍候退出，让替换脚本有足够时间接管（脚本内先 sleep 1 等待本进程退出）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                NSApp.terminate(nil)
            }
        } catch {
            status = .failed("启动更新失败：\(error.localizedDescription)")
        }
    }

    // MARK: - 版本比较

    private static func readCurrentVersion() -> String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return short ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0")
    }

    /// 去掉 tag 前缀（如 v1.2.3 -> 1.2.3），用于和 MARKETING_VERSION 比较
    private static func normalizeVersion(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("v") || value.hasPrefix("V") {
            value = String(value.dropFirst())
        }
        return value
    }

    /// 按数字分段比较，兼容 "2026.6.2" 这类非语义化版本号
    private static func isNewer(_ lhs: String, than rhs: String) -> Bool {
        let left = lhs.split(separator: ".").compactMap { Int($0) }
        let right = rhs.split(separator: ".").compactMap { Int($0) }
        let count = max(left.count, right.count)
        for index in 0..<count {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a != b { return a > b }
        }
        return false
    }

    private static func releasePageURL(for tag: String) -> URL {
        URL(string: "https://gitee.com/\(repoOwner)/\(repoName)/releases/tag/\(tag)")!
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private var isChecking: Bool {
        if case .checking = status { return true }
        return false
    }
}

// MARK: - 更新界面

struct UpdateView: View {
    @ObservedObject var manager: UpdateManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title3)
                    .foregroundStyle(.tint)
                Text("软件更新")
                    .font(.headline)
                Spacer()
            }

            switch manager.status {
            case .idle:
                statusLine(icon: "sparkles", text: "点击菜单栏「检查更新…」开始。", tint: .secondary)

            case .checking:
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("正在检查更新…").foregroundStyle(.secondary)
                }

            case .upToDate:
                statusLine(
                    icon: "checkmark.circle.fill",
                    text: "当前已是新版本 \(manager.currentVersion)",
                    tint: .green
                )

            case .available(let update):
                availableContent(update)

            case .downloading(let update):
                installingContent(
                    update,
                    message: "正在下载 \(update.version)…",
                    systemImage: "arrow.down.circle"
                )

            case .installing(let update):
                installingContent(
                    update,
                    message: "正在安装 \(update.version)，应用即将自动重启…",
                    systemImage: "arrow.triangle.2.circlepath"
                )

            case .failed(let message):
                failedContent(message)
            }
        }
        .padding(20)
        .frame(width: 440, alignment: .leading)
    }

    @ViewBuilder
    private func availableContent(_ update: AppUpdate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("发现新版本 \(update.version)")
                    .font(.headline)
                Spacer()
                Text("当前 \(manager.currentVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let notes = update.releaseNotes, !notes.isEmpty {
                ScrollView {
                    Text(notes)
                        .font(.callout)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 220)
            } else {
                Text("点击「下载并安装」获取最新版本。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    Task { await manager.downloadAndInstall() }
                } label: {
                    Label("下载并安装", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)

                Button("跳过此版本") {
                    dismiss()
                }

                Spacer()

                Button("查看更新说明") {
                    NSWorkspace.shared.open(update.releaseURL)
                }
                .buttonStyle(.link)
            }
        }
    }

    @ViewBuilder
    private func installingContent(_ update: AppUpdate, message: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            Text(message)
                .foregroundStyle(.secondary)
            Text(update.version)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func failedContent(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            statusLine(icon: "exclamationmark.triangle.fill", text: "更新失败", tint: .orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("重试") {
                Task { await manager.checkForUpdates() }
            }
        }
    }

    @ViewBuilder
    private func statusLine(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}
