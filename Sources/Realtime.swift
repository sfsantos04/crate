import Foundation

/// Cliente mínimo de SignalR sobre WebSocket: negocia, faz o handshake JSON e
/// avisa a cada mensagem do servidor. Não interpreta os eventos — qualquer
/// mensagem significa "algo mudou", e o app atualiza o estado.
@MainActor
final class RealtimeClient {
    private var socket: URLSessionWebSocketTask?
    private var pump: Task<Void, Never>?
    private var running = false

    var onSignal: (() -> Void)?
    var onState: ((Bool) -> Void)?

    func start(urlProvider: @escaping () async -> URL?) {
        guard !running else { return }
        running = true
        pump = Task { [weak self] in
            var delay: UInt64 = 3_000_000_000
            while let self, self.running, !Task.isCancelled {
                guard let url = await urlProvider() else {
                    try? await Task.sleep(nanoseconds: delay)
                    delay = min(delay * 2, 60_000_000_000)
                    continue
                }
                await self.connect(url)
                guard self.running, !Task.isCancelled else { break }
                try? await Task.sleep(nanoseconds: delay)
                delay = min(delay * 2, 60_000_000_000)
            }
        }
    }

    func stop() {
        running = false
        pump?.cancel()
        pump = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        onState?(false)
    }

    private func connect(_ url: URL) async {
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        socket = task
        task.resume()

        let handshake = #"{"protocol":"json","version":1}"# + "\u{1e}"
        do {
            try await task.send(.string(handshake))
            _ = try await task.receive()  // {} do servidor
            onState?(true)
        } catch {
            onState?(false)
            task.cancel(with: .goingAway, reason: nil)
            socket = nil
            return
        }

        while running, !Task.isCancelled {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    if !text.isEmpty { onSignal?() }
                case .data(let data):
                    if !data.isEmpty { onSignal?() }
                @unknown default:
                    break
                }
            } catch {
                onState?(false)
                break
            }
        }
        task.cancel(with: .goingAway, reason: nil)
        socket = nil
    }
}
