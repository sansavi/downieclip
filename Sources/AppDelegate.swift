import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var preferencesController: PreferencesWindowController?
    private var currentShortcut = Shortcut.default
    private var feedbackResetWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let identifier = Bundle.main.bundleIdentifier ?? "com.github.sansavi.downieclip"
        if NSRunningApplication.runningApplications(withBundleIdentifier: identifier).count > 1 {
            Log.write("wykryto inną instancję DownieClip — kończę")
            NSApp.terminate(nil)
            return
        }

        setupStatusItem()
        currentShortcut = ShortcutStore.load()
        registerHotKey()
        enableLoginItemOnFirstRun()
        Log.write("DownieClip uruchomiony; skrót=\(currentShortcut.display); metoda=\(Preferences.sendMethod.rawValue)")

        if CommandLine.arguments.contains("--show-settings") {
            DispatchQueue.main.async { [weak self] in self?.openPreferences() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "DownieClip")
            button.image?.isTemplate = true
            button.toolTip = "DownieClip — \(currentShortcut.display): wyślij link ze schowka do Downie"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Wyślij link ze schowka do Downie", action: #selector(sendClipboardFromMenu), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Ustawienia…", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Otwórz Downie 4", action: #selector(openDownie), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Otwórz log", action: #selector(openLog), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Zakończ", action: #selector(quit), keyEquivalent: "q"))
        for item in menu.items where item.action != nil {
            item.target = self
        }
        statusItem.menu = menu
    }

    // MARK: - Skrót

    /// Przy pierwszym uruchomieniu z /Applications włączamy autostart, żeby skrót
    /// działał też po restarcie. Wyłączalne w ustawieniach (checkbox) lub CLI.
    private func enableLoginItemOnFirstRun() {
        let key = "didConfigureLoginItem"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        guard Bundle.main.bundlePath.hasPrefix("/Applications/") else {
            Log.write("autostart: apka nie jest w /Applications — pomijam")
            return
        }
        if !LoginItem.isEnabled {
            LoginItem.setEnabled(true)
            Log.write("autostart: włączony przy pierwszym uruchomieniu")
        }
    }

    private func registerHotKey() {
        let ok = HotKeyManager.shared.register(currentShortcut) { [weak self] in
            self?.sendClipboard()
        }
        if !ok {
            feedback(ok: false, tooltip: "Nie udało się zarejestrować skrótu \(currentShortcut.display) — może być zajęty")
        }
    }

    // MARK: - Akcje

    @objc private func sendClipboardFromMenu() {
        sendClipboard()
    }

    func sendClipboard() {
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        guard !text.isEmpty else {
            Log.write("send: schowek jest pusty")
            feedback(ok: false, tooltip: "Schowek jest pusty")
            return
        }

        let method = Preferences.sendMethod
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let outcome = DownieSender.send(text: text, method: method)
            Log.write("send: ok=\(outcome.ok) msg=\(outcome.message)")
            DispatchQueue.main.async {
                self?.feedback(ok: outcome.ok, tooltip: outcome.message)
                if Preferences.playSound {
                    NSSound(named: outcome.ok ? "Glass" : "Basso")?.play()
                }
            }
        }
    }

    private func feedback(ok: Bool, tooltip: String) {
        guard let button = statusItem.button else { return }
        button.toolTip = tooltip
        button.image = nil
        button.title = ok ? "✓" : "✗"
        feedbackResetWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let button = self?.statusItem.button else { return }
            button.title = ""
            button.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "DownieClip")
            button.image?.isTemplate = true
            button.toolTip = "DownieClip — \(self?.currentShortcut.display ?? ""): wyślij link ze schowka do Downie"
        }
        feedbackResetWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: item)
    }

    @objc private func openPreferences() {
        if preferencesController == nil {
            let controller = PreferencesWindowController()
            controller.onShortcutChanged = { [weak self] shortcut in
                guard let self = self else { return }
                self.currentShortcut = shortcut
                self.registerHotKey()
            }
            controller.onMethodChanged = { [weak self] in
                self?.feedback(ok: true, tooltip: "Metoda wysyłania: \(Preferences.sendMethod.title)")
            }
            preferencesController = controller
        }
        preferencesController?.show()
    }

    @objc private func openDownie() {
        guard let url = DownieSender.appURL() else {
            feedback(ok: false, tooltip: "Nie znaleziono Downie 4")
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in }
    }

    @objc private func openLog() {
        NSWorkspace.shared.open(URL(fileURLWithPath: Log.path))
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
