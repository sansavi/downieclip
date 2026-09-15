import AppKit
import Foundation

// MARK: - Tryb CLI (do testów i integracji ze skryptami)

func cliExitCode(for outcome: SendOutcome) -> Int32 {
    print(outcome.ok ? "OK: \(outcome.message)" : "BŁĄD: \(outcome.message)")
    return outcome.ok ? 0 : 1
}

func runCLI() -> Int32 {
    let args = CommandLine.arguments
    var method = Preferences.sendMethod
    if let index = args.firstIndex(of: "--method"), index + 1 < args.count,
       let parsed = SendMethod(rawValue: args[index + 1]) {
        method = parsed
    }

    _ = NSApplication.shared  // potrzebne dla NSPasteboard / NSWorkspace

    if let index = args.firstIndex(of: "--login-item"), index + 1 < args.count {
        let value = args[index + 1].lowercased()
        let enable = ["on", "yes", "1", "true", "enable", "włącz", "wlacz"].contains(value)
        LoginItem.setEnabled(enable)
        print(enable ? "OK: autostart przy logowaniu włączony" : "OK: autostart przy logowaniu wyłączony")
        return 0
    }

    if args.contains("--status") {
        let shortcut = ShortcutStore.load()
        let clipboardURLs = DownieSender.extractURLs(from: NSPasteboard.general.string(forType: .string) ?? "")
        print("""
        Skrót:              \(shortcut.display)
        Metoda wysyłania:   \(Preferences.sendMethod.rawValue)
        Autostart:          \(LoginItem.isEnabled ? "włączony" : "wyłączony")
        Dźwięk:             \(Preferences.playSound ? "tak" : "nie")
        Downie 4:           \(DownieSender.appURL()?.path ?? "NIE ZNALEZIONO")
        Downie działa:      \(DownieSender.isRunning() ? "tak" : "nie")
        Linki w schowku:    \(clipboardURLs.count)
        Log:                \(Log.path)
        """)
        return 0
    }

    if let index = args.firstIndex(of: "--send-url"), index + 1 < args.count {
        let url = args[index + 1]
        return cliExitCode(for: DownieSender.send(text: url, method: method))
    }

    if args.contains("--send") {
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        if text.isEmpty {
            print("BŁĄD: schowek jest pusty")
            return 1
        }
        return cliExitCode(for: DownieSender.send(text: text, method: method))
    }

    print("""
    DownieClip — wysyła link ze schowka do Downie 4.

    Użycie:
      DownieClip                        uruchamia agenta w pasku menu (skrót globalny)
      DownieClip --show-settings        uruchamia agenta i otwiera ustawienia
      DownieClip --send [--method M]    wysyła URL ze schowka i kończy  (M: auto|appleScript|launchServices)
      DownieClip --send-url URL         wysyła podany URL i kończy
      DownieClip --status               pokazuje konfigurację
      DownieClip --login-item on|off    włącza/wyłącza autostart przy logowaniu
    """)
    return 0
}

if CommandLine.arguments.count > 1 {
    exit(runCLI())
}

// MARK: - Tryb aplikacji (agent w pasku menu)

let delegate = AppDelegate()
let application = NSApplication.shared
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
