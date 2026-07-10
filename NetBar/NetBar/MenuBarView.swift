import Cocoa

class MenuBarView: NSView {

    // Core data
    private var rawUpload: String = "0 B/s"
    private var rawDownload: String = "0 B/s"
    private var currentFlag: String = "🌐"
    private var currentIP: String = "..."

    private let speedFont: NSFont = NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .regular)
    private let flagFont: NSFont = NSFont.systemFont(ofSize: 14, weight: .regular) // slightly larger for emoji

    // Stable width: only grows, never shrinks, to prevent menu bar icon shifting
    private var cachedWidth: CGFloat = 0

    override init(frame frameRect: NSRect) { super.init(frame: frameRect) }
    required init?(coder: NSCoder) { super.init(coder: coder) }
    
    func updateSpeeds(upload: String, download: String) {
        self.rawUpload = upload
        self.rawDownload = download
        self.needsDisplay = true
    }
    
    func updateFlag(_ flag: String, ip: String) {
        self.currentFlag = flag
        self.currentIP = ip
        self.needsDisplay = true
    }
    
    func calculateOptimalWidth() -> CGFloat {
        let prefs = Preferences.shared

        let upStr = prefs.showArrows ? "\(rawUpload) ↑" : rawUpload
        let downStr = prefs.showArrows ? "\(rawDownload) ↓" : rawDownload
        let upSize = NSAttributedString(string: upStr, attributes: [.font: speedFont]).size()
        let downSize = NSAttributedString(string: downStr, attributes: [.font: speedFont]).size()

        var totalWidth: CGFloat = 8.0 // Left/Right padding baseline

        let showUp = (prefs.displayMode == 0 || prefs.displayMode == 1)
        let showDown = (prefs.displayMode == 0 || prefs.displayMode == 2)

        // Text width container
        if showUp && showDown {
            if prefs.useSingleLine {
                let spaceSize = NSAttributedString(string: "  ", attributes: [.font: speedFont]).size()
                totalWidth += upSize.width + spaceSize.width + downSize.width
            } else {
                totalWidth += max(upSize.width, downSize.width)
            }
        } else if showUp {
            totalWidth += upSize.width
        } else if showDown {
            totalWidth += downSize.width
        }

        // Right side adornment (Flag or IP)
        if prefs.showFlag {
            totalWidth += 4.0 // gap
            if prefs.showIPInsteadOfFlag {
                let ipSize = NSAttributedString(string: currentIP, attributes: [.font: speedFont]).size()
                totalWidth += ipSize.width
            } else {
                let flagSize = NSAttributedString(string: currentFlag, attributes: [.font: flagFont]).size()
                totalWidth += flagSize.width
            }
        }

        // Only grow, never shrink — prevents menu bar icons from shifting
        cachedWidth = max(cachedWidth, totalWidth)
        return cachedWidth
    }

    /// Reset cached width when preferences change (e.g. display mode, arrows toggle)
    func resetCachedWidth() {
        cachedWidth = 0
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let prefs = Preferences.shared
        
        let textColor = NSColor.labelColor
        let speedAttributes: [NSAttributedString.Key: Any] = [.font: speedFont, .foregroundColor: textColor]
        
        let upStr = prefs.showArrows ? "\(rawUpload) ↑" : rawUpload
        let downStr = prefs.showArrows ? "\(rawDownload) ↓" : rawDownload
        
        let upString = NSAttributedString(string: upStr, attributes: speedAttributes)
        let downString = NSAttributedString(string: downStr, attributes: speedAttributes)
        
        let upSize = upString.size()
        let downSize = downString.size()
        
        let viewWidth = self.bounds.width
        let viewHeight = self.bounds.height
        
        var currentRightEdge = viewWidth - 3.0 // Right padding
        
        // 1. Draw Flag or IP on the right (if enabled)
        if prefs.showFlag {
            if prefs.showIPInsteadOfFlag {
                let ipString = NSAttributedString(string: currentIP, attributes: speedAttributes)
                let ipSize = ipString.size()
                let ipY = (viewHeight - ipSize.height) / 2.0
                currentRightEdge -= ipSize.width
                ipString.draw(at: NSPoint(x: currentRightEdge, y: ipY))
            } else {
                let flagAttributes: [NSAttributedString.Key: Any] = [.font: flagFont]
                let flagString = NSAttributedString(string: currentFlag, attributes: flagAttributes)
                let flagSize = flagString.size()
                let flagY = (viewHeight - flagSize.height) / 2.0 + 1.0 // Offset for visual emoji baseline
                currentRightEdge -= flagSize.width
                flagString.draw(at: NSPoint(x: currentRightEdge, y: flagY))
            }
            currentRightEdge -= 4.0 // Gap between right-element and text
        }
        
        // 2. Draw Text Logic
        let showUp = (prefs.displayMode == 0 || prefs.displayMode == 1)
        let showDown = (prefs.displayMode == 0 || prefs.displayMode == 2)
        
        if showUp && showDown {
            if prefs.useSingleLine {
                // Draw inline: Upload [space] Download
                let spaceSize = NSAttributedString(string: "  ", attributes: speedAttributes).size()
                let totalTextWidth = upSize.width + spaceSize.width + downSize.width
                let startX = currentRightEdge - totalTextWidth
                let textY = (viewHeight - upSize.height) / 2.0
                
                upString.draw(at: NSPoint(x: startX, y: textY))
                downString.draw(at: NSPoint(x: startX + upSize.width + spaceSize.width, y: textY))
            } else {
                // Draw stacked (Dual Line)
                let topY: CGFloat = 11.5
                let bottomY: CGFloat = 1.0
                
                let upX = currentRightEdge - upSize.width
                upString.draw(at: NSPoint(x: upX, y: topY))
                
                let downX = currentRightEdge - downSize.width
                downString.draw(at: NSPoint(x: downX, y: bottomY))
            }
        } else if showUp {
            // Only Drawing Upload — vertically center it
            let textY = (viewHeight - upSize.height) / 2.0
            let startX = currentRightEdge - upSize.width
            upString.draw(at: NSPoint(x: startX, y: textY))
        } else if showDown {
            // Only Drawing Download — vertically center it
            let textY = (viewHeight - downSize.height) / 2.0
            let startX = currentRightEdge - downSize.width
            downString.draw(at: NSPoint(x: startX, y: textY))
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        // Pass click to the status item's button so the menu appears
        super.mouseDown(with: event)
        if let menu = self.enclosingMenuItem?.menu {
            menu.popUp(positioning: nil, at: NSPoint.zero, in: self)
        } else {
            // Forward event if wrapped in NSStatusBarButton
            self.nextResponder?.mouseDown(with: event)
        }
    }
}
