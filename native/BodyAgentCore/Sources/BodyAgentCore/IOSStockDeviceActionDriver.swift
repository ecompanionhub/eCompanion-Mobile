#if os(iOS)
import Foundation
import UIKit

struct IOSStockDeviceActionDriver: StockDeviceActionDriver {
    @MainActor
    func openURL(_ url: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { success in
                continuation.resume(returning: success)
            }
        }
    }

    @MainActor
    func readClipboardText() async -> String? {
        UIPasteboard.general.string
    }

    @MainActor
    func writeClipboardText(_ text: String) async {
        UIPasteboard.general.string = text
    }

    @MainActor
    func clearClipboard() async {
        UIPasteboard.general.items = []
    }

    func appDocumentsDirectory() async throws -> URL {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw BodyActionError.executionFailed("BODY_ACTION_DOCUMENTS_UNAVAILABLE")
        }
        return directory
    }
}
#endif
