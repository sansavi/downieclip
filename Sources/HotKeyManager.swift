import AppKit
import Carbon.HIToolbox

/// Rejestracja globalnego skrótu przez Carbon RegisterEventHotKey.
/// Nie wymaga uprawnień Accessibility (w przeciwieństwie do monitorowania klawiatury).
final class HotKeyManager {
    static let shared = HotKeyManager()

    private static let signature: OSType = 0x44434C50 // 'DCLP'

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var callback: (() -> Void)?

    private init() {}

    @discardableResult
    func register(_ shortcut: Shortcut, callback: @escaping () -> Void) -> Bool {
        unregister()
        guard shortcut.isUsable else {
            Log.write("hotkey: skrót nieprawidłowy — pomijam")
            return false
        }
        self.callback = callback

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event = event, let userData = userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if hotKeyID.signature == HotKeyManager.signature {
                    DispatchQueue.main.async { manager.callback?() }
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandler
        )
        guard installStatus == noErr else {
            Log.write("hotkey: InstallEventHandler failed (\(installStatus))")
            return false
        }

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: HotKeyManager.signature, id: 1)
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr else {
            Log.write("hotkey: RegisterEventHotKey failed (\(status)) dla \(shortcut.display)")
            return false
        }
        hotKeyRef = ref
        Log.write("hotkey: zarejestrowano \(shortcut.display)")
        return true
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        callback = nil
    }
}
