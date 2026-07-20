import Cocoa

class PeriodButton: NSView {
    var isSelected: Bool = false { didSet { needsDisplay = true } }
    var title: String = ""
    var onTap: (() -> Void)?

    override init(frame: NSRect) { super.init(frame: frame) }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5)
        if isSelected {
            NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0).setFill()
        } else {
            NSColor(white: 0.25, alpha: 1.0).setFill()
        }
        path.fill()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: isSelected ? NSColor.white : NSColor(white: 0.6, alpha: 1.0)
        ]
        let size = NSAttributedString(string: title, attributes: attrs).size()
        let rect = NSRect(x: (bounds.width - size.width) / 2,
                          y: (bounds.height - size.height) / 2,
                          width: size.width, height: size.height)
        NSAttributedString(string: title, attributes: attrs).draw(in: rect)
    }

    override func mouseDown(with event: NSEvent) { onTap?() }
}

class DataUsageWindowController: NSWindowController {

    private var tracker: DataUsageTracker!
    private var selectedPeriod: UsagePeriod = .lastMonth
    private var periodButtons: [PeriodButton] = []
    private var buttonPeriods: [UsagePeriod] = [.lastHour, .lastDay, .lastWeek, .lastMonth]

    private var uploadValueLabel: NSTextField!
    private var downloadValueLabel: NSTextField!
    private var totalLabel: NSTextField!
    private var scrollDocView: NSView!

    convenience init(tracker: DataUsageTracker) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 640),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Data Usage"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(white: 0.11, alpha: 1.0)
        window.center()
        window.level = .floating
        window.appearance = NSAppearance(named: .darkAqua)

        self.init(window: window)
        self.tracker = tracker

        tracker.onUpdate = { [weak self] in
            DispatchQueue.main.async { self?.refreshUI() }
        }

        setupUI(in: window.contentView!)
        refreshUI()
    }

    private func setupUI(in contentView: NSView) {
        let w = contentView.bounds.width
        let padding: CGFloat = 20
        var y: CGFloat = contentView.bounds.height - 44

        let iconSize: CGFloat = 48
        let iconView = NSImageView(frame: NSRect(x: (w - iconSize)/2, y: y - iconSize, width: iconSize, height: iconSize))
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(iconView)
        y -= iconSize + 6

        let titleLabel = lbl("Data Usage", size: 14, weight: .semibold, color: .white)
        titleLabel.frame = NSRect(x: 0, y: y - 18, width: w, height: 18)
        titleLabel.alignment = .center
        contentView.addSubview(titleLabel)
        y -= 28

        contentView.addSubview(sep(y: y, w: w))
        y -= 20

        let periods: [(String, UsagePeriod)] = [("1H", .lastHour), ("1D", .lastDay), ("1W", .lastWeek), ("1M", .lastMonth)]
        let btnW: CGFloat = 70
        let gap: CGFloat = 6
        let totalW = CGFloat(periods.count) * btnW + CGFloat(periods.count - 1) * gap
        let startX = (w - totalW) / 2

        for (idx, (title, period)) in periods.enumerated() {
            let btn = PeriodButton(frame: NSRect(x: startX + CGFloat(idx) * (btnW + gap), y: y - 24, width: btnW, height: 24))
            btn.title = title
            btn.isSelected = period == selectedPeriod
            btn.onTap = { [weak self] in
                self?.selectPeriod(period)
            }
            contentView.addSubview(btn)
            periodButtons.append(btn)
        }
        y -= 40

        contentView.addSubview(sep(y: y, w: w))
        y -= 20

        let uploadIcon = lbl("▲", size: 12, weight: .regular, color: NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0))
        uploadIcon.frame = NSRect(x: padding, y: y - 14, width: 16, height: 16)
        contentView.addSubview(uploadIcon)

        let uploadText = lbl("Upload", size: 12, weight: .regular, color: NSColor(white: 0.85, alpha: 1.0))
        uploadText.frame = NSRect(x: padding + 18, y: y - 14, width: 50, height: 16)
        contentView.addSubview(uploadText)

        uploadValueLabel = lbl("—", size: 11, weight: .medium, color: NSColor(white: 0.85, alpha: 1.0))
        uploadValueLabel.frame = NSRect(x: w - padding - 68, y: y - 14, width: 68, height: 16)
        uploadValueLabel.alignment = .right
        contentView.addSubview(uploadValueLabel)
        y -= 26

        let downloadIcon = lbl("▼", size: 12, weight: .regular, color: NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0))
        downloadIcon.frame = NSRect(x: padding, y: y - 14, width: 16, height: 16)
        contentView.addSubview(downloadIcon)

        let downloadText = lbl("Download", size: 12, weight: .regular, color: NSColor(white: 0.85, alpha: 1.0))
        downloadText.frame = NSRect(x: padding + 18, y: y - 14, width: 58, height: 16)
        contentView.addSubview(downloadText)

        downloadValueLabel = lbl("—", size: 11, weight: .medium, color: NSColor(white: 0.85, alpha: 1.0))
        downloadValueLabel.frame = NSRect(x: w - padding - 68, y: y - 14, width: 68, height: 16)
        downloadValueLabel.alignment = .right
        contentView.addSubview(downloadValueLabel)
        y -= 32

        contentView.addSubview(sep(y: y, w: w))
        y -= 16

        totalLabel = lbl("Total: —", size: 12, weight: .semibold, color: .white)
        totalLabel.frame = NSRect(x: padding, y: y - 16, width: w - padding * 2, height: 16)
        contentView.addSubview(totalLabel)
        y -= 24

        contentView.addSubview(sep(y: y, w: w))
        y -= 16

        let mhLabel = lbl("MONTHLY HISTORY", size: 10, weight: .medium, color: NSColor(white: 0.45, alpha: 1.0))
        mhLabel.frame = NSRect(x: padding, y: y - 12, width: 200, height: 12)
        contentView.addSubview(mhLabel)
        y -= 24

        let scrollFrame = NSRect(x: padding, y: 8, width: w - padding * 2, height: y - 8)
        let scrollView = NSScrollView(frame: scrollFrame)
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        scrollDocView = NSView(frame: NSRect(x: 0, y: 0, width: scrollFrame.width, height: scrollFrame.height))
        scrollDocView.wantsLayer = true
        scrollView.documentView = scrollDocView
        contentView.addSubview(scrollView)
    }

    private func selectPeriod(_ period: UsagePeriod) {
        selectedPeriod = period
        for (idx, btn) in periodButtons.enumerated() {
            btn.isSelected = buttonPeriods[idx] == period
        }
        refreshUI()
    }

    private func refreshUI() {
        let data = tracker.usage(for: selectedPeriod)
        uploadValueLabel.stringValue = formatBytes(data.bytesOut)
        downloadValueLabel.stringValue = formatBytes(data.bytesIn)
        totalLabel.stringValue = "Total: \(formatBytes(data.total))"

        buildMonthlyList()
    }

    private func buildMonthlyList() {
        scrollDocView.subviews.forEach { $0.removeFromSuperview() }

        let history = tracker.monthlyHistory
        guard !history.isEmpty else {
            let noData = lbl("No monthly data yet", size: 11, weight: .regular, color: NSColor(white: 0.4, alpha: 1.0))
            noData.frame = NSRect(x: 0, y: scrollDocView.bounds.height - 20, width: scrollDocView.bounds.width, height: 14)
            noData.alignment = .center
            scrollDocView.addSubview(noData)
            return
        }

        let rowHeight: CGFloat = 26
        let totalH = CGFloat(history.count) * rowHeight
        let visibleH = scrollDocView.superview?.bounds.height ?? scrollDocView.bounds.height
        scrollDocView.frame.size.height = max(totalH, visibleH)

        let displayMonth: (String) -> String = { raw in
            let parts = raw.split(separator: "-")
            guard parts.count == 2 else { return raw }
            let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            let idx = Int(parts[1]) ?? 1
            return "\(months[max(0, min(idx - 1, 11))]) \(parts[0])"
        }

        for (i, month) in history.enumerated() {
            let yPos = scrollDocView.bounds.height - CGFloat(i + 1) * rowHeight

            let nameLabel = lbl(displayMonth(month.month), size: 11, weight: .semibold, color: NSColor(white: 0.85, alpha: 1.0))
            nameLabel.frame = NSRect(x: 4, y: yPos + 6, width: 58, height: 14)
            scrollDocView.addSubview(nameLabel)

            let upArrow = lbl("▲", size: 9, weight: .regular, color: NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0))
            upArrow.frame = NSRect(x: 66, y: yPos + 7, width: 10, height: 12)
            scrollDocView.addSubview(upArrow)

            let upVal = lbl(formatBytes(month.bytesOut), size: 10, weight: .regular, color: NSColor(white: 0.7, alpha: 1.0))
            upVal.frame = NSRect(x: 78, y: yPos + 6, width: 64, height: 14)
            scrollDocView.addSubview(upVal)

            let downArrow = lbl("▼", size: 9, weight: .regular, color: NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0))
            downArrow.frame = NSRect(x: 146, y: yPos + 7, width: 10, height: 12)
            scrollDocView.addSubview(downArrow)

            let downVal = lbl(formatBytes(month.bytesIn), size: 10, weight: .regular, color: NSColor(white: 0.7, alpha: 1.0))
            downVal.frame = NSRect(x: 158, y: yPos + 6, width: 64, height: 14)
            scrollDocView.addSubview(downVal)

            let totalVal = lbl(formatBytes(month.total), size: 10, weight: .medium, color: NSColor(white: 0.6, alpha: 1.0))
            totalVal.frame = NSRect(x: scrollDocView.bounds.width - 68, y: yPos + 6, width: 68, height: 14)
            totalVal.alignment = .right
            scrollDocView.addSubview(totalVal)
        }
    }

    // MARK: - Helpers

    private func lbl(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = NSFont.systemFont(ofSize: size, weight: weight)
        l.textColor = color
        return l
    }

    private func sep(y: CGFloat, w: CGFloat) -> NSView {
        let s = NSView(frame: NSRect(x: 0, y: y, width: w, height: 1))
        s.wantsLayer = true
        s.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.08).cgColor
        return s
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let b = Double(bytes)
        if b < 1024 {
            return "\(Int(b)) B"
        } else if b < 1_048_576 {
            return String(format: "%.1f KB", b / 1024)
        } else if b < 1_073_741_824 {
            return String(format: "%.1f MB", b / 1_048_576)
        } else if b < 1_099_511_627_776 {
            return String(format: "%.1f GB", b / 1_073_741_824)
        } else {
            return String(format: "%.1f TB", b / 1_099_511_627_776)
        }
    }
}
