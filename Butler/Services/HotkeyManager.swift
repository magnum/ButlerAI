import Foundation
import Carbon
import AppKit

class HotkeyManager {
    private var eventHandler: EventHandlerRef?
    private var monitorEvent: Any?
    private var permissionTimer: Timer?
    private let callback: () -> Void
    
    init(callback: @escaping () -> Void) {
        self.callback = callback
        if RuntimeEnvironment.isRunningTests {
            log("Skipping accessibility check during tests")
        } else {
            setupAccessibilityCheck()
        }
    }
    
    deinit {
        log("Cleaning up HotkeyManager")
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
        if let monitor = monitorEvent {
            NSEvent.removeMonitor(monitor)
        }
        permissionTimer?.invalidate()
    }
    
    private func setupAccessibilityCheck() {
        log("Setting up accessibility check")
        
        // Initial check
        checkAccessibilityPermissions()
        
        // Periodic check if not granted
        if !AXIsProcessTrusted() {
            log("Starting permission check timer")
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    log("Accessibility permission detected")
                    timer.invalidate()
                    self?.onAccessibilityGranted()
                }
            }
        }
    }
    
    private func onAccessibilityGranted() {
        log("Accessibility permission granted")
        registerHotkey()
    }
    
    private func checkAccessibilityPermissions() {
        if !AXIsProcessTrusted() {
            log("Warning: App is not trusted for accessibility", type: .warning)
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options)
            
            // Show alert about accessibility permissions
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Access Required"
                alert.informativeText = """
                    ButlerAI needs accessibility access to detect keyboard shortcuts.
                    
                    Please enable it in System Settings:
                    1. Open System Settings
                    2. Go to Privacy & Security > Accessibility
                    3. Enable ButlerAI
                    """
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Later")
                
                NSApp.activate(ignoringOtherApps: true)
                if alert.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
        } else {
            log("App is trusted for accessibility")
            registerHotkey()
        }
    }
    
    private func registerHotkey() {
        log("Registering global hotkey ⌃⌥⌘C")
        
        // Set up monitoring of global keyboard events
        monitorEvent = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else {
                log("Warning: Self is nil in hotkey handler", type: .warning)
                return
            }
            
            if event.modifierFlags.contains([.control, .option, .command]) &&
               event.keyCode == 0x08 { // 'c' key
                log("Global keyboard shortcut ⌃⌥⌘C detected")
                DispatchQueue.main.async {
                    self.callback()
                }
            }
        }
        
        if monitorEvent == nil {
            log("Error: Failed to register global monitor", type: .error)
        } else {
            log("Global keyboard monitor registered successfully")
        }
    }
}
