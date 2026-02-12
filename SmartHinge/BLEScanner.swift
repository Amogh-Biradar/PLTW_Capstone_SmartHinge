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
}

// MARK: - RealBLEScanner for Device Builds

#if !targetEnvironment(simulator)

@MainActor
public final class RealBLEScanner: NSObject, BLEScanning {
    @Published private(set) public var devices: [DiscoveredDevice] = []
    
    private var centralManager: CBCentralManager!
    private var discoveredDevices: [UUID: DiscoveredDevice] = [:]
    
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
}

extension RealBLEScanner: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScanning()
        } else {
            stopScanning()
            Task { @MainActor in
                devices = []
                discoveredDevices.removeAll()
            }
        }
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
}

#else

// MARK: - MockBLEScanner for Simulator

@MainActor
public final class MockBLEScanner: BLEScanning {
    @Published private(set) public var devices: [DiscoveredDevice] = []
    
    private var timer: Timer?
    
    public init() {}
    
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
}

#endif

// MARK: - BLEScannerViewModel

@MainActor
public final class BLEScannerViewModel: ObservableObject {
    @Published public private(set) var devices: [DiscoveredDevice] = []
    @Published public private(set) var isScanning: Bool = false
    
    private let scanner: BLEScanning
    private var cancellable: AnyCancellable?
    
    public init() {
        #if targetEnvironment(simulator)
        scanner = MockBLEScanner()
        #else
        scanner = RealBLEScanner()
        #endif
        
        bind()
    }
    
    private func bind() {
        if let publisher = (scanner as? ObservableObject)?.objectWillChange {
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
    
    public func startScanning() {
        isScanning = true
        scanner.startScanning()
    }
    
    public func stopScanning() {
        isScanning = false
        scanner.stopScanning()
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
         }
     }
 }
 
 */

