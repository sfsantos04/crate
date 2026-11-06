import AVFoundation
import SwiftUI

extension SlskdClient {
    /// Pede ao servidor um link temporário (6h) para tocar o arquivo.
    func streamLink(path: String, root: String = "downloads") async throws -> URL {
        let body = try JSONSerialization.data(withJSONObject: ["path": path, "root": root])
        let data = try await send("/api/v0/files/link", method: "POST", body: body)

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let key = object["key"] as? String,
              let base = baseURL else {
            throw SlskdError.malformed("link de arquivo inválido")
        }

        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        components?.path = "/api/v0/files/stream"
        components?.queryItems = [URLQueryItem(name: "key", value: key)]

        guard let url = components?.url else {
            throw SlskdError.badHost
        }

        return url
    }
}

/// Player simples para os arquivos baixados no servidor.
struct PlayerView: View {
    let title: String
    let url: URL

    @State private var player = AVPlayer()
    @State private var playing = false
    @State private var position: Double = 0
    @State private var duration: Double = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.hero)
                    .frame(height: 220)
                Image(systemName: "waveform")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Text(title)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal)

            VStack(spacing: 6) {
                Slider(value: Binding(
                    get: { position },
                    set: { value in
                        position = value
                        player.seek(to: CMTime(seconds: value, preferredTimescale: 600))
                    }
                ), in: 0...max(duration, 1))

                HStack {
                    Text(time(position)).font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                    Spacer()
                    Text(time(duration)).font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            Button {
                toggle()
            } label: {
                Image(systemName: playing ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.accent)
            }

            Spacer()
        }
        .padding(.top, 20)
        .navigationTitle("Tocando")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: start)
        .onDisappear(perform: stop)
    }

    private func start() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        player = AVPlayer(url: url)
        player.play()
        playing = true

        Task {
            let asset = AVURLAsset(url: url)
            if let value = try? await asset.load(.duration) {
                duration = CMTimeGetSeconds(value)
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            position = CMTimeGetSeconds(player.currentTime())
            if duration == 0, let item = player.currentItem {
                let seconds = CMTimeGetSeconds(item.duration)
                if seconds.isFinite { duration = seconds }
            }
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        player.pause()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func toggle() {
        if playing {
            player.pause()
        } else {
            player.play()
        }
        playing.toggle()
    }

    private func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
