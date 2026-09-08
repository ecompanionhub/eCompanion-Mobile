#if os(iOS)
import Foundation
import UIKit

struct IOSStockDeviceActionDriver: StockDeviceActionDriver {
    func openURL(_ url: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                UIApplication.shared.open(url, options: [:]) { success in
                    continuation.resume(returning: success)
                }
            }
        }
    }

    func readClipboardText() async -> String? {
        await MainActor.run {
            UIPasteboard.general.string
        }
    }

    func writeClipboardText(_ text: String) async {
        await MainActor.run {
            UIPasteboard.general.string = text
        }
    }

    func clearClipboard() async {
        await MainActor.run {
            UIPasteboard.general.items = []
        }
    }

    func appDocumentsDirectory() async throws -> URL {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw BodyActionError.executionFailed("BODY_ACTION_DOCUMENTS_UNAVAILABLE")
        }
        return directory
    }
}
#endif
