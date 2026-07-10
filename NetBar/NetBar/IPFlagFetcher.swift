import Foundation

class IPFlagFetcher {
    // Passes back (FlagEmoji, IPString)
    var onUpdate: ((String, String) -> Void)?
    
    // Cache last known
    private var lastFlag: String = "🌐"
    private var lastIP: String = "Unknown IP"
    
    // Generation counter to discard stale in-flight responses
    private var fetchGeneration: Int = 0
    
    // Ephemeral session — zero URL caching, no cookies, no disk persistence
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        config.timeoutIntervalForResource = 15
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()
    
    // Multiple IP APIs for redundancy — if one fails/times out through a VPN, another will work.
    // Each provider has a URL and a closure to extract (ip, countryCode) from the JSON response.
    private struct IPProvider {
        let url: String
        let parse: ([String: Any]) -> (ip: String, country: String)?
    }
    
    private let providers: [IPProvider] = [
        // ip-api.com — fast, reliable, uses HTTP (avoids some VPN TLS issues)
        IPProvider(url: "http://ip-api.com/json/?fields=query,countryCode") { json in
            guard let ip = json["query"] as? String,
                  let code = json["countryCode"] as? String else { return nil }
            return (ip, code)
        },
        // ipapi.co — HTTPS
        IPProvider(url: "https://ipapi.co/json/") { json in
            guard let ip = json["ip"] as? String,
                  let code = json["country_code"] as? String else { return nil }
            return (ip, code)
        },
        // api.country.is — HTTPS (the original)
        IPProvider(url: "https://api.country.is/") { json in
            guard let ip = json["ip"] as? String,
                  let code = json["country"] as? String else { return nil }
            return (ip, code)
        },
        // ipinfo.io — HTTPS
        IPProvider(url: "https://ipinfo.io/json") { json in
            guard let ip = json["ip"] as? String,
                  let code = json["country"] as? String else { return nil }
            return (ip, code)
        },
        // ipwho.is — HTTPS
        IPProvider(url: "https://ipwho.is/") { json in
            guard let ip = json["ip"] as? String,
                  let code = json["country_code"] as? String else { return nil }
            return (ip, code)
        },
    ]

    /// Standard fetch — just get the current IP once.
    func fetch() {
        fetchGeneration += 1
        performFetch(generation: fetchGeneration)
    }
    
    /// Fetch with retries — used after a network change (VPN connect/disconnect).
    /// Fetches immediately first, then retries up to `maxRetries` times
    /// with increasing delays to give the VPN tunnel time to fully establish routing.
    func fetchWithRetry(maxRetries: Int = 4) {
        fetchGeneration += 1
        let gen = fetchGeneration
        let previousIP = lastIP
        // Fetch immediately — no initial delay
        performFetchWithRetry(generation: gen, previousIP: previousIP, retriesLeft: maxRetries, delay: 0)
    }

    private func performFetchWithRetry(generation: Int, previousIP: String, retriesLeft: Int, delay: TimeInterval) {
        // Bail if a newer fetch has been started
        guard generation == fetchGeneration else { return }

        // If delay > 0, wait before fetching; otherwise fetch immediately
        let work = { [weak self] in
            guard let self = self, generation == self.fetchGeneration else { return }
            self.performFetch(generation: generation) { [weak self] newIP in
                guard let self = self, generation == self.fetchGeneration else { return }

                // If IP changed or no retries left, we're done
                if newIP != previousIP || retriesLeft <= 0 {
                    return
                }

                // IP hasn't changed yet — the VPN routing may not be fully settled.
                // Retry after an increasing delay.
                let nextDelay = min(delay * 1.5 + 1.0, 10.0)
                DispatchQueue.main.asyncAfter(deadline: .now() + nextDelay) { [weak self] in
                    guard let self = self, generation == self.fetchGeneration else { return }
                    self.performFetchWithRetry(generation: generation, previousIP: previousIP, retriesLeft: retriesLeft - 1, delay: nextDelay)
                }
            }
        }

        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        } else {
            work()
        }
    }

    /// Try all IP providers concurrently. The first one to succeed wins.
    private func performFetch(generation: Int, completion: ((String) -> Void)? = nil) {
        let resultLock = NSLock()
        var hasResult = false
        
        // Track how many providers have finished (to know when ALL have failed)
        var finishedCount = 0
        let totalProviders = providers.count
        
        for provider in providers {
            guard let url = URL(string: provider.url) else {
                resultLock.lock()
                finishedCount += 1
                resultLock.unlock()
                continue
            }
            
            var request = URLRequest(url: url)
            request.setValue("NetBar/1.1", forHTTPHeaderField: "User-Agent")
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.setValue("no-cache, no-store", forHTTPHeaderField: "Cache-Control")
            request.setValue("no-cache", forHTTPHeaderField: "Pragma")
            request.timeoutInterval = 12
            
            let task = session.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else { return }
                
                // Discard if a newer fetch was started
                guard generation == self.fetchGeneration else { return }
                
                resultLock.lock()
                
                // If another provider already returned a result, skip
                if hasResult {
                    resultLock.unlock()
                    return
                }
                
                // Check for errors
                if error != nil {
                    finishedCount += 1
                    let allFailed = finishedCount >= totalProviders
                    resultLock.unlock()
                    
                    if allFailed {
                        // All providers failed — dispatch with cached values
                        self.dispatchUpdate()
                        completion?(self.lastIP)
                    }
                    return
                }
                
                guard let data = data else {
                    finishedCount += 1
                    let allFailed = finishedCount >= totalProviders
                    resultLock.unlock()
                    
                    if allFailed {
                        self.dispatchUpdate()
                        completion?(self.lastIP)
                    }
                    return
                }
                
                // Try to parse
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let result = provider.parse(json) {
                        hasResult = true
                        self.lastIP = result.ip
                        self.lastFlag = self.countryCodeToEmoji(result.country)
                        resultLock.unlock()
                        
                        self.dispatchUpdate()
                        completion?(self.lastIP)
                        return
                    }
                } catch {
                    // Parse failed
                }
                
                finishedCount += 1
                let allFailed = finishedCount >= totalProviders
                resultLock.unlock()
                
                if allFailed {
                    self.dispatchUpdate()
                    completion?(self.lastIP)
                }
            }
            task.resume()
        }
    }
    
    private func dispatchUpdate() {
        let flag = self.lastFlag
        let ip = self.lastIP
        DispatchQueue.main.async {
            self.onUpdate?(flag, ip)
        }
    }
    
    private func countryCodeToEmoji(_ code: String) -> String {
        let base: UInt32 = 127397
        var scalarView = String.UnicodeScalarView()
        let safeCode = String(code.prefix(2))
        for scalar in safeCode.uppercased().unicodeScalars {
            if let newScalar = UnicodeScalar(base + scalar.value) {
                scalarView.append(newScalar)
            }
        }
        return String(scalarView)
    }
}
