import Foundation
import CoreBluetooth
import SwiftUI
import Combine

// MARK: - DiscoveredDevice

public struct DiscoveredDevice: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let rssi: Int?
    
    public init(id: UUID, name: String, rssi: Int?) {
        self.id = id
        self.name = name
        self.rssi = rssi
    }
}

// MARK: - BLEScanning Protocol

@MainActor
public protocol BLEScanning: AnyObject {
    var devices: [DiscoveredDevice] { get }
    func startScanning()
    func stopScanning()
    func connect(to device: DiscoveredDevice)
    
    /// Closure to inform about Bluetooth availability changes
    var bluetoothAvailabilityChanged: ((Bool) -> Void)? { get set }
}

// MARK: - RealBLEScanner for Device Builds

#if !targetEnvironment(simulator)

@MainActor
public final class RealBLEScanner: NSObject, BLEScanning {
    @Published private(set) public var devices: [DiscoveredDevice] = []
    
    private var centralManager: CBCentralManager!
    private var discoveredDevices: [UUID: DiscoveredDevice] = [:]
    private var connectingPeripheral: CBPeripheral?
    
    // Closure to inform about Bluetooth availability changes
    public var bluetoothAvailabilityChanged: ((Bool) -> Void)?
    
    public override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    public func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
    
    public func stopScanning() {
        centralManager.stopScan()
    }
    
    public func connect(to device: DiscoveredDevice) {
        // Find the corresponding CBPeripheral for the device id
        guard let peripheral = centralManager.retrievePeripherals(withIdentifiers: [device.id]).first else {
            return
        }
        connectingPeripheral = peripheral
        centralManager.connect(peripheral, options: nil)
        // Platform-specific connection logic and delegate methods should be implemented here
        // to update connection states and handle connection events.
    }
}

extension RealBLEScanner: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let isAvailable = central.state == .poweredOn
        if isAvailable {
            startScanning()
        } else {
            stopScanning()
            Task { @MainActor in
                devices = []
                discoveredDevices.removeAll()
            }
        }
        // Inform about Bluetooth availability
        bluetoothAvailabilityChanged?(isAvailable)
    }
    
    public func centralManager(_ central: CBCentralManager,
                               didDiscover peripheral: CBPeripheral,
                               advertisementData: [String: Any],
                               rssi RSSI: NSNumber) {
        guard let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String), !name.isEmpty else {
            return
        }
        let id = peripheral.identifier
        let rssiValue = RSSI.intValue
        
        let newDevice = DiscoveredDevice(id: id, name: name, rssi: rssiValue)
        Task { @MainActor in
            discoveredDevices[id] = newDevice
            devices = Array(discoveredDevices.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }
    
    // Implement connection delegate methods here if needed to update BLEScannerViewModel via delegate or closures
}

#else

// MARK: - MockBLEScanner for Simulator

@MainActor
public final class MockBLEScanner: BLEScanning {
    @Published private(set) public var devices: [DiscoveredDevice] = []
    
    private var timer: Timer?
    
    // Closure to inform about Bluetooth availability changes, always true in simulator
    public var bluetoothAvailabilityChanged: ((Bool) -> Void)?
    
    public init() {
        // Immediately notify that Bluetooth is available
        bluetoothAvailabilityChanged?(true)
    }
    
    public func startScanning() {
        devices = []
        // Simulate devices appearing after 1 second
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.devices = [
                    DiscoveredDevice(id: UUID(), name: "Sim Device A", rssi: -60),
                    DiscoveredDevice(id: UUID(), name: "Sim Device B", rssi: -75)
                ]
            }
        }
    }
    
    public func stopScanning() {
        timer?.invalidate()
        timer = nil
        devices = []
    }
    
    public func connect(to device: DiscoveredDevice) {
        // Instantly simulate the device being connected
        // In a real case, you might simulate delays or connection failures as well.
    }
}

#endif

// MARK: - BLEScannerViewModel

@MainActor
public final class BLEScannerViewModel: ObservableObject {
    public enum ConnectionStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case failed(String)
    }
    
    @Published public private(set) var devices: [DiscoveredDevice] = []
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var connectionStatus: ConnectionStatus = .disconnected
    
    /// Tracks the currently connected device ID, if any
    @Published public private(set) var connectedDeviceID: UUID?
    
    /// Indicates if Bluetooth is available (powered on)
    @Published public private(set) var isBluetoothAvailable: Bool = false
    
    private let scanner: BLEScanning
    private var cancellable: AnyCancellable?
    
    public init() {
        #if targetEnvironment(simulator)
        scanner = MockBLEScanner()
        #else
        scanner = RealBLEScanner()
        #endif
        
        // Subscribe to Bluetooth availability changes
        scanner.bluetoothAvailabilityChanged = { [weak self] available in
            Task { @MainActor in
                self?.isBluetoothAvailable = available
                if !available {
                    // If Bluetooth becomes unavailable, stop scanning and reset state
                    self?.stopScanning()
                }
            }
        }
        
        bind()
    }
    
    private func bind() {
        if scanner is any ObservableObject {
            // no direct access to devices publisher, so fallback to polling
            startPolling()
        } else {
            startPolling()
        }
        
        // Prefer subscribing to the Published property if possible
        if let scannerPublished = scanner as? ObservableObjectPublisherProvider {
            cancellable = scannerPublished.devicesPublisher
                .receive(on: DispatchQueue.main)
                .assign(to: \.devices, on: self)
        }
    }
    
    private func startPolling() {
        Task {
            while true {
                await MainActor.run {
                    self.devices = scanner.devices
                }
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
            }
        }
    }
    
    /// Starts scanning if Bluetooth is available
    public func startScanning() {
        guard isBluetoothAvailable else { return }
        isScanning = true
        scanner.startScanning()
        // Clear connection status and connected device on starting a new scan
        connectionStatus = .disconnected
        connectedDeviceID = nil
    }
    
    /// Stops scanning and clears connection state
    public func stopScanning() {
        isScanning = false
        scanner.stopScanning()
        connectionStatus = .disconnected
        connectedDeviceID = nil
    }
    
    public func connect(to device: DiscoveredDevice) {
        guard isBluetoothAvailable else {
            // Cannot connect if Bluetooth not available
            connectionStatus = .failed("Bluetooth is unavailable")
            connectedDeviceID = nil
            return
        }
        
        // Set connectedDeviceID immediately on connect attempt
        connectedDeviceID = device.id
        connectionStatus = .connecting
        
        scanner.connect(to: device)
        
        // For MockBLEScanner simulate instant connection:
        #if targetEnvironment(simulator)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay to simulate connect
            self.connectionStatus = .connected
            // connectedDeviceID is already set above
        }
        #else
        // On real device, connection status updates should come from CBCentralManagerDelegate callbacks
        // and be forwarded to this ViewModel via delegate, closure or Combine.
        #endif
    }
    
    /// Helper to update connectionStatus and reset connectedDeviceID if needed
    private func updateConnectionStatus(_ status: ConnectionStatus) {
        connectionStatus = status
        switch status {
        case .disconnected, .failed:
            connectedDeviceID = nil
        default:
            break
        }
    }
}

protocol ObservableObjectPublisherProvider {
    var devicesPublisher: AnyPublisher<[DiscoveredDevice], Never> { get }
}

#if !targetEnvironment(simulator)
extension RealBLEScanner: ObservableObjectPublisherProvider {
    public var devicesPublisher: AnyPublisher<[DiscoveredDevice], Never> {
        $devices.eraseToAnyPublisher()
    }
}
#endif

#if targetEnvironment(simulator)
extension MockBLEScanner: ObservableObjectPublisherProvider {
    public var devicesPublisher: AnyPublisher<[DiscoveredDevice], Never> {
        $devices.eraseToAnyPublisher()
    }
}
#endif

/*
 Minimal usage example:
 
 struct ContentView: View {
     @StateObject private var viewModel = BLEScannerViewModel()
     
     var body: some View {
         VStack {
             List(viewModel.devices) { device in
                 VStack(alignment: .leading) {
                     Text(device.name).font(.headline)
                     if let rssi = device.rssi {
                         Text("RSSI: \(rssi)")
                             .font(.caption)
                             .foregroundColor(.secondary)
                     }
                 }
                 .onTapGesture {
                     viewModel.connect(to: device)
                 }
             }
             HStack {
                 Button("Start Scanning") {
                     viewModel.startScanning()
                 }
                 Button("Stop Scanning") {
                     viewModel.stopScanning()
                 }
             }
             .padding()
             
             Text("Connection Status: \(String(describing: viewModel.connectionStatus))")
                 .padding()
             
             Text("Bluetooth Available: \(viewModel.isBluetoothAvailable ? "Yes" : "No")")
                 .padding()
         }
     }
 }
 
 */

