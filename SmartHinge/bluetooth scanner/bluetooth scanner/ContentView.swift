//
//  ContentView.swift
//  bluetooth scanner
//
//  Created by AmoghB on 2/23/26.
//

import SwiftUI
import CoreBluetooth
import Combine

struct ContentView: View {
    @StateObject private var bluetoothVM = BluetoothViewModel()
    
    var body: some View {
        VStack {
            Button(action: {
                bluetoothVM.startScanning()
            }) {
                Text(bluetoothVM.isScanning ? "Scanning..." : "Scan for Devices")
                    .padding()
                    .background(bluetoothVM.isScanning ? Color.gray : Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(8)
            }
            .disabled(bluetoothVM.isScanning)
            .padding()
        
            List(bluetoothVM.foundDevices, id: \.identifier) { device in
                VStack(alignment: .leading) {
                    Text(device.name.isEmpty ? "Unknown Device" : device.name)
                        .font(.headline)
                    Text(device.identifier.uuidString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct BluetoothDevice: Identifiable, Hashable {
    let id = UUID()
    let identifier: UUID
    let name: String
}

class BluetoothViewModel: ObservableObject {
    @Published var foundDevices: [BluetoothDevice] = []
    @Published var isScanning: Bool = false
    
    func startScanning() {
        // Actual scanning logic will be implemented in BluetoothViewModel.swift
    }
}

#Preview {
    ContentView()
}
