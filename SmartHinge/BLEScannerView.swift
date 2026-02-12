import SwiftUI
import Foundation

struct BLEScannerView: View {
    @StateObject private var viewModel = BLEScannerViewModel()
    @State private var searchText: String = ""
    @State private var sortOption: SortOption = .rssi

    enum SortOption: String, CaseIterable, Identifiable {
        case name = "Name"
        case rssi = "RSSI"

        var id: Self { self }
    }

    @State private var selectedDevice: DiscoveredDevice?

    var body: some View {
        ZStack {
            // Background with large animated vertical gradient blob (simplified static gradient here)
            LinearGradient(
                colors: [Color.teal.opacity(0.3), Color.blue.opacity(0.15), Color.white.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                scanningHeader
                sortControl
                if filteredDevices.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                } else {
                    ZStack {
                        // Gradient background behind list for floating card feel
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.12), Color.teal.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .background(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)

                        deviceList
                            .padding(.horizontal, 14)
                    }
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                }
            }
            .navigationTitle("Nearby Devices")
            .searchable(text: $searchText, prompt: "Search devices")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        toggleScanning()
                    } label: {
                        Label(viewModel.isScanning ? "Stop" : "Scan",
                              systemImage: viewModel.isScanning ? "pause.fill" : "play.fill")
                    }
                    .tint(viewModel.isScanning ? .red : .accentColor)
                    .controlSize(.large)
                }
            }
            .sheet(item: $selectedDevice) { device in
                DeviceDetailView(device: device)
            }
        }
        .animation(.default, value: viewModel.isScanning)
        .animation(.default, value: filteredDevices)
        .onAppear {
            // Optional: Start scanning automatically on appear
        }
    }

    private var scanningHeader: some View {
        HStack(spacing: 16) {
            PulseCirclesView(isScanning: viewModel.isScanning, animatePulse: animatePulse)
                .frame(width: 50, height: 50)
                .onAppear {
                    if viewModel.isScanning {
                        animatePulse = true
                    }
                }
                .onChange(of: viewModel.isScanning) { newValue in
                    animatePulse = newValue
                }

            Text(viewModel.isScanning ? "Scanning..." : "Tap to Scan")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(viewModel.isScanning ? AnyShapeStyle(LinearGradient(
                    colors: [Color.blue, Color.teal],
                    startPoint: .leading,
                    endPoint: .trailing
                )) : AnyShapeStyle(.secondary))
                .animation(.easeInOut, value: viewModel.isScanning)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.10), Color.teal.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
        )
        .padding(.horizontal, 16)
        .onTapGesture {
            toggleScanning()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(viewModel.isScanning ? .isSelected : .isButton)
        .accessibilityLabel(viewModel.isScanning ? "Scanning in progress" : "Tap to start scanning")
    }
    @State private var animatePulse = false

    private var sortControl: some View {
        Picker("Sort by", selection: $sortOption) {
            ForEach(SortOption.allCases) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var deviceList: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                ForEach(filteredDevices) { device in
                    Button {
                        selectedDevice = device
                    } label: {
                        DeviceRowView(device: device)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(.regularMaterial)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.blue.opacity(0.12), Color.teal.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(device.name), RSSI \(device.rssi.map { String($0) } ?? "unknown")")
                    .accessibilityHint("Tap for more details")
                }
            }
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.25), Color.teal.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 110, height: 110)
                    .shadow(color: Color.blue.opacity(0.25), radius: 20, x: 0, y: 6)

                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(LinearGradient(
                        colors: [Color.blue, Color.teal],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .symbolRenderingMode(.multicolor)
            }
            .padding(.bottom, 8)

            Text("No Devices Found")
                .font(.title2.weight(.bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue, Color.teal],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("No devices around yet. Try moving closer or make sure your BLE devices are powered on and ready to connect.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 36)
        }
        .padding()
    }

    private var filteredDevices: [DiscoveredDevice] {
        var devices = viewModel.devices

        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            devices = devices.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch sortOption {
        case .name:
            devices = devices.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .rssi:
            devices = devices.sorted { ($0.rssi ?? -999) > ($1.rssi ?? -999) }
        }

        return devices
    }

    private func toggleScanning() {
        if viewModel.isScanning {
            viewModel.stopScanning()
        } else {
            viewModel.startScanning()
        }
    }
}

// MARK: - Pulse Circles View

private struct PulseCirclesView: View {
    let isScanning: Bool
    let animatePulse: Bool

    var body: some View {
        ZStack {
            // Multiple layered pulses with staggered animation for playful effect
            ForEach(0..<3) { index in
                Circle()
                    .stroke(Color.accentColor.opacity(0.3 - Double(index) * 0.1), lineWidth: 3)
                    .frame(width: 40 + CGFloat(index * 18), height: 40 + CGFloat(index * 18))
                    .scaleEffect(isScanning ? (animatePulse ? 1.6 + CGFloat(index)*0.2 : 1) : 1)
                    .opacity(isScanning ? (animatePulse ? 0 : 0.7 - Double(index)*0.15) : 0)
                    .animation(
                        isScanning ?
                            Animation.easeOut(duration: 1.3 + Double(index)*0.4).repeatForever(autoreverses: true).delay(Double(index)*0.2) :
                            .default,
                        value: animatePulse
                    )
            }

            Circle()
                .fill(Color.accentColor)
                .frame(width: 20, height: 20)
        }
    }
}

// MARK: - Device Row View

private struct DeviceRowView: View {
    let device: DiscoveredDevice

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 6, x: 0, y: 3)
                    .frame(width: 40, height: 48)

                DeviceSignalView(rssi: device.rssi)
                    .frame(width: 30)
                    .padding(.leading, 2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let rssi = device.rssi {
                    Text("RSSI: \(rssi) dBm")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("RSSI: —")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.secondary.opacity(0.7))
        }
    }
}

// MARK: - Device Signal View (Bars)

private struct DeviceSignalView: View {
    let rssi: Int?

    var barCount: Int {
        let value = rssi ?? -100
        switch value {
        case let x where x >= -50:
            return 5
        case -60..<(-50):
            return 4
        case -70..<(-60):
            return 3
        case -80..<(-70):
            return 2
        case -90..<(-80):
            return 1
        default:
            return 0
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1 ... 5, id: \.self) { index in
                Capsule()
                    .fill(index <= barCount ? Color.accentColor : Color.accentColor.opacity(0.25))
                    .frame(width: 3, height: CGFloat(5 + index * 4))
                    .animation(.easeInOut(duration: 0.3), value: barCount)
            }
        }
        .accessibilityLabel("\(barCount) bars signal strength")
    }
}

// MARK: - Radar Pulse View

private struct RadarPulseView: View {
    var isPulsing: Bool

    @State private var animatePulse = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 2)
                .foregroundColor(.accentColor)
                .opacity(isPulsing ? (animatePulse ? 0.2 : 0.6) : 0)
                .scaleEffect(animatePulse ? 1.6 : 1)
                .animation(isPulsing ? .easeOut(duration: 1).repeatForever(autoreverses: true) : .default, value: animatePulse)

            Circle()
                .fill(Color.accentColor)
                .frame(width: 14, height: 14)
        }
        .onAppear {
            if isPulsing {
                animatePulse = true
            }
        }
        .onChange(of: isPulsing) { newValue in
            if newValue {
                animatePulse = true
            } else {
                animatePulse = false
            }
        }
    }
}

// MARK: - Device Detail Placeholder

private struct DeviceDetailView: View {
    let device: DiscoveredDevice

    var body: some View {
        VStack(spacing: 20) {
            Text(device.name)
                .font(.largeTitle.weight(.bold))
                .padding(.top)

            DeviceSignalView(rssi: device.rssi)
                .frame(width: 50)
                .padding(.bottom)

            if let rssi = device.rssi {
                Text("RSSI: \(rssi) dBm")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else {
                Text("RSSI: —")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text("More device details will be available here.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()

            Spacer()
        }
        .padding()
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preview

#Preview {
    BLEScannerView()
}

