import SwiftUI
import Combine

struct ContentView: View {
    // ← Change this to your ESP8266's IP (shown in Serial Monitor)
    let espIP = "192.168.86.43"

    @State private var command = ""
    @State private var response = "No response yet."
    @State private var history: [String] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Response card
                    VStack(alignment: .leading, spacing: 8) {
                        Label("ESP says", systemImage: "bubble.left.and.bubble.right.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(response)
                            .fontDesign(.monospaced)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    // History card
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Sent commands", systemImage: "paperplane.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 6) {
                            if history.isEmpty {
                                Text("No commands sent yet.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(history.indices.reversed(), id: \.self) { index in
                                    Text("→ \(history[index])")
                                        .font(.system(.body, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.horizontal)
                .padding(.top)
            }
            .navigationTitle("ESP8266 Controller")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await fetchResponse() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
            .refreshable { await fetchResponse() }
            .safeAreaInset(edge: .bottom) {
                // Modern input bar
                HStack(spacing: 8) {
                    TextField("Type a command…", text: $command)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.send)
                        .onSubmit { Task { await sendCommand() } }

                    Button {
                        Task { await sendCommand() }
                    } label: {
                        Label("Send", systemImage: "paperplane.fill")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
        }
        // Poll the ESP for its latest message every 2 seconds using a modern publisher
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            Task { await fetchResponse() }
        }
    }

    // Send a command to the ESP (async/await)
    func sendCommand() async {
        guard !command.isEmpty,
              let encoded = command.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "http://\(espIP)/send?msg=\(encoded)") else { return }

        // Capture and clear immediately for a responsive UI
        let message = command
        history.append(message)
        command = ""

        do {
            _ = try await URLSession.shared.data(from: url)
        } catch {
            // You might show an error toast/state here in the future
            // For now, we silently ignore failures to keep the UI simple
        }
    }

    // Fetch the latest message from the ESP (async/await)
    func fetchResponse() async {
        guard let url = URL(string: "http://\(espIP)/receive") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let text = String(data: data, encoding: .utf8) {
                await MainActor.run {
                    response = text
                }
            }
        } catch {
            // Optionally handle networking errors
        }
    }
}

#Preview {
    ContentView()
}
