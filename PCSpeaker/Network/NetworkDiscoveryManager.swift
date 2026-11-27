import Foundation

/// UDP Auto-Discovery Client for finding PC Speaker sender on the local Wi-Fi network
public final class NetworkDiscoveryManager {
    
    private let discoveryPort: UInt16 = 8888
    private var socketFd: Int32 = -1
    private var isSearching: Bool = false
    private var workerQueue = DispatchQueue(label: "com.pcspeaker.discovery", qos: .userInitiated)
    private var probeTimer: DispatchSourceTimer?
    
    public var onDeviceFound: ((DiscoveredPc) -> Void)?
    
    public init() {}
    
    deinit {
        stopDiscovery()
    }
    
    public func startDiscovery() {
        guard !isSearching else { return }
        isSearching = true
        
        workerQueue.async { [weak self] in
            self?.runDiscoveryLoop()
        }
    }
    
    public func stopDiscovery() {
        guard isSearching else { return }
        isSearching = false
        
        probeTimer?.cancel()
        probeTimer = nil
        
        if socketFd >= 0 {
            close(socketFd)
            socketFd = -1
        }
    }
    
    private func runDiscoveryLoop() {
        // Create UDP socket
        socketFd = socket(AF_INET, SOCK_DGRAM, 0)
        guard socketFd >= 0 else {
            print("[NetworkDiscovery] Failed to create socket")
            return
        }
        
        var broadcastEnable: Int32 = 1
        setsockopt(socketFd, SOL_SOCKET, SO_BROADCAST, &broadcastEnable, socklen_t(MemoryLayout<Int32>.size))
        
        var reuseAddr: Int32 = 1
        setsockopt(socketFd, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))
        
        var reusePort: Int32 = 1
        setsockopt(socketFd, SOL_SOCKET, SO_REUSEPORT, &reusePort, socklen_t(MemoryLayout<Int32>.size))
        
        // Bind to port 8888
        var bindAddr = sockaddr_in()
        bindAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        bindAddr.sin_family = sa_family_t(AF_INET)
        bindAddr.sin_port = discoveryPort.bigEndian
        bindAddr.sin_addr.s_addr = INADDR_ANY.bigEndian
        
        let bindResult = withUnsafePointer(to: &bindAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketFd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        if bindResult < 0 {
            print("[NetworkDiscovery] Notice: Could not bind port \(discoveryPort), will rely on probe responses")
        }
        
        // Start periodic probe broadcaster (sending DISCOVER_PC_SPEAKER)
        startProbeTimer()
        
        // Receive buffer
        var buffer = [UInt8](repeating: 0, count: 2048)
        var clientAddr = sockaddr_in()
        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        
        // Set socket receive timeout to 1.5 seconds so loop can cleanly check isSearching
        var timeout = timeval(tv_sec: 1, tv_usec: 500000)
        setsockopt(socketFd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        
        while isSearching && socketFd >= 0 {
            let bytesRead = withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    recvfrom(socketFd, &buffer, buffer.count, 0, $0, &addrLen)
                }
            }
            
            guard bytesRead > 0 else { continue }
            
            let data = Data(buffer[0..<bytesRead])
            guard let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  text.contains("pc-speaker") else { continue }
            
            parseBeacon(data: data, clientAddr: clientAddr)
        }
    }
    
    private func startProbeTimer() {
        let timer = DispatchSource.makeTimerSource(queue: workerQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(600))
        timer.setEventHandler { [weak self] in
            self?.sendProbe()
        }
        timer.resume()
        self.probeTimer = timer
    }
    
    private func sendProbe() {
        guard socketFd >= 0, isSearching else { return }
        
        let probeText = "DISCOVER_PC_SPEAKER"
        guard let data = probeText.data(using: .utf8) else { return }
        
        let broadcastIps = ["255.255.255.255", "192.168.1.255", "192.168.0.255", "172.20.10.15"]
        
        data.withUnsafeBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress else { return }
            for ipStr in broadcastIps {
                var broadcastAddr = sockaddr_in()
                broadcastAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                broadcastAddr.sin_family = sa_family_t(AF_INET)
                broadcastAddr.sin_port = discoveryPort.bigEndian
                broadcastAddr.sin_addr.s_addr = inet_addr(ipStr)
                
                withUnsafePointer(to: &broadcastAddr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        _ = sendto(socketFd, ptr, data.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
            }
        }
    }
    
    private func parseBeacon(data: Data, clientAddr: sockaddr_in) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let service = json["service"] as? String, service == "pc-speaker" else { return }
        
        let name = json["name"] as? String ?? "Windows PC"
        let wsUrl = json["ws_url"] as? String ?? ""
        var ip = json["ip"] as? String ?? ""
        let port = json["port"] as? Int ?? 8080
        
        if ip.isEmpty {
            var addrCopy = clientAddr.sin_addr
            var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            if inet_ntop(AF_INET, &addrCopy, &ipBuffer, socklen_t(INET_ADDRSTRLEN)) != nil {
                ip = String(cString: ipBuffer)
            }
        }
        
        guard !wsUrl.isEmpty else { return }
        
        let discovered = DiscoveredPc(name: name, ip: ip, port: port, wsUrl: wsUrl)
        print("[NetworkDiscovery] Discovered: \(name) @ \(wsUrl)")
        
        DispatchQueue.main.async { [weak self] in
            self?.onDeviceFound?(discovered)
        }
    }
}
