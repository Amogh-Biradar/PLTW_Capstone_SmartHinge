import Foundation
import CoreBluetooth

class BluetoothViewModel: NSObject, ObservableObject {
    @Published var foundDevices: [BluetoothDevice] = []
    @Published var isScanning: Bool = false
    
    private var centralManager: CBCentralManager!
    private var discoveredIdentifiers = Set<UUID>()
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        foundDevices.removeAll()
        discoveredIdentifiers.removeAll()
        isScanning = true
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        }
    }

    private func stopScanning() {
        isScanning = false
        centralManager.stopScan()
    }
}

extension BluetoothViewModel: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Optionally handle state updates.
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let device = BluetoothDevice(identifier: peripheral.identifier, name: peripheral.name ?? "")
        if !discoveredIdentifiers.contains(device.identifier) {
            discoveredIdentifiers.insert(device.identifier)
            DispatchQueue.main.async {
                self.foundDevices.append(device)
            }
        }
    }
}
