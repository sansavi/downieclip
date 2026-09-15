import AppKit
import Carbon.HIToolbox

/// Pole przechwytujące kombinację klawiszy (bez wymogu Accessibility —
/// zdarzenia przechwytujemy lokalnie, tylko gdy okno ustawień jest aktywne).
final class ShortcutRecorderView: NSView {
    var onCapture: ((Shortcut) -> Void)?
    var current: Shortcut {
        didSet { needsDisplay = true }
    }

    private var monitor: Any?
    private var isRecording = false

    init(shortcut: Shortcut) {
        self.current = shortcut
        super.init(frame: NSRect(x: 0, y: 0, width: 220, height: 32))
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("nib nie jest używany") }

    override var intrinsicContentSize: NSSize { NSSize(width: 220, height: 32) }
    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.18) : NSColor.textBackgroundColor).setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = isRecording ? 2 : 1
        path.stroke()

        let text = isRecording ? "Naciśnij kombinację…" : current.display
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: isRecording ? NSColor.controlAccentColor : NSColor.labelColor,
            .paragraphStyle: style
        ]
        let size = text.size(withAttributes: attributes)
        let rect = NSRect(x: 0, y: (bounds.height - size.height) / 2, width: bounds.width, height: size.height)
        text.draw(in: rect, withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        isRecording ? stopRecording() : startRecording()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { stopRecording() }
    }

    private func startRecording() {
        guard monitor == nil else { return }
        isRecording = true
        needsDisplay = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self, self.isRecording else { return event }
            if event.keyCode == UInt16(kVK_Escape) {
                self.stopRecording()
                return nil
            }
            var flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            flags.subtract([.capsLock, .numericPad, .function, .help])
            let modifiers = Shortcut.carbonModifiers(from: flags)
            guard modifiers != 0 else {
                NSSound.beep()  // wymagamy co najmniej jednego modyfikatora
                return nil
            }
            let shortcut = Shortcut(keyCode: UInt32(event.keyCode), carbonModifiers: modifiers)
            self.current = shortcut
            self.stopRecording()
            self.onCapture?(shortcut)
            return nil
        }
    }

    private func stopRecording() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
        needsDisplay = true
    }
}

final class PreferencesWindowController: NSWindowController {
    var onShortcutChanged: ((Shortcut) -> Void)?
    var onMethodChanged: (() -> Void)?

    private let recorder: ShortcutRecorderView
    private var methodPopup: NSPopUpButton!
    private var soundCheckbox: NSButton!
    private var loginCheckbox: NSButton!

    init() {
        recorder = ShortcutRecorderView(shortcut: ShortcutStore.load())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "DownieClip — ustawienia"
        super.init(window: window)
        buildUI()
        recorder.onCapture = { [weak self] shortcut in
            ShortcutStore.save(shortcut)
            Log.write("ustawienia: nowy skrót \(shortcut.display)")
            self?.onShortcutChanged?(shortcut)
        }
    }

    required init?(coder: NSCoder) { fatalError("nib nie jest używany") }

    func show() {
        recorder.current = ShortcutStore.load()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        func label(_ text: String) -> NSTextField {
            let field = NSTextField(labelWithString: text)
            field.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
            field.translatesAutoresizingMaskIntoConstraints = false
            return field
        }

        let hotKeyLabel = label("Skrót globalny")
        let hintLabel = NSTextField(labelWithString: "Kliknij pole i naciśnij kombinację (Esc = anuluj). Wymagany co najmniej jeden modyfikator.")
        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.lineBreakMode = .byWordWrapping
        hintLabel.maximumNumberOfLines = 2

        recorder.translatesAutoresizingMaskIntoConstraints = false

        let resetButton = NSButton(title: "Domyślny (⌥⌘V)", target: self, action: #selector(resetShortcut))
        resetButton.translatesAutoresizingMaskIntoConstraints = false

        let methodLabel = label("Metoda wysyłania")
        methodPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        methodPopup.translatesAutoresizingMaskIntoConstraints = false
        for method in SendMethod.allCases {
            methodPopup.addItem(withTitle: method.title)
            methodPopup.lastItem?.representedObject = method.rawValue
        }
        methodPopup.selectItem(at: SendMethod.allCases.firstIndex(of: Preferences.sendMethod) ?? 0)
        methodPopup.target = self
        methodPopup.action = #selector(methodChanged)

        soundCheckbox = NSButton(checkboxWithTitle: "Dźwięk po dodaniu linku", target: nil, action: nil)
        soundCheckbox.state = Preferences.playSound ? .on : .off
        soundCheckbox.target = self
        soundCheckbox.action = #selector(soundChanged)
        soundCheckbox.translatesAutoresizingMaskIntoConstraints = false

        loginCheckbox = NSButton(checkboxWithTitle: "Uruchamiaj przy logowaniu", target: nil, action: nil)
        loginCheckbox.state = LoginItem.isEnabled ? .on : .off
        loginCheckbox.target = self
        loginCheckbox.action = #selector(loginChanged)
        loginCheckbox.translatesAutoresizingMaskIntoConstraints = false

        let infoLabel = NSTextField(labelWithString: "Downie 4: \(DownieSender.appURL()?.path ?? "nie znaleziono w /Applications")")
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.translatesAutoresizingMaskIntoConstraints = false

        let allViews: [NSView] = [hotKeyLabel, recorder, resetButton, hintLabel, methodLabel, methodPopup, soundCheckbox, loginCheckbox, infoLabel]
        for view in allViews {
            content.addSubview(view)
        }

        NSLayoutConstraint.activate([
            hotKeyLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            hotKeyLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),

            recorder.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            recorder.centerYAnchor.constraint(equalTo: hotKeyLabel.centerYAnchor),
            recorder.widthAnchor.constraint(equalToConstant: 220),
            recorder.heightAnchor.constraint(equalToConstant: 32),

            hintLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            hintLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            hintLabel.topAnchor.constraint(equalTo: recorder.bottomAnchor, constant: 8),

            resetButton.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            resetButton.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 10),

            methodLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            methodLabel.topAnchor.constraint(equalTo: resetButton.bottomAnchor, constant: 18),
            methodPopup.leadingAnchor.constraint(equalTo: methodLabel.trailingAnchor, constant: 12),
            methodPopup.centerYAnchor.constraint(equalTo: methodLabel.centerYAnchor),
            methodPopup.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -20),

            soundCheckbox.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            soundCheckbox.topAnchor.constraint(equalTo: methodLabel.bottomAnchor, constant: 18),
            loginCheckbox.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            loginCheckbox.topAnchor.constraint(equalTo: soundCheckbox.bottomAnchor, constant: 6),
            infoLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            infoLabel.topAnchor.constraint(equalTo: loginCheckbox.bottomAnchor, constant: 12)
        ])
    }

    @objc private func resetShortcut() {
        ShortcutStore.save(.default)
        recorder.current = .default
        onShortcutChanged?(.default)
    }

    @objc private func methodChanged() {
        let index = methodPopup.indexOfSelectedItem
        guard index >= 0, index < SendMethod.allCases.count else { return }
        Preferences.sendMethod = SendMethod.allCases[index]
        Log.write("ustawienia: metoda = \(Preferences.sendMethod.rawValue)")
        onMethodChanged?()
    }

    @objc private func soundChanged() {
        Preferences.playSound = (soundCheckbox.state == .on)
    }

    @objc private func loginChanged() {
        LoginItem.setEnabled(loginCheckbox.state == .on)
        loginCheckbox.state = LoginItem.isEnabled ? .on : .off
    }
}
