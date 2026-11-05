import Foundation

/// Ajustes de transferência lidos/gravados no fork (overlay de opções do slskd).
struct TransferSettings: Equatable {
    var uploadSlots: Int = 10
    var uploadSpeedLimit: Int = Int(Int32.max)
    var downloadSlots: Int = Int(Int32.max)
    var downloadSpeedLimit: Int = Int(Int32.max)

    static let unlimited = Int(Int32.max)

    var uploadUnlimited: Bool { uploadSpeedLimit >= Self.unlimited }
    var downloadUnlimited: Bool { downloadSpeedLimit >= Self.unlimited }
}

extension SlskdClient {
    func transferSettings() async throws -> TransferSettings {
        let data = try await send("/api/v0/options")
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let transfers = root["transfers"] as? [String: Any],
            let upload = transfers["upload"] as? [String: Any],
            let download = transfers["download"] as? [String: Any]
        else {
            throw SlskdError.malformed("options sem bloco transfers")
        }

        var settings = TransferSettings()
        settings.uploadSlots = upload["slots"] as? Int ?? settings.uploadSlots
        settings.uploadSpeedLimit = upload["speedLimit"] as? Int ?? settings.uploadSpeedLimit
        settings.downloadSlots = download["slots"] as? Int ?? settings.downloadSlots
        settings.downloadSpeedLimit = download["speedLimit"] as? Int ?? settings.downloadSpeedLimit
        return settings
    }

    func patchTransfers(uploadSlots: Int?, uploadSpeed: Int?, downloadSpeed: Int?) async throws {
        var upload: [String: Any] = [:]
        if let uploadSlots { upload["slots"] = uploadSlots }
        if let uploadSpeed { upload["speedLimit"] = uploadSpeed }

        var transfers: [String: Any] = [:]
        if !upload.isEmpty { transfers["upload"] = upload }
        if let downloadSpeed { transfers["download"] = ["speedLimit": downloadSpeed] }
        guard !transfers.isEmpty else { return }

        let body = try JSONSerialization.data(withJSONObject: ["transfers": transfers])
        _ = try await send("/api/v0/options", method: "PATCH", body: body)
    }
}
