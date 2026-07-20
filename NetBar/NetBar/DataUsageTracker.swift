import Foundation

enum UsagePeriod {
    case lastHour, lastDay, lastWeek, lastMonth
}

struct UsageData {
    let bytesIn: UInt64
    let bytesOut: UInt64
    var total: UInt64 { bytesIn + bytesOut }
}

struct MonthlyUsage {
    let month: String
    let bytesIn: UInt64
    let bytesOut: UInt64
    var total: UInt64 { bytesIn + bytesOut }
}

class DataUsageTracker {

    var onUpdate: (() -> Void)?

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "netbar.datausage")
    private var snapshots: [(date: Date, bytesIn: UInt64, bytesOut: UInt64)] = []
    private var monthlyArchive: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent("NetBar")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("usage.json")
        loadFromDisk()
    }

    func start() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 5, repeating: 180)
        t.setEventHandler { [weak self] in
            self?.tick()
        }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        let (bytesIn, bytesOut) = getNetworkBytes()
        // Record a baseline snapshot even when zero (e.g. right after reboot),
        // so the first interval after a reset has a starting point. Skip only
        // if both counters are zero AND we already have recent snapshots —
        // otherwise we'd miss the legitimate "all-zero baseline" tick.
        snapshots.append((date: Date(), bytesIn: bytesIn, bytesOut: bytesOut))
        pruneOldSnapshots()
        saveToDisk()

        DispatchQueue.main.async { [weak self] in
            self?.onUpdate?()
        }
    }

    func usage(for period: UsagePeriod) -> UsageData {
        // Serialize against the writer (tick() / pruneOldSnapshots() run on
        // `queue`). Reads are cheap (filter + small array iterate), so a
        // blocking sync is fine and prevents the data race where the main
        // thread iterates an array being mutated on the background queue.
        queue.sync {
            let now = Date()
            let cutoff: Date
            switch period {
            case .lastHour:  cutoff = now.addingTimeInterval(-3600)
            case .lastDay:   cutoff = now.addingTimeInterval(-86400)
            case .lastWeek:  cutoff = now.addingTimeInterval(-604800)
            case .lastMonth: cutoff = now.addingTimeInterval(-2592000)
            }

            let filtered = snapshots.filter { $0.date >= cutoff }
            guard filtered.count >= 2 else {
                return UsageData(bytesIn: 0, bytesOut: 0)
            }

            // Pair-wise delta accumulation across the period. When a counter
            // reset happens mid-period (reboot / sleep / interface re-init),
            // the snapshot after the reset is treated as the new baseline for
            // the next interval — we attribute its reading to that interval
            // instead of zeroing the entire period's usage.
            var deltaIn: UInt64 = 0
            var deltaOut: UInt64 = 0
            for i in 1..<filtered.count {
                let prev = filtered[i - 1]
                let cur = filtered[i]
                deltaIn  += cur.bytesIn  < prev.bytesIn  ? cur.bytesIn  : cur.bytesIn  - prev.bytesIn
                deltaOut += cur.bytesOut < prev.bytesOut ? cur.bytesOut : cur.bytesOut - prev.bytesOut
            }
            return UsageData(bytesIn: deltaIn, bytesOut: deltaOut)
        }
    }

    var monthlyHistory: [MonthlyUsage] {
        // Serialize against the writer for the same reason as usage(for:).
        queue.sync {
            monthlyArchive
                .map { MonthlyUsage(month: $0.key, bytesIn: $0.value.bytesIn, bytesOut: $0.value.bytesOut) }
                .sorted { $0.month > $1.month }
        }
    }

    // MARK: - Pruning

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()

    private func pruneOldSnapshots() {
        let cutoff = Date().addingTimeInterval(-2764800) // 32 days
        let toArchive = snapshots.filter { $0.date < cutoff }

        if !toArchive.isEmpty {
            let grouped = Dictionary(grouping: toArchive) { Self.monthFormatter.string(from: $0.date) }
            let currentMonthKey = Self.monthFormatter.string(from: Date())

            for (monthKey, monthSnapshots) in grouped {
                guard monthKey != currentMonthKey else { continue }
                let sorted = monthSnapshots.sorted { $0.date < $1.date }
                guard sorted.count >= 2 else { continue }

                // Pair-wise delta accumulation across the month. Same
                // counter-reset handling as usage(for:): a reset mid-month
                // doesn't zero the whole month; the snapshot after the reset
                // contributes its own reading to that interval.
                var inDelta: UInt64 = 0
                var outDelta: UInt64 = 0
                for i in 1..<sorted.count {
                    let prev = sorted[i - 1]
                    let cur = sorted[i]
                    inDelta  += cur.bytesIn  < prev.bytesIn  ? cur.bytesIn  : cur.bytesIn  - prev.bytesIn
                    outDelta += cur.bytesOut < prev.bytesOut ? cur.bytesOut : cur.bytesOut - prev.bytesOut
                }
                if inDelta > 0 || outDelta > 0 {
                    monthlyArchive[monthKey] = (bytesIn: inDelta, bytesOut: outDelta)
                }
            }
        }

        snapshots = snapshots.filter { $0.date >= cutoff }

        if monthlyArchive.count > 12 {
            let sortedKeys = monthlyArchive.keys.sorted()
            for key in sortedKeys.prefix(monthlyArchive.count - 12) {
                monthlyArchive.removeValue(forKey: key)
            }
        }
    }

    // MARK: - Network Bytes

    private func getNetworkBytes() -> (UInt64, UInt64) {
        let (bytesIn, bytesOut) = NetworkInterfaceReader.bytes(locked: Preferences.shared.lockedInterface)
        return (bytesIn, bytesOut)
    }

    // MARK: - Persistence

    private struct SnapshotEntry: Codable {
        let t: Double
        let i: UInt64
        let o: UInt64
    }

    private struct MonthlyEntry: Codable {
        let i: UInt64
        let o: UInt64
    }

    private struct StorageFormat: Codable {
        var version: Int
        var snapshots: [SnapshotEntry]
        var monthly: [String: MonthlyEntry]
    }

    private func saveToDisk() {
        let entries = snapshots.map { SnapshotEntry(t: $0.date.timeIntervalSince1970, i: $0.bytesIn, o: $0.bytesOut) }
        let monthlyDict = monthlyArchive.mapValues { MonthlyEntry(i: $0.bytesIn, o: $0.bytesOut) }
        let storage = StorageFormat(version: 1, snapshots: entries, monthly: monthlyDict)

        do {
            let data = try JSONEncoder().encode(storage)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[DataUsageTracker] save error: \(error)")
        }
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let storage = try JSONDecoder().decode(StorageFormat.self, from: data)
            snapshots = storage.snapshots.map {
                (date: Date(timeIntervalSince1970: $0.t), bytesIn: $0.i, bytesOut: $0.o)
            }
            monthlyArchive = storage.monthly.mapValues { (bytesIn: $0.i, bytesOut: $0.o) }
        } catch {
            print("[DataUsageTracker] load error: \(error)")
        }
    }
}
