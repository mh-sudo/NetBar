import Foundation

class NetworkMonitor {
    
    // Callback to pass formatted strings (e.g. "12 KB/s", "4 MB/s")
    var onSpeedUpdate: ((String, String) -> Void)?
    
    // Timer using DispatchSource for background execution
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "netbar.networkmonitor")
    
    // Previous byte counts
    private var lastBytesIn: UInt64 = 0
    private var lastBytesOut: UInt64 = 0
    private var isFirstTick = true

    func start(interval: Double = 1.0) {
        // Attempt to fetch initial bytes right away to get a baseline
        let (initialIn, initialOut) = getNetworkBytes()
        lastBytesIn = initialIn
        lastBytesOut = initialOut
        
        // Send initial 0 B/s
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onSpeedUpdate?(self.formatSpeed(0), self.formatSpeed(0))
        }
        isFirstTick = false
        
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + interval, repeating: interval)
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
        let (currentIn, currentOut) = getNetworkBytes()

        // Counter-reset handling: if the current reading is lower than the
        // previous one, the interface counters were reset (reboot, sleep/wake,
        // interface re-init). The pre-reset portion of this interval is
        // unknowable, so treat the current reading as the new baseline going
        // forward and attribute the current reading itself to this interval
        // (preserves accumulated bytes instead of discarding them).
        let deltaIn = currentIn >= lastBytesIn ? currentIn - lastBytesIn : currentIn
        let deltaOut = currentOut >= lastBytesOut ? currentOut - lastBytesOut : currentOut

        lastBytesIn = currentIn
        lastBytesOut = currentOut

        let formattedIn = formatSpeed(deltaIn)
        let formattedOut = formatSpeed(deltaOut)

        DispatchQueue.main.async { [weak self] in
            self?.onSpeedUpdate?(formattedOut, formattedIn) // Note: up (out), down (in)
        }
    }
    
    // Reads bytes via the shared NetworkInterfaceReader
    private func getNetworkBytes() -> (UInt64, UInt64) {
        let (bytesIn, bytesOut) = NetworkInterfaceReader.bytes(locked: Preferences.shared.lockedInterface)
        return (bytesIn, bytesOut)
    }
    
    private func formatSpeed(_ bytes: UInt64) -> String {
        let b = Double(bytes)
        if b < 1000 {
            return String(format: "%.0f B/s", b)
        } else if b < 1_000_000 {
            return String(format: "%.1f KB/s", b / 1000)
        } else if b < 1_000_000_000 {
            return String(format: "%.1f MB/s", b / 1_000_000)
        } else {
            return String(format: "%.1f GB/s", b / 1_000_000_000)
        }
    }
}
