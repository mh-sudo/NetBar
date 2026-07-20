import Foundation

/// Shared reader for network interface byte counters and enumeration.
///
/// Consolidates the `getifaddrs` loop that was previously duplicated in
/// `NetworkMonitor`, `DataUsageTracker`, and `SettingsWindowController`.
/// All three now route through this file so the filter rules and counter
/// reads stay in one place.
enum NetworkInterfaceReader {

    /// Read cumulative `(bytesIn, bytesOut)` from `AF_LINK` layer of active,
    /// non-loopback interfaces matching `en*` / `utun*` / `pdp_ip*`.
    ///
    /// - If `locked` names an interface present among the active matching
    ///   interfaces, only that interface is summed.
    /// - If `locked` is non-nil but absent (interface went down / unplugged),
    ///   falls back to summing all matching interfaces for this read so the
    ///   user doesn't see a permanent zero. The preference is not cleared;
    ///   locking resumes automatically when the interface returns.
    /// - If `locked` is nil, sums all matching interfaces.
    static func bytes(locked: String?) -> (bytesIn: UInt64, bytesOut: UInt64) {
        var matching: [(name: String, bytesIn: UInt64, bytesOut: UInt64)] = []
        collect { name, bytesIn, bytesOut in
            matching.append((name, bytesIn, bytesOut))
        }

        if let locked = locked {
            let lockedEntries = matching.filter { $0.name == locked }
            if !lockedEntries.isEmpty {
                var bytesIn: UInt64 = 0
                var bytesOut: UInt64 = 0
                for entry in lockedEntries {
                    bytesIn += entry.bytesIn
                    bytesOut += entry.bytesOut
                }
                return (bytesIn, bytesOut)
            }
            // Locked interface not currently active — fall back to all.
        }

        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
        for entry in matching {
            bytesIn += entry.bytesIn
            bytesOut += entry.bytesOut
        }
        return (bytesIn, bytesOut)
    }

    /// List currently active matching interfaces for the settings dropdown.
    /// First entry is always `("Auto (all interfaces)", nil)`, followed by
    /// sorted friendly-named entries for each active matching interface.
    static func activeInterfaces() -> [(displayName: String, rawName: String?)] {
        var interfaces: [(String, String?)] = [("Auto (all interfaces)", nil)]
        var seen = Set<String>()

        collect { name, _, _ in
            guard !seen.contains(name) else { return }
            seen.insert(name)
            interfaces.append((friendlyName(for: name), name))
        }

        interfaces.sort { a, b in
            if a.1 == nil { return true }
            if b.1 == nil { return false }
            return (a.1 ?? "") < (b.1 ?? "")
        }

        return interfaces
    }

    // MARK: - Private

    /// Enumerate active, non-loopback interfaces matching `en*` / `utun*` /
    /// `pdp_ip*` and invoke `body` once per interface with its name and
    /// cumulative `(bytesIn, bytesOut)` from the `AF_LINK` layer.
    private static func collect(_ body: (String, UInt64, UInt64) -> Void) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) == IFF_UP
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK
            guard isUp && !isLoopback else { continue }
            guard ptr.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) else { continue }
            guard let namePtr = ptr.pointee.ifa_name else { continue }

            let relevant = strncmp(namePtr, "en", 2) == 0 ||
                strncmp(namePtr, "utun", 4) == 0 ||
                strncmp(namePtr, "pdp_ip", 6) == 0
            guard relevant else { continue }

            let name = String(cString: namePtr)

            if let networkData = ptr.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) {
                let bytesIn = UInt64(networkData.pointee.ifi_ibytes)
                let bytesOut = UInt64(networkData.pointee.ifi_obytes)
                body(name, bytesIn, bytesOut)
            }
        }
    }

    private static func friendlyName(for name: String) -> String {
        if name.hasPrefix("en") { return "Network (\(name))" }
        if name.hasPrefix("utun") { return "VPN Tunnel (\(name))" }
        if name.hasPrefix("pdp_ip") { return "Cellular (\(name))" }
        return name
    }
}
