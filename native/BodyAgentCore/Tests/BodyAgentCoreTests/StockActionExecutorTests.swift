import Foundation
import XCTest
@testable import BodyAgentCore

private actor StubStockDeviceDriver: StockDeviceActionDriver {
    private let root: URL
    private var clipboard: String?
    private var openedURLs: [URL] = []
    private let openResult: Bool

    init(root: URL, clipboard: String? = nil, openResult: Bool = true) {
        self.root = root
        self.clipboard = clipboard
        self.openResult = openResult
    }

    func openURL(_ url: URL) async -> Bool {
        openedURLs.append(url)
        return openResult
    }

    func readClipboardText() async -> String? {
        clipboard
    }

    func writeClipboardText(_ text: String) async {
        clipboard = text
    }

    func clearClipboard() async {
        clipboard = nil
    }

    func appDocumentsDirectory() async throws -> URL {
        root
    }

    func opened() -> [URL] {
        openedURLs
    }

    func clipboardValue() -> String? {
        clipboard
    }
}

final class StockActionExecutorTests: XCTestCase {
    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ecompanion-stock-actions-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func testOpenURLUsesStructuredActionAndRejectsLocalFileScheme() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let driver = StubStockDeviceDriver(root: root)
        let executor = StockBodyActionExecutor(driver: driver)

        let result = try await executor.execute(BodyActionRequest(
            capability: "device.open_url",
            operation: "open",
            arguments: ["url": .string("https://example.com/path")]
        ))

        XCTAssertEqual(result.output["opened"]?.boolValue, true)
        XCTAssertEqual(result.output["scheme"]?.stringValue, "https")
        let opened = await driver.opened()
        XCTAssertEqual(opened.map(\.absoluteString), ["https://example.com/path"])

        do {
            _ = try await executor.execute(BodyActionRequest(
                capability: "device.open_url",
                operation: "open",
                arguments: ["url": .string("file:///private/escape")]
            ))
            XCTFail("Local file URLs must fail closed")
        } catch let error as BodyActionError {
            XCTAssertEqual(error, .invalidArguments("BODY_ACTION_URL_INVALID"))
        }
    }

    func testClipboardReadWriteAndClearAreExplicitOperations() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let driver = StubStockDeviceDriver(root: root)
        let executor = StockBodyActionExecutor(driver: driver)

        _ = try await executor.execute(BodyActionRequest(
            capability: "device.clipboard",
            operation: "write_text",
            arguments: ["text": .string("owner-approved")]
        ))
        let stored = await driver.clipboardValue()
        XCTAssertEqual(stored, "owner-approved")

        let read = try await executor.execute(BodyActionRequest(
            capability: "device.clipboard",
            operation: "read_text"
        ))
        XCTAssertEqual(read.output["text"]?.stringValue, "owner-approved")

        _ = try await executor.execute(BodyActionRequest(
            capability: "device.clipboard",
            operation: "clear"
        ))
        let cleared = await driver.clipboardValue()
        XCTAssertNil(cleared)
    }

    func testAppOwnedFilesSupportBoundedLifecycleInsideDocumentsRoot() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let driver = StubStockDeviceDriver(root: root)
        let executor = StockBodyActionExecutor(driver: driver)

        _ = try await executor.execute(BodyActionRequest(
            capability: "device.files.app_owned",
            operation: "create_directory",
            arguments: ["path": .string("notes")]
        ))

        let write = try await executor.execute(BodyActionRequest(
            capability: "device.files.app_owned",
            operation: "write_text",
            arguments: [
                "path": .string("notes/state.txt"),
                "text": .string("same canonical body")
            ]
        ))
        XCTAssertEqual(write.output["written"]?.boolValue, true)

        let read = try await executor.execute(BodyActionRequest(
            capability: "device.files.app_owned",
            operation: "read_text",
            arguments: ["path": .string("notes/state.txt")]
        ))
        XCTAssertEqual(read.output["text"]?.stringValue, "same canonical body")

        let list = try await executor.execute(BodyActionRequest(
            capability: "device.files.app_owned",
            operation: "list",
            arguments: ["path": .string("notes")]
        ))
        XCTAssertEqual(list.output["count"]?.numberValue, 1)
        XCTAssertEqual(list.output["truncated"]?.boolValue, false)

        do {
            _ = try await executor.execute(BodyActionRequest(
                capability: "device.files.app_owned",
                operation: "write_text",
                arguments: [
                    "path": .string("notes/state.txt"),
                    "text": .string("must not overwrite implicitly")
                ]
            ))
            XCTFail("Implicit overwrite must fail closed")
        } catch let error as BodyActionError {
            XCTAssertEqual(error, .executionFailed("BODY_ACTION_FILE_EXISTS"))
        }

        let delete = try await executor.execute(BodyActionRequest(
            capability: "device.files.app_owned",
            operation: "delete_file",
            arguments: ["path": .string("notes/state.txt")]
        ))
        XCTAssertEqual(delete.output["deleted"]?.boolValue, true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("notes/state.txt").path))
    }

    func testAppOwnedFilesRejectTraversalAbsoluteAndDirectoryDelete() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let driver = StubStockDeviceDriver(root: root)
        let executor = StockBodyActionExecutor(driver: driver)

        for invalidPath in ["../escape.txt", "/private/escape.txt", "notes/../../escape.txt"] {
            do {
                _ = try await executor.execute(BodyActionRequest(
                    capability: "device.files.app_owned",
                    operation: "read_text",
                    arguments: ["path": .string(invalidPath)]
                ))
                XCTFail("Path escape must fail closed: \(invalidPath)")
            } catch let error as BodyActionError {
                XCTAssertEqual(error, .invalidArguments("BODY_ACTION_PATH_INVALID"))
            }
        }

        try FileManager.default.createDirectory(at: root.appendingPathComponent("directory"), withIntermediateDirectories: false)
        do {
            _ = try await executor.execute(BodyActionRequest(
                capability: "device.files.app_owned",
                operation: "delete_file",
                arguments: ["path": .string("directory")]
            ))
            XCTFail("Directory delete must not be available through delete_file")
        } catch let error as BodyActionError {
            XCTAssertEqual(error, .executionFailed("BODY_ACTION_FILE_NOT_REGULAR"))
        }
    }

    func testWrongOperationAndUnknownCapabilityFailClosed() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let driver = StubStockDeviceDriver(root: root)
        let executor = StockBodyActionExecutor(driver: driver)

        do {
            _ = try await executor.execute(BodyActionRequest(
                capability: "device.open_url",
                operation: "browse",
                arguments: ["url": .string("https://example.com")]
            ))
            XCTFail("Undeclared operation must fail closed")
        } catch let error as BodyActionError {
            XCTAssertEqual(error, .operationDenied("browse"))
        }

        do {
            _ = try await executor.execute(BodyActionRequest(
                capability: "elevated.app.control",
                operation: "execute"
            ))
            XCTFail("Executor must not accept elevated capability")
        } catch let error as BodyActionError {
            XCTAssertEqual(error, .unknownCapability("elevated.app.control"))
        }
    }
}
