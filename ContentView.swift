import SwiftUI

struct ContentView: View {
    @State private var urlText = ""
    @State private var file: TBFile?
    @State private var loading = false
    @State private var error: String?
    @State private var showPlayer = false
    let resolver = TeraBoxResolver()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Paste share link (terabox, 4funbox, nephobox…)", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onSubmit { Task { await resolve() } }

                Button("Resolve & Play") { Task { await resolve() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(loading)

                if loading { ProgressView("Resolving…") }

                if let file {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(file.server_filename).font(.headline)
                        Text(String(format: "%.1f MB", Double(file.size) / 1_048_576.0))
                            .foregroundStyle(.secondary)

                        if let link = file.dlink, let url = URL(string: link) {
                            Button { showPlayer = true } label: {
                                Label("Play Now", systemImage: "play.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)

                            ShareLink(item: url) {
                                Label("Copy Direct Link", systemImage: "link")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Text("No direct link returned — link may require login or expired.")
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                if let error {
                    Text(error).foregroundStyle(.red).multilineTextAlignment(.center)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("TeraBox Player")
            .navigationDestination(isPresented: $showPlayer) {
                if let file, let link = file.dlink, let url = URL(string: link) {
                    PlayerView(url: url, fileName: file.server_filename)
                }
            }
        }
    }

    func resolve() async {
        loading = true; error = nil; file = nil
        defer { loading = false }
        do {
            guard let parsed = resolver.parse(urlString: urlText) else {
                error = "Unsupported domain.\nSupported: " +
                    TeraBoxResolver.mirrors.map(\.host).joined(separator: ", ")
                return
            }
            file = try await resolver.resolve(parsed)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
