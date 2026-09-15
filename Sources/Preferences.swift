import AppKit
import Foundation

enum Preferences {
    private static let methodKey = "sendMethod"
    private static let soundKey = "playSound"

    static var sendMethod: SendMethod {
        get {
            guard let raw = UserDefaults.standard.string(forKey: methodKey),
                  let method = SendMethod(rawValue: raw) else { return .auto }
            return method
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: methodKey) }
    }

    static var playSound: Bool {
        get { return UserDefaults.standard.object(forKey: soundKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: soundKey) }
    }
}

/// Autostart przy logowaniu przez LaunchAgent (bez helper bundle'a).
enum LoginItem {
    static let label = "com.github.sansavi.downieclip"
    static var plistPath: String {
        NSHomeDirectory() + "/Library/LaunchAgents/\(label).plist"
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistPath)
    }

    static func setEnabled(_ enabled: Bool) {
        guard let executable = Bundle.main.executablePath else { return }
        if enabled {
            let plist: [String: Any] = [
                "Label": label,
                "ProgramArguments": [executable],
                "RunAtLoad": true,
                "KeepAlive": false,
                "ProcessType": "Interactive"
            ]
            if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
                let dir = (plistPath as NSString).deletingLastPathComponent
                try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                try? data.write(to: URL(fileURLWithPath: plistPath))
            }
            runLaunchctl(["bootout", "gui/\(getuid())/\(label)"])   // usuń starą rejestrację, jeśli jest
            runLaunchctl(["bootstrap", "gui/\(getuid())", plistPath])
        } else {
            runLaunchctl(["bootout", "gui/\(getuid())/\(label)"])
            try? FileManager.default.removeItem(atPath: plistPath)
        }
        Log.write("loginItem enabled=\(enabled)")
    }

    @discardableResult
    private static func runLaunchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            Log.write("launchctl \(arguments.joined(separator: " ")) error: \(error.localizedDescription)")
            return -1
        }
    }
}
