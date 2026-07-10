import Foundation

class Preferences {
    static let shared = Preferences()
    
    // Notification name for when settings change
    static let changedNotification = Notification.Name("NetBarPreferencesChanged")
    
    private let defaults = UserDefaults.standard
    
    // Feature Toggles
    var showFlag: Bool {
        get { defaults.object(forKey: "showFlag") as? Bool ?? true }
        set { 
            defaults.set(newValue, forKey: "showFlag") 
            notify()
        }
    }
    
    var showArrows: Bool {
        get { defaults.object(forKey: "showArrows") as? Bool ?? true }
        set { 
            defaults.set(newValue, forKey: "showArrows")
            notify()
        }
    }
    
    var useSingleLine: Bool {
        get { defaults.bool(forKey: "useSingleLine") } // Defaults to false
        set { 
            defaults.set(newValue, forKey: "useSingleLine")
            notify()
        }
    }
    
    var showIPInsteadOfFlag: Bool {
        get { defaults.bool(forKey: "showIPInsteadOfFlag") } // Defaults to false
        set { 
            defaults.set(newValue, forKey: "showIPInsteadOfFlag")
            notify()
        }
    }
    
    var refreshInterval: Double {
        get { defaults.object(forKey: "refreshInterval") as? Double ?? 1.0 }
        set { 
            defaults.set(newValue, forKey: "refreshInterval")
            notify()
        }
    }
    
    // Speed Display Mode: 0 = Both, 1 = Upload Only, 2 = Download Only
    var displayMode: Int {
        get { defaults.object(forKey: "displayMode") as? Int ?? 0 }
        set {
            defaults.set(newValue, forKey: "displayMode")
            notify()
        }
    }
    
    // We handle Launch At Login via SMAppService directly in AppDelegate/Settings,
    // but we can store the theoretical state here if needed.
    
    private init() {}
    
    func resetToDefaults() {
        guard let domain = Bundle.main.bundleIdentifier else { return }
        defaults.removePersistentDomain(forName: domain)
        defaults.synchronize()
        notify()
    }
    
    private func notify() {
        NotificationCenter.default.post(name: Preferences.changedNotification, object: nil)
    }
}
