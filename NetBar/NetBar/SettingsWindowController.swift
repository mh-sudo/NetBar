import Cocoa
import ServiceManagement

// MARK: - Minimal Toggle Switch

class ToggleSwitch: NSView {
    var isOn: Bool = false {
        didSet { needsDisplay = true }
    }
    var onToggle: ((Bool) -> Void)?

    private let trackWidth: CGFloat = 40
    private let trackHeight: CGFloat = 22
    private let knobSize: CGFloat = 18

    override var intrinsicContentSize: NSSize {
        return NSSize(width: trackWidth, height: trackHeight)
    }

    override func draw(_ dirtyRect: NSRect) {
        let trackRect = NSRect(
            x: (bounds.width - trackWidth) / 2,
            y: (bounds.height - trackHeight) / 2,
            width: trackWidth,
            height: trackHeight
        )

        let trackPath = NSBezierPath(roundedRect: trackRect, xRadius: trackHeight / 2, yRadius: trackHeight / 2)
        (isOn ? NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0) : NSColor(white: 0.3, alpha: 1.0)).setFill()
        trackPath.fill()

        let knobX = isOn ? trackRect.maxX - knobSize - 2 : trackRect.minX + 2
        let knobRect = NSRect(x: knobX, y: trackRect.minY + 2, width: knobSize, height: knobSize)
        NSColor.white.setFill()
        NSBezierPath(ovalIn: knobRect).fill()
    }

    override func mouseDown(with event: NSEvent) {
        isOn.toggle()
        onToggle?(isOn)
    }
}

// MARK: - Dropdown Row

class DropdownRow: NSView {
    private var popup: NSPopUpButton!

    init(frame: NSRect, items: [String], selectedIndex: Int, onChange: @escaping (Int) -> Void) {
        super.init(frame: frame)

        popup = NSPopUpButton(frame: NSRect(x: bounds.width - 140, y: 0, width: 140, height: 24))
        popup.addItems(withTitles: items)
        popup.selectItem(at: selectedIndex)
        popup.font = NSFont.systemFont(ofSize: 12)
        popup.target = nil
        popup.action = nil
        popup.target = self
        popup.action = #selector(valueChanged)
        addSubview(popup)

        self.onChange = onChange
    }

    required init?(coder: NSCoder) { fatalError() }

    private var onChange: ((Int) -> Void)?

    @objc private func valueChanged() {
        onChange?(popup.indexOfSelectedItem)
    }
}

// MARK: - Settings Window Controller

class SettingsWindowController: NSWindowController {

    private var flagToggle: ToggleSwitch!
    private var arrowsToggle: ToggleSwitch!
    private var singleLineToggle: ToggleSwitch!
    private var ipToggle: ToggleSwitch!
    private var loginToggle: ToggleSwitch!
    private var interfaceDropdown: NSPopUpButton!

    convenience init() {
        let windowWidth: CGFloat = 380
        let windowHeight: CGFloat = 660

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Settings"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(white: 0.11, alpha: 1.0)
        window.center()
        window.level = .floating
        window.appearance = NSAppearance(named: .darkAqua)

        self.init(window: window)
        setupUI(in: window.contentView!)
    }

    private func setupUI(in contentView: NSView) {
        let prefs = Preferences.shared
        let w = contentView.bounds.width
        let padding: CGFloat = 20

        var y: CGFloat = contentView.bounds.height - 50

        // ── App Icon ──
        let iconSize: CGFloat = 56
        let iconView = NSImageView(frame: NSRect(x: (w - iconSize) / 2, y: y - iconSize, width: iconSize, height: iconSize))
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.imageFrameStyle = .none
        contentView.addSubview(iconView)
        y -= iconSize + 8

        // ── App Name ──
        let nameLabel = label("NetBar", size: 14, weight: .semibold, color: .white)
        nameLabel.frame = NSRect(x: 0, y: y - 18, width: w, height: 18)
        nameLabel.alignment = .center
        contentView.addSubview(nameLabel)
        y -= 26

        // ── Version ──
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.2"
        let vLabel = label("v\(version)", size: 11, weight: .regular, color: NSColor(white: 0.5, alpha: 1.0))
        vLabel.frame = NSRect(x: 0, y: y - 14, width: w, height: 14)
        vLabel.alignment = .center
        contentView.addSubview(vLabel)
        y -= 32

        // ── Separator ──
        contentView.addSubview(makeSep(y: y))
        y -= 16

        // ── Appearance Section ──
        let sectionLabel = label("APPEARANCE", size: 10, weight: .medium, color: NSColor(white: 0.45, alpha: 1.0))
        sectionLabel.frame = NSRect(x: padding, y: y - 12, width: 200, height: 12)
        contentView.addSubview(sectionLabel)
        y -= 24

        // Toggles
        flagToggle = addToggle(to: contentView, y: &y, padding: padding, label: "Show Country Flag", isOn: prefs.showFlag) { prefs.showFlag = $0 }
        arrowsToggle = addToggle(to: contentView, y: &y, padding: padding, label: "Show Arrows", isOn: prefs.showArrows) { prefs.showArrows = $0 }
        singleLineToggle = addToggle(to: contentView, y: &y, padding: padding, label: "Single Line", isOn: prefs.useSingleLine) { prefs.useSingleLine = $0 }
        ipToggle = addToggle(to: contentView, y: &y, padding: padding, label: "Show IP Instead of Flag", isOn: prefs.showIPInsteadOfFlag) { prefs.showIPInsteadOfFlag = $0 }

        y -= 8
        contentView.addSubview(makeSep(y: y))
        y -= 16

        // ── Behavior Section ──
        let bLabel = label("BEHAVIOR", size: 10, weight: .medium, color: NSColor(white: 0.45, alpha: 1.0))
        bLabel.frame = NSRect(x: padding, y: y - 12, width: 200, height: 12)
        contentView.addSubview(bLabel)
        y -= 24

        // Login toggle
        loginToggle = addToggle(to: contentView, y: &y, padding: padding, label: "Launch at Login", isOn: SMAppService.mainApp.status == .enabled) { [weak self] isOn in
            self?.handleLoginToggle(isOn)
        }

        // Refresh rate
        y -= 4
        let rLabel = label("Refresh Rate", size: 13, weight: .regular, color: NSColor(white: 0.85, alpha: 1.0))
        rLabel.frame = NSRect(x: padding, y: y - 16, width: 200, height: 16)
        contentView.addSubview(rLabel)

        let refreshIndex = prefs.refreshInterval == 2.0 ? 1 : prefs.refreshInterval == 5.0 ? 2 : 0
        let dropdown = DropdownRow(
            frame: NSRect(x: w - padding - 140, y: y - 22, width: 140, height: 24),
            items: ["1s", "2s", "5s"],
            selectedIndex: refreshIndex
        ) { index in
            prefs.refreshInterval = index == 1 ? 2.0 : index == 2 ? 5.0 : 1.0
        }
        contentView.addSubview(dropdown)
        y -= 36

        // ── Monitoring Section (Interface Lock) ──
        y -= 8
        contentView.addSubview(makeSep(y: y))
        y -= 16

        let monLabel = label("MONITORING", size: 10, weight: .medium, color: NSColor(white: 0.45, alpha: 1.0))
        monLabel.frame = NSRect(x: padding, y: y - 12, width: 200, height: 12)
        contentView.addSubview(monLabel)
        y -= 26

        let intLabel = label("Lock Interface", size: 13, weight: .regular, color: NSColor(white: 0.85, alpha: 1.0))
        intLabel.frame = NSRect(x: padding, y: y - 16, width: 200, height: 16)
        contentView.addSubview(intLabel)

        let interfaces = getMonitoredInterfaces()
        interfaceDropdown = NSPopUpButton(frame: NSRect(x: w - padding - 160, y: y - 22, width: 160, height: 24))
        interfaceDropdown.font = NSFont.systemFont(ofSize: 11)
        for (displayName, rawName) in interfaces {
            let item = NSMenuItem(title: displayName, action: nil, keyEquivalent: "")
            item.representedObject = rawName
            interfaceDropdown.menu?.addItem(item)
        }
        interfaceDropdown.target = self
        interfaceDropdown.action = #selector(interfaceChanged)
        let locked = prefs.lockedInterface
        if let locked = locked {
            for (i, item) in (interfaceDropdown.menu?.items ?? []).enumerated() {
                if item.representedObject as? String == locked {
                    interfaceDropdown.selectItem(at: i)
                    break
                }
            }
        } else {
            interfaceDropdown.selectItem(at: 0)
        }
        contentView.addSubview(interfaceDropdown)
        y -= 42

        // ── Reset Button ──
        y -= 8
        let resetBtn = NSButton(frame: NSRect(x: w - padding - 120, y: y - 28, width: 120, height: 28))
        resetBtn.title = "Reset to Defaults"
        resetBtn.bezelStyle = .rounded
        resetBtn.font = NSFont.systemFont(ofSize: 11)
        resetBtn.target = self
        resetBtn.action = #selector(resetDefaults)
        contentView.addSubview(resetBtn)
        y -= 44

        // ── Footer (clickable link) ──
        let footerField = NSTextField(frame: NSRect(x: 0, y: 8, width: w, height: 16))
        footerField.isEditable = false
        footerField.isBordered = false
        footerField.drawsBackground = false
        footerField.alignment = .center
        let centeredStyle = NSMutableParagraphStyle()
        centeredStyle.alignment = .center
        let prefix = NSMutableAttributedString(string: "An open-source MIT licensed app by ",
            attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: NSColor(white: 0.4, alpha: 1.0),
                .paragraphStyle: centeredStyle
            ])
        let linkAttr = NSMutableAttributedString(string: "MHSUDO",
            attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: NSColor(calibratedRed: 0.2, green: 0.6, blue: 1.0, alpha: 1.0),
                .link: URL(string: "https://github.com/mh-sudo")! as NSURL,
                .cursor: NSCursor.pointingHand,
                .paragraphStyle: centeredStyle
            ])
        prefix.append(linkAttr)
        footerField.attributedStringValue = prefix
        footerField.allowsEditingTextAttributes = true
        footerField.isSelectable = true
        contentView.addSubview(footerField)
    }

    // MARK: - Helpers

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = NSFont.systemFont(ofSize: size, weight: weight)
        l.textColor = color
        l.isEditable = false
        l.isBordered = false
        l.drawsBackground = false
        return l
    }

    private func makeSep(y: CGFloat) -> NSView {
        let sepWidth = window?.contentView?.bounds.width ?? 0
        let sep = NSView(frame: NSRect(x: 0, y: y, width: sepWidth, height: 1))
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.08).cgColor
        return sep
    }

    private func addToggle(to parent: NSView, y: inout CGFloat, padding: CGFloat, label text: String, isOn: Bool, onChange: @escaping (Bool) -> Void) -> ToggleSwitch {
        let l = label(text, size: 13, weight: .regular, color: NSColor(white: 0.88, alpha: 1.0))
        l.frame = NSRect(x: padding + 28, y: y - 14, width: 200, height: 16)
        parent.addSubview(l)

        let toggle = ToggleSwitch(frame: NSRect(x: parent.bounds.width - padding - 44, y: y - 16, width: 40, height: 22))
        toggle.isOn = isOn
        toggle.onToggle = onChange
        parent.addSubview(toggle)
        y -= 32
        return toggle
    }

    // MARK: - Actions

    @objc private func interfaceChanged() {
        let selected = interfaceDropdown.selectedItem?.representedObject as? String
        Preferences.shared.lockedInterface = selected
    }

    // MARK: - Interface list (delegates to NetworkInterfaceReader)
    private func getMonitoredInterfaces() -> [(String, String?)] {
        NetworkInterfaceReader.activeInterfaces()
    }

    private func handleLoginToggle(_ isOn: Bool) {
        do {
            if isOn {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            loginToggle.isOn = SMAppService.mainApp.status == .enabled
        }
    }

    @objc func resetDefaults() {
        let alert = NSAlert()
        alert.messageText = "Reset Settings"
        alert.informativeText = "Reset all settings to defaults?"
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            Preferences.shared.resetToDefaults()
            self.window?.close()
        }
    }
}
