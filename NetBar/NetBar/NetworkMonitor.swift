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
        
        // Calculate deltas (handle counter wrap or network reset gracefully)
        let deltaIn = currentIn >= lastBytesIn ? currentIn - lastBytesIn : 0
        let deltaOut = currentOut >= lastBytesOut ? currentOut - lastBytesOut : 0
        
        lastBytesIn = currentIn
        lastBytesOut = currentOut
        
        let formattedIn = formatSpeed(deltaIn)
        let formattedOut = formatSpeed(deltaOut)
        
        DispatchQueue.main.async { [weak self] in
            self?.onSpeedUpdate?(formattedOut, formattedIn) // Note: up (out), down (in)
        }
    }
    
    // Reads bytes using getifaddrs
    private func getNetworkBytes() -> (UInt64, UInt64) {
        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
        
        let locked = Preferences.shared.lockedInterface
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddr) == 0 else { return (0, 0) }
        guard let firstAddr = ifaddr else { return (0, 0) }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            
            // Filter only active, non-loopback interfaces
            let isUp = (flags & IFF_UP) == IFF_UP
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK
            
            if isUp && !isLoopback {
                let addrFamily = ptr.pointee.ifa_addr.pointee.sa_family
                
                // Read from AF_LINK layer which contains standard network stats
                if addrFamily == UInt8(AF_LINK) {
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
                    
                    // Cast ifa_data to if_data
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
