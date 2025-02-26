//
//  AppDelegate.swift
//  DemoAppSufferingFromBug
//
//  Created by Tobias Jordan on 26.02.25.
//

import ApplicationServices
import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet private var window: NSWindow!
    @IBOutlet private weak var processButton: NSPopUpButton!
    @IBOutlet private weak var statusLabel: NSTextField!

    private var processButtonObserver: AnyObject?
    private let processListMenu = NSMenu()
    private var observer: AXObserver?
    private var appElement: AXUIElement?
    private var selectedApp: NSRunningApplication?

    func applicationWillFinishLaunching(_ aNotification: Notification) {
        updateProcessMenu()
        processButton.menu = processListMenu
        processButton.selectItem(withTag: 1000)

        processButtonObserver = NotificationCenter.default.addObserver(forName: NSPopUpButton.willPopUpNotification, object: processButton, queue: nil) { [self] _ in
            let selectedItemIndex = processButton.indexOfSelectedItem
            updateProcessMenu()
            if processListMenu.items.count > selectedItemIndex {
                processButton.selectItem(at: selectedItemIndex)
            }
        }

        if checkForAccessibility(prompt: true) {
            if let selectedItem = processButton.selectedItem {
                chooseProcess(selectedItem)
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        window?.makeKeyAndOrderFront(nil)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if checkForAccessibility(prompt: false), selectedApp == nil, let selectedItem = processButton.selectedItem {
            chooseProcess(selectedItem)
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    @discardableResult
    private func checkForAccessibility(prompt: Bool) -> Bool {
        let options = prompt ? [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary : nil
        let isTrusted = AXIsProcessTrustedWithOptions(options)

        let noPermissionsText = """
No permissions to use Accessibility API. Please grant permissions in System Settings -> Privacy & Security -> Accessbility -> \(ProcessInfo().processName)
"""
        let instructionsText = """
This is a demo app for a potential bug in the Accessbility API on macOS 15 Sequoia.

Steps to reproduce bug:
1. Choose a process where you can create new windows (e.g. Mail or TextEdit).
2. Switch to the process and open a new window.
3. Watch the Xcode console to see how the app keeps track of newly create windows using Accessibility.
4. Run `DemoAppTriggeringBug`, choose the same process and click the "Enable" button to start observing `AXUIElementDestroyed` of the top-level element.
5. As long as `DemoAppTriggeringBug` has the observer enabled, this app will no longer receive AXUIElementDestroyed notifications for newly created windows. This is the bug!   
"""

        processButton.isEnabled = isTrusted
        statusLabel.stringValue = isTrusted ? instructionsText : noPermissionsText
        statusLabel.textColor = isTrusted ? .secondaryLabelColor : .systemRed

        return isTrusted
    }

    private func updateProcessMenu() {
        let processes = NSWorkspace.shared.runningApplications.sorted(by: { $0.localizedName ?? "" > $1.localizedName ?? "" })
        let menuItems: [NSMenuItem] = processes.map { app in
            let appName: String = {
                let name = app.localizedName ?? String(app.processIdentifier)
                return "\(name) - \(app.processIdentifier)"
            }()

            let menuItem = NSMenuItem(
                title: appName,
                action: #selector(chooseProcess(_:)),
                keyEquivalent: ""
            )

            menuItem.representedObject = app

            if let bundleIdentifier = app.bundleIdentifier, bundleIdentifier == "com.apple.mail" {
                menuItem.tag = 1000
            }

            if let bundleURL = app.bundleURL {
                let appIcon = NSWorkspace.shared.icon(forFile: bundleURL.path)
                appIcon.size = NSSize(width: 16.0, height: 16.0)
                menuItem.image = appIcon
            }
            return menuItem
        }

        processListMenu.removeAllItems()
        menuItems.forEach(processListMenu.addItem)
    }

    @objc private func chooseProcess(_ sender: NSMenuItem) {
        guard let app = sender.representedObject as? NSRunningApplication else { return }
        selectedApp = app
        addObserver(for: app)
    }

    private func addObserver(for app: NSRunningApplication) {
        if let observer, let appElement {
            let result = AXObserverRemoveNotification(observer, appElement, kAXWindowCreatedNotification as CFString)
            if result != .success {
                print("Failed to remove notification: \(result.rawValue)")
            }
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
            self.observer = nil
            self.appElement = nil

            print("Accessibility Observer stopped.")
        }

        let pid = app.processIdentifier
        let callback: AXObserverCallback = { observer, element, notification, refcon in
            guard let refcon = refcon else { return }
            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
            appDelegate.handleAXNotification(notification as String, element: element)
        }

        guard AXObserverCreate(pid, callback, &observer) == .success, let observer = observer else {
            print("Failed to create observer")
            return
        }

        print("🚀 Accessibility Observer for \(app.localizedName ?? "Unknown") is running, please create a new window…")

        let appElement = AXUIElementCreateApplication(pid)
        self.appElement = appElement
        let result = AXObserverAddNotification(observer, appElement, kAXWindowCreatedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
        if result != .success {
            print("Failed to add kAXWindowCreatedNotification notification: \(result.rawValue)")
        }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
    }

    private func handleAXNotification(_ notification: String, element: AXUIElement) {
        switch notification {
        case kAXWindowCreatedNotification:
            // Add observer for AXUIElementDestroyed
            axWindowCreated(element)
        default:
            break
        }

        let appName = selectedApp?.localizedName ?? "Unknown"
        print("🔔 \(appName): \(notification)")
    }

    private func axWindowCreated(_ window: AXUIElement) {
        guard let observer else { return }
        let result = AXObserverAddNotification(observer, window, kAXUIElementDestroyedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
        if result != .success {
            print("Failed to add kAXUIElementDestroyedNotification notification: \(result.rawValue)")
        }
    }
}


