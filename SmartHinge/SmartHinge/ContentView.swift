import SwiftUI

private struct DeviceLabel: Codable, Equatable {
    var label: String
    var door: String
    var kind: String? // e.g., "actuatorDoorHinge"
}

private enum DeviceKind: String, CaseIterable, Identifiable {
    case actuatorDoorHinge
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .actuatorDoorHinge: return "Actuator Door Hinge"
        case .other: return "Other"
        }
    }
}

struct ContentView: View {
    @StateObject private var controller = BluetoothActuatorController()
    @State private var isSimulation: Bool = false
    @State private var angleDegrees: Double = 1.0

    // Labeling & selection state
    @State private var labels: [UUID: DeviceLabel] = [:]
    @State private var selectedDevice: DiscoveredPeripheral? = nil
    @State private var isLabelSheetPresented: Bool = false
    @State private var labelInput: String = ""
    @State private var doorInput: String = ""
    @State private var activeDeviceID: UUID? = nil
    @State private var kindSelection: DeviceKind = .actuatorDoorHinge

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Connection Section
                GroupBox("Connection") {
                    HStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 10, height: 10)
                        Text(statusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Toggle("Demo Mode", isOn: $isSimulation)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .help("Enable to simulate scanning and connection without hardware")
                        if controller.connectionState == .connected {
                            Button("Disconnect") {
                                controller.disconnect()
                                activeDeviceID = nil
                            }
                            .buttonStyle(.bordered)
                        } else {
                            if controller.isScanning {
                                Button("Stop Scan") { controller.stopScan() }
                                    .buttonStyle(.bordered)
                            } else {
                                Button("Scan Devices") { controller.startScan() }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(!controller.isBluetoothAvailable)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    if controller.connectionState != .connected {
                        // Device selection list
                        List(controller.devices) { device in
                            Button {
                                selectedDevice = device
                                if let info = labels[device.id] {
                                    labelInput = info.label
                                    doorInput = info.door
                                    if let raw = info.kind, let kind = DeviceKind(rawValue: raw) {
                                        kindSelection = kind
                                    } else {
                                        kindSelection = .actuatorDoorHinge
                                    }
                                } else {
                                    labelInput = ""
                                    doorInput = ""
                                    kindSelection = .actuatorDoorHinge
                                }
                                isLabelSheetPresented = true
                            } label: {
                                HStack(alignment: .center) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(device.name)
                                        if let info = labels[device.id] {
                                            Text("\(info.label) • \(info.door)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .frame(minHeight: 180, maxHeight: 260)
                    } else {
                        // Connected summary
                        HStack(spacing: 8) {
                            Image(systemName: "link.circle.fill").foregroundStyle(.green)
                            if let id = activeDeviceID, let info = labels[id] {
                                Text("Connected: \(info.label) • \(info.door)")
                            } else if let name = controller.connectedPeripheralName {
                                Text("Connected to \(name)")
                            } else {
                                Text("Connected")
                            }
                            Spacer()
                        }
                    }
                }

                if isActuatorHingeActive {
                    // Controls Section (only visible once identified as Actuator Door Hinge)
                    GroupBox("Actuator Controls") {
                        HStack(spacing: 12) {
                            Button {
                                controller.retract()
                            } label: {
                                Label("Retract", systemImage: "arrow.down.to.line")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                controller.stopMotion()
                            } label: {
                                Label("Stop", systemImage: "pause.circle")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                controller.extend()
                            } label: {
                                Label("Extend", systemImage: "arrow.up.to.line")
                            }
                            .buttonStyle(.bordered)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Angle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Text("1°")
                                    .font(.caption2)
                                Slider(value: $angleDegrees, in: 1...90, step: 1) { _ in
                                    // Map 1...90° to 0...1 normalized (using 1...90 inclusive -> 89 span)
                                    let normalized = (angleDegrees - 1.0) / 89.0
                                    controller.setPosition(normalized: normalized)
                                }
                                Text("90°")
                                    .font(.caption2)
                            }
                        }
                        .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Speed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Text("0")
                                    .font(.caption2)
                                Slider(value: $controller.speed, in: 0...1, step: 0.01) { _ in
                                    controller.setSpeed(normalized: controller.speed)
                                }
                                Text("100")
                                    .font(.caption2)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("SmartHinge")
            .onAppear {
                restoreLabels()
            }
            .onChange(of: isSimulation) { oldValue, newValue in
                controller.stopScan()
            }
        }
        .sheet(isPresented: $isLabelSheetPresented) {
            NavigationStack {
                Form {
                    Section("Identify this actuator") {
                        TextField("Label (e.g., Front Door Actuator)", text: $labelInput)
                        TextField("Door (e.g., Front Door)", text: $doorInput)
                    }
                    Section("Device type") {
                        Picker("This device is", selection: $kindSelection) {
                            ForEach(DeviceKind.allCases) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                }
                .navigationTitle("Label Device")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isLabelSheetPresented = false
                            selectedDevice = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save & Connect") {
                            guard let device = selectedDevice else { return }
                            let trimmedLabel = labelInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            let trimmedDoor = doorInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            labels[device.id] = DeviceLabel(label: trimmedLabel, door: trimmedDoor, kind: kindSelection.rawValue)
                            persistLabels()
                            activeDeviceID = device.id
                            controller.connect(to: device)
                            isLabelSheetPresented = false
                        }
                        .disabled(labelInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || doorInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private var statusText: String {
        switch controller.connectionState {
        case .disconnected:
            if controller.isBluetoothAvailable {
                return "Disconnected"
            } else {
                return "Bluetooth unavailable"
            }
        case .connecting:
            return "Connecting…"
        case .connected:
            return "Connected"
        }
    }

    private var statusColor: Color {
        switch controller.connectionState {
        case .disconnected:
            return controller.isBluetoothAvailable ? .yellow : .red
        case .connecting:
            return .orange
        case .connected:
            return .green
        }
    }

    private var isActuatorHingeActive: Bool {
        guard controller.connectionState == .connected,
              let id = activeDeviceID,
              let info = labels[id] else { return false }
        return info.kind == DeviceKind.actuatorDoorHinge.rawValue
    }

    // MARK: - Persistence helpers
    private func restoreLabels() {
        if let data = UserDefaults.standard.data(forKey: "deviceLabels"),
           let decoded = try? JSONDecoder().decode([UUID: DeviceLabel].self, from: data) {
            labels = decoded
        }
    }

    private func persistLabels() {
        if let data = try? JSONEncoder().encode(labels) {
            UserDefaults.standard.set(data, forKey: "deviceLabels")
        }
    }
}

#Preview {
    ContentView()
}
