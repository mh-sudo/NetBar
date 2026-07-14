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
        guard bytesIn > 0 || bytesOut > 0 else { return }

        snapshots.append((date: Date(), bytesIn: bytesIn, bytesOut: bytesOut))
        pruneOldSnapshots()
        saveToDisk()

        DispatchQueue.main.async { [weak self] in
            self?.onUpdate?()
        }
    }

    func usage(for period: UsagePeriod) -> UsageData {
        let now = Date()
        let cutoff: Date
        switch period {
        case .lastHour:  cutoff = now.addingTimeInterval(-3600)
        case .lastDay:   cutoff = now.addingTimeInterval(-86400)
        case .lastWeek:  cutoff = now.addingTimeInterval(-604800)
        case .lastMonth: cutoff = now.addingTimeInterval(-2592000)
        }

        let filtered = snapshots.filter { $0.date >= cutoff }
        guard let oldest = filtered.first, let newest = filtered.last else {
            return UsageData(bytesIn: 0, bytesOut: 0)
        }

        let deltaIn = newest.bytesIn >= oldest.bytesIn ? newest.bytesIn - oldest.bytesIn : 0
        let deltaOut = newest.bytesOut >= oldest.bytesOut ? newest.bytesOut - oldest.bytesOut : 0
        return UsageData(bytesIn: deltaIn, bytesOut: deltaOut)
    }

    var monthlyHistory: [MonthlyUsage] {
        monthlyArchive
            .map { MonthlyUsage(month: $0.key, bytesIn: $0.value.bytesIn, bytesOut: $0.value.bytesOut) }
            .sorted { $0.month > $1.month }
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
                guard let first = sorted.first, let last = sorted.last else { continue }
                let inDelta = last.bytesIn >= first.bytesIn ? last.bytesIn - first.bytesIn : 0
                let outDelta = last.bytesOut >= first.bytesOut ? last.bytesOut - first.bytesOut : 0
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
        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0

        let locked = Preferences.shared.lockedInterface

        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddr) == 0 else { return (0, 0) }
        guard let firstAddr = ifaddr else { return (0, 0) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) == IFF_UP
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK
            if isUp && !isLoopback {
                if ptr.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                    guard let namePtr = ptr.pointee.ifa_name else { continue }
                    let name = String(cString: namePtr)

                    if let locked = locked {
                        if name != locked { continue }
                    } else {
                        if !(strncmp(namePtr, "en", 2) == 0 ||
                             strncmp(namePtr, "utun", 4) == 0 ||
                             strncmp(namePtr, "pdp_ip", 6) == 0) {
                            continue
                        }
                    }

                    if let networkData = ptr.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) {
                        bytesIn += UInt64(networkData.pointee.ifi_ibytes)
                        bytesOut += UInt64(networkData.pointee.ifi_obytes)
                    }
                }
            }
        }

        freeifaddrs(ifaddr)
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
