import Foundation
import CoreBluetooth
import Combine

// MARK: - Model for UI
struct DiscoveredPeripheral: Identifiable, Equatable {
    let id: UUID
    let name: String
    fileprivate let peripheral: CBPeripheral

    static func == (lhs: DiscoveredPeripheral, rhs: DiscoveredPeripheral) -> Bool {
        lhs.id == rhs.id
    }
}

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
}

// MARK: - Bluetooth Actuator Controller
final class BluetoothActuatorController: NSObject, ObservableObject {
    // Publish properties for SwiftUI
    @Published var isBluetoothAvailable: Bool = false
    @Published var isScanning: Bool = false
    @Published var devices: [DiscoveredPeripheral] = []
    @Published var connectionState: ConnectionState = .disconnected
    @Published var connectedPeripheralName: String? = nil

    @Published var desiredPosition: Double = 0.0 // 0.0 ... 1.0
    @Published var speed: Double = 1.0 // 0.0 ... 1.0
    
    // CoreBluetooth internals
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?

    // MARK: - Replace these with your actuator's UUIDs
    // If you know the service/characteristics, set them here to speed up discovery.
    // Otherwise, leave nil to discover all and pick the first writable characteristic.
    private let targetServiceUUIDs: [CBUUID]? = nil
    private let targetWriteCharacteristicUUIDs: [CBUUID]? = nil

    override init() {
        super.init()
        // Use the main queue so UI updates are safe without hopping threads.
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Scanning
    func startScan() {
        guard centralManager.state == .poweredOn else { return }
        devices.removeAll()
        isScanning = true
        centralManager.scanForPeripherals(withServices: targetServiceUUIDs, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func stopScan() {
        isScanning = false
        centralManager.stopScan()
    }

    // MARK: - Connection
    func connect(to device: DiscoveredPeripheral) {
        connectionState = .connecting
        centralManager.connect(device.peripheral, options: nil)
    }

    func disconnect() {
        guard let p = connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(p)
    }

    // MARK: - Commands (Replace with your device protocol)
    func extend() {
        // TODO: Replace with your actuator's extend command payload
        sendCommand(Data([0x45])) // 'E'
    }

    func retract() {
        // TODO: Replace with your actuator's retract command payload
        sendCommand(Data([0x52])) // 'R'
    }

    func stopMotion() {
        // TODO: Replace with your actuator's stop command payload
        sendCommand(Data([0x53])) // 'S'
    }

    func setPosition(normalized: Double) {
        // Clamp 0...1
        let clamped = max(0.0, min(1.0, normalized))
        // Example payload: "Pxxx" where xxx is 0...100 percentage
        // TODO: Replace with your actuator's positioning protocol
        let percent = Int((clamped * 100.0).rounded())
        let payload = String(format: "P%03d", percent)
        if let data = payload.data(using: .utf8) {
            sendCommand(data)
        }
    }

    func setSpeed(normalized: Double) {
        // Clamp 0...1
        let clamped = max(0.0, min(1.0, normalized))
        // Example payload: "Vxxx" where xxx is 0...100 percentage
        // TODO: Replace with your actuator's speed protocol
        let percent = Int((clamped * 100.0).rounded())
        let payload = String(format: "V%03d", percent)
        if let data = payload.data(using: .utf8) {
            sendCommand(data)
        }
    }

    // MARK: - Low-level write helper
    private func sendCommand(_ data: Data) {
        guard connectionState == .connected, let peripheral = connectedPeripheral, let characteristic = writeCharacteristic else {
            return
        }
        let props = characteristic.properties
        let type: CBCharacteristicWriteType = props.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        peripheral.writeValue(data, for: characteristic, type: type)
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothActuatorController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothAvailable = (central.state == .poweredOn)
        if central.state != .poweredOn {
            // Reset state if BT turns off
            isScanning = false
            devices.removeAll()
            connectionState = .disconnected
            connectedPeripheral = nil
            connectedPeripheralName = nil
            writeCharacteristic = nil
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? "Unknown"
        let item = DiscoveredPeripheral(id: peripheral.identifier, name: name, peripheral: peripheral)
        if let idx = devices.firstIndex(of: item) {
            devices[idx] = item
        } else {
            devices.append(item)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        connectedPeripheralName = peripheral.name ?? "Device"
        connectionState = .connected
        stopScan()
        peripheral.delegate = self
        // Discover services (filter if known)
        peripheral.discoverServices(targetServiceUUIDs)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionState = .disconnected
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionState = .disconnected
        connectedPeripheral = nil
        connectedPeripheralName = nil
        writeCharacteristic = nil
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothActuatorController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { return }
        guard let services = peripheral.services else { return }
        for service in services {
            // Discover characteristics (filter if known)
            peripheral.discoverCharacteristics(targetWriteCharacteristicUUIDs, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else { return }
        guard let characteristics = service.characteristics else { return }

        // If specific write characteristic UUIDs are provided, prefer them.
        if let targetUUIDs = targetWriteCharacteristicUUIDs {
            if let match = characteristics.first(where: { targetUUIDs.contains($0.uuid) }) {
                writeCharacteristic = match
                return
            }
        }

        // Otherwise, pick the first characteristic that supports writing.
        if let writable = characteristics.first(where: { $0.properties.contains(.write) || $0.properties.contains(.writeWithoutResponse) }) {
            writeCharacteristic = writable
        }
    }
}

