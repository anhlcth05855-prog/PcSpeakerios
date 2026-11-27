import Foundation
import CoreBluetooth
import Combine

/// Discovered Bluetooth Device Item
public struct BluetoothDeviceItem: Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let rssi: Int
    public let peripheral: CBPeripheral
    
    public init(id: UUID, name: String, rssi: Int, peripheral: CBPeripheral) {
        self.id = id
        self.name = name
        self.rssi = rssi
        self.peripheral = peripheral
    }
}

/// CoreBluetooth Manager for scanning and pairing PC Speaker via Bluetooth
public final class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    public static let shared = BluetoothManager()
    
    @Published public private(set) var isPoweredOn: Bool = false
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var statusMessage: String = "Bluetooth Ready"
    @Published public private(set) var discoveredDevices: [BluetoothDeviceItem] = []
    @Published public private(set) var connectedDeviceName: String? = nil
    
    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    
    public override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }
    
    public func startScanning() {
        guard let central = centralManager, central.state == .poweredOn else {
            statusMessage = "Please turn on Bluetooth in Settings"
            return
        }
        
        isScanning = true
        discoveredDevices.removeAll()
        statusMessage = "Scanning for nearby PCs..."
        
        // Scan for all peripherals with name or PC services
        central.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
    }
    
    public func stopScanning() {
        isScanning = false
        centralManager?.stopScan()
        statusMessage = "Scan stopped"
    }
    
    public func connect(to device: BluetoothDeviceItem) {
        stopScanning()
        statusMessage = "Connecting to \(device.name)..."
        connectedPeripheral = device.peripheral
        device.peripheral.delegate = self
        centralManager?.connect(device.peripheral, options: nil)
    }
    
    public func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        connectedDeviceName = nil
        statusMessage = "Disconnected"
    }
    
    // MARK: - CBCentralManagerDelegate
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            isPoweredOn = true
            statusMessage = "Bluetooth is active"
        case .poweredOff:
            isPoweredOn = false
            statusMessage = "Bluetooth is turned off"
            stopScanning()
        case .unauthorized:
            isPoweredOn = false
            statusMessage = "Bluetooth permission not granted"
        case .unsupported:
            isPoweredOn = false
            statusMessage = "Bluetooth is unsupported on this device"
        default:
            isPoweredOn = false
            statusMessage = "Bluetooth initializing..."
        }
    }
    
    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? peripheral.name
            ?? ""
        
        guard !name.isEmpty else { return }
        
        // Filter or highlight PCs / PC Speaker
        let item = BluetoothDeviceItem(
            id: peripheral.identifier,
            name: name,
            rssi: RSSI.intValue,
            peripheral: peripheral
        )
        
        if !discoveredDevices.contains(where: { $0.id == item.id }) {
            discoveredDevices.append(item)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedDeviceName = peripheral.name ?? "PC Bluetooth Device"
        statusMessage = "Connected to \(connectedDeviceName!)"
        peripheral.discoverServices(nil)
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        statusMessage = "Failed to connect: \(error?.localizedDescription ?? "Unknown error")"
        connectedDeviceName = nil
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        statusMessage = "Disconnected from \(peripheral.name ?? "device")"
        connectedDeviceName = nil
        connectedPeripheral = nil
    }
}
