import Cocoa
import Foundation
import Network

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!
    var menuBarView: MenuBarView!
    var networkMonitor: NetworkMonitor!
    var ipFetcher: IPFlagFetcher!
    var ipMenuItem: NSMenuItem!
    var settingsController: SettingsWindowController?
    var networkChangeDetector: NetworkChangeDetector!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the status item with variable length initially
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        menuBarView = MenuBarView()
        
        if let button = statusItem.button {
            button.title = ""
            menuBarView.frame = button.bounds
            menuBarView.autoresizingMask = [.width, .height]
            button.addSubview(menuBarView)
        }
        
        // Setup Menu
        let menu = NSMenu()
        
        ipMenuItem = NSMenuItem(title: "Fetching IP...", action: nil, keyEquivalent: "")
        ipMenuItem.isEnabled = false // Not clickable
        menu.addItem(ipMenuItem)
        
        let refreshItem = NSMenuItem(title: "Refresh IP", action: #selector(refreshIP), keyEquivalent: "r")
        menu.addItem(refreshItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit NetBar", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        
        // Initialize Core Components
        ipFetcher = IPFlagFetcher()
        networkMonitor = NetworkMonitor()
        
        // Wire up callbacks
        networkMonitor.onSpeedUpdate = { [weak self] upload, download in
            guard let self = self else { return }
            self.menuBarView.updateSpeeds(upload: upload, download: download)
            self.updateMenuBarWidth()
        }
        
        ipFetcher.onUpdate = { [weak self] flag, ipString in
            guard let self = self else { return }
            self.menuBarView.updateFlag(flag, ip: ipString)
            self.ipMenuItem.title = "IP: \(ipString)"
            self.updateMenuBarWidth()
        }
        
        // Listen for preference changes
        NotificationCenter.default.addObserver(self, selector: #selector(preferencesChanged), name: Preferences.changedNotification, object: nil)
        
        // Setup network change detector (uses SCDynamicStore + NWPathMonitor + interface polling)
        // to reliably detect VPN connections/disconnections from any VPN app
        networkChangeDetector = NetworkChangeDetector()
        networkChangeDetector.onNetworkChange = { [weak self] in
            // Fetch immediately on network change for instant flag update
            self?.ipFetcher.fetchWithRetry()
        }
        networkChangeDetector.start()
        
        // Start monitoring immediately
        startNetworkMonitor()
        
        // Trigger an initial fetch
        ipFetcher.fetch()
        
        // Setup repeating fetch for IP (every 60 seconds as safety net)
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.ipFetcher.fetch()
        }
    }
    
    @objc func preferencesChanged() {
        startNetworkMonitor() // Restart timer if interval changed
        menuBarView.resetCachedWidth() // Recalculate width for new display settings
        updateMenuBarWidth()
        menuBarView.needsDisplay = true
    }
    
    private func updateMenuBarWidth() {
        let optimalLength = menuBarView.calculateOptimalWidth()
        statusItem.length = optimalLength
    }
    
    private func startNetworkMonitor() {
        networkMonitor.stop() // safety
        networkMonitor.start(interval: Preferences.shared.refreshInterval)
    }
    
    @objc func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController()
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc func refreshIP() {
        ipMenuItem.title = "Refreshing..."
        ipFetcher.fetch()
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

