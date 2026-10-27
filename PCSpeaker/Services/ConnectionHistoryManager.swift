import Foundation

/// Manages persistence of previously connected PCs
public enum ConnectionHistoryManager {
    
    private static let userDefaultsKey = "pcspeaker_connection_history"
    private static let maxEntries = 20
    
    public static func loadAll() -> [ConnectionHistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return []
        }
        do {
            let items = try JSONDecoder().decode([ConnectionHistoryItem].self, from: data)
            return items.sorted { $0.connectedAt > $1.connectedAt }
        } catch {
            print("[ConnectionHistory] Error decoding history: \(error.localizedDescription)")
            return []
        }
    }
    
    public static func record(pcName: String, ip: String, wsUrl: String) {
        var existing = loadAll()
        existing.removeAll { $0.wsUrl == wsUrl }
        
        let newItem = ConnectionHistoryItem(
            pcName: pcName.isEmpty ? "PC Sender" : pcName,
            ip: ip,
            wsUrl: wsUrl,
            connectedAt: Date()
        )
        existing.insert(newItem, at: 0)
        
        let trimmed = Array(existing.prefix(maxEntries))
        save(items: trimmed)
    }
    
    public static func delete(wsUrl: String) {
        var existing = loadAll()
        existing.removeAll { $0.wsUrl == wsUrl }
        save(items: existing)
    }
    
    public static func clearAll() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
    
    private static func save(items: [ConnectionHistoryItem]) {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("[ConnectionHistory] Error encoding history: \(error.localizedDescription)")
        }
    }
}
