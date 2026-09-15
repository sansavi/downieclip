import AppKit
import Foundation

enum SendMethod: String, CaseIterable {
    case auto
    case appleScript
    case launchServices

    var title: String {
        switch self {
        case .auto: return "Automatycznie (AppleScript, potem fallback)"
        case .appleScript: return "AppleScript (open all URLs in text)"
        case .launchServices: return "LaunchServices (open -a \"Downie 4\")"
        }
    }
}

struct SendOutcome {
    let ok: Bool
    let message: String

    static func failure(_ m: String) -> SendOutcome { SendOutcome(ok: false, message: m) }
    static func success(_ m: String) -> SendOutcome { SendOutcome(ok: true, message: m) }
}

/// Wysyłka linków do Downie 4.
///
/// Dwie niezależne drogi:
///  1. AppleScript — `tell application "Downie 4" to open all URLs in text ...`
///     (oficjalne API Downie; macOS może raz zapytać o zgodę na sterowanie).
///  2. LaunchServices — przekazanie URL-a do aplikacji przez `open -a`,
///     bez pytania o uprawnienia Automation.
enum DownieSender {
    static let bundleID = "com.charliemonroe.Downie-4"
    static let appName = "Downie 4"

    // MARK: - Wykrywanie

    static func appURL() -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    static func isRunning() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    @discardableResult
    static func ensureRunning(wait: Bool = true) -> Bool {
        if isRunning() { return true }
        guard let url = appURL() else { return false }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        let semaphore = DispatchSemaphore(value: 0)
        var launched = false
        NSWorkspace.shared.openApplication(at: url, configuration: config) { app, error in
            launched = (app != nil)
            if let error = error { Log.write("launch error: \(error.localizedDescription)") }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 10)
        if launched && wait {
            // Downie musi mieć gotowy AppleEvent handler, zanim przyjmiemy pierwsze zdarzenie.
            Thread.sleep(forTimeInterval: 2.0)
        }
        Log.write("ensureRunning -> \(launched)")
        return launched
    }

    // MARK: - Parsowanie URL-i

    private static let urlRegex = try! NSRegularExpression(
        pattern: #"(?:https?|ftp)://[^\s<>"'\)\]]+"#,
        options: [.caseInsensitive]
    )

    static func extractURLs(from text: String) -> [String] {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var seen = Set<String>()
        var out: [String] = []
        for match in urlRegex.matches(in: text, range: range) {
            guard let r = Range(match.range, in: text) else { continue }
            var url = String(text[r])
            // usuń końcową interpunkcję, która częściej jest zdaniem niż częścią URL-a
            while let last = url.last, ".,;:!?".contains(last) || last == ")" {
                url.removeLast()
            }
            if url.isEmpty { continue }
            if url.hasSuffix("(") { continue }
            if seen.insert(url).inserted { out.append(url) }
        }
        return out
    }

    // MARK: - Wysyłka

    static func send(text: String, method: SendMethod) -> SendOutcome {
        let urls = extractURLs(from: text)
        guard !urls.isEmpty else {
            return .failure("Brak linku (http/https) w schowku")
        }
        guard ensureRunning() else {
            return .failure("Nie znalazłem Downie 4 w /Applications")
        }

        switch method {
        case .appleScript:
            return sendViaAppleScript(text: urls.joined(separator: "\n"))
        case .launchServices:
            return sendViaLaunchServices(urls)
        case .auto:
            let result = sendViaAppleScript(text: urls.joined(separator: "\n"))
            if result.ok { return result }
            Log.write("appleScript failed (\(result.message)) — fallback na LaunchServices")
            let fallback = sendViaLaunchServices(urls)
            if fallback.ok { return fallback }
            return .failure("\(result.message) / \(fallback.message)")
        }
    }

    /// Escapowanie tekstu do literału AppleScript w podwójnych cudzysłowach.
    static func appleScriptLiteral(_ text: String) -> String {
        var out = ""
        for character in text {
            switch character {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default: out.append(character)
            }
        }
        return "\"" + out + "\""
    }

    /// Oficjalne API Downie: `open all URLs in text` wykrywa linki i dodaje je do
    /// kolejki, ale NIE startuje pobierania — dlatego po dodaniu wołamy `start queue`.
    static func sendViaAppleScript(text: String) -> SendOutcome {
        let source = """
        tell application "\(appName)"
            set added to open all URLs in text \(appleScriptLiteral(text))
            if added is 1 then
                start queue
            end if
            return added
        end tell
        """
        guard let script = NSAppleScript(source: source) else {
            return .failure("Nie udało się utworzyć skryptu")
        }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo = errorInfo {
            let message = (errorInfo[NSAppleScript.errorMessage] as? String) ?? "nieznany błąd AppleScript"
            let number = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? 0
            return .failure("AppleScript error \(number): \(message)")
        }
        let added = result.int32Value
        if added == 1 {
            return .success("Dodano do Downie (AppleScript)")
        }
        return .failure("Downie nie znalazł linku w tekście")
    }

    static func sendViaLaunchServices(_ urls: [String]) -> SendOutcome {
        guard let appURL = appURL() else { return .failure("Brak Downie 4") }
        let nsURLs = urls.compactMap { URL(string: $0) }
        guard !nsURLs.isEmpty else { return .failure("Niepoprawny URL") }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        let semaphore = DispatchSemaphore(value: 0)
        var ok = false
        var failure: String?
        NSWorkspace.shared.open(nsURLs, withApplicationAt: appURL, configuration: config) { _, error in
            if let error = error {
                failure = error.localizedDescription
            } else {
                ok = true
            }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 15)
        if ok {
            return .success("Przekazano \(nsURLs.count) link(i) do Downie (LaunchServices)")
        }
        return .failure(failure ?? "Timeout przy przekazywaniu URL-a")
    }
}
