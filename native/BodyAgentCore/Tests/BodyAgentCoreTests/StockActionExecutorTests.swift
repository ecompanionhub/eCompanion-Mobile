import Foundation
import XCTest
@testable import BodyAgentCore

private actor TestStockDeviceActionDriver: StockDeviceActionDriver {
    private let root: URL
    private var clipboard: String?
    private var opened: [URL] = []

    init(root: URL, clipboard: String? = nil) {
        self.root = root
        self.clipboard = clipboard
    }

    func openURL(_ url: URL) async -> Bool {
        opened.append(url)
        return true
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

    func openedURLs() -> [URL] {
        opened
    }
}

final class StockActionExecutorTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ecompanion-stock-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }

    func testExecutorExposesOnlyConvergedStockCapabilities() throws {
        let root = try temporaryDirectory()
        let executor = StockBodyActionExecutor(
            driver: TestStockDeviceActionDriver(root: root)
        )
        XCTAssertEqual(
            executor.capabilities,
            ["device.open_url", "device.clipboard", "device.files.app_owned"]
        )
        XCTAssertFalse(executor.capabilities.contains("device.shortcut.invoke"))
        XCTAssertFalse(executor.capabilities.contains("device.location"))
    }

    func testOpenURLAllowsWebAndRejectsPrivilegedSchemes() async throws {
        let root = try temporaryDirectory()
        let driver = TestStockDeviceActionDriver(root: root)
        let executor = StockBodyActionExecutor(driver: driver)

        let result = try await executor.execute(
            BodyActionRequest(
                capability: "device.open_url",
                operation: "open",
                arguments: ["url": "https://example.com/path"]
            )
        )
        XCTAssertEqual(result.output["opened"], .bool(true))
        let opened = await driver.openedURLs()
        XCTAssertEqual(opened.first?.absoluteString, "https://example.com/path")

        for value in [
            "file:///private/var/mobile/secret",
            "javascript:alert(1)",
            "shortcuts://run-shortcut?name=test",
            "data:text/plain,hello"
        ] {
            do {
                _ = try await executor.execute(
                    BodyActionRequest(
                        capability: "device.open_url",
                        operation: "open",
                        arguments: ["url": .string(value)]
                    )
                )
                XCTFail("Expected \(value) to be rejected")
            } catch let error as BodyActionError {
                XCTAssertEqual(error, .invalidArguments("BODY_ACTION_URL_INVALID"))
            }
        }
    }

    func testClipboardReadWriteAndClear() async throws {
        let root = try temporaryDirectory()
        let driver = TestStockDeviceActionDriver(root: root)
        let executor = StockBodyActionExecutor(driver: driver)

        _ = try await executor.execute(
            BodyActionRequest(
                capability: "device.clipboard",
                operation: "write_text",
                arguments: ["text": "hello"]
            )
        )

        let read = try await executor.execute(
            BodyActionRequest(
                capability: "device.clipboard",
                operation: "read_text"
            )
        )
        XCTAssertEqual(read.output["text"], .string("hello"))

        _ = try await executor.execute(
            BodyActionRequest(
                capability: "device.clipboard",
                operation: "clear"
            )
        )

        let empty = try await executor.execute(
            BodyActionRequest(
                capability: "device.clipboard",
                operation: "read_text"
            )
        )
        XCTAssertEqual(empty.output["text"], .null)
    }

    func testAppOwnedFilesStayInsideDocumentsAndRequireExplicitOverwrite() async throws {
        let root = try temporaryDirectory()
        let driver = TestStockDeviceActionDriver(root: root)
        let executor = StockBodyActionExecutor(driver: driver)

        _ = try await executor.execute(
            BodyActionRequest(
                capability: "device.files.app_owned",
                operation: "create_directory",
                arguments: [
                    "path": "notes",
                    "with_intermediates": true
                ]
            )
        )

        _ = try await executor.execute(
            BodyActionRequest(
                capability: "device.files.app_owned",
                operation: "write_text",
                arguments: [
                    "path": "notes/lola.txt",
                    "text": "first"
                ]
            )
        )

        do {
            _ = try await executor.execute(
                BodyActionRequest(
                    capability: "device.files.app_owned",
                    operation: "write_text",
                    arguments: [
                        "path": "notes/lola.txt",
                        "text": "second"
                    ]
                )
            )
            XCTFail("Overwrite must be explicit")
        } catch let error as BodyActionError {
            XCTAssertEqual(error, .executionFailed("BODY_ACTION_FILE_EXISTS"))
        }

        _ = try await executor.execute(
            BodyActionRequest(
                capability: "device.files.app_owned",
                operation: "write_text",
                arguments: [
                    "path": "notes/lola.txt",
                    "text": "second",
                    "overwrite": true
                ]
            )
        )

        let read = try await executor.execute(
            BodyActionRequest(
                capability: "device.files.app_owned",
                operation: "read_text",
                arguments: ["path": "notes/lola.txt"]
            )
        )
        XCTAssertEqual(read.output["text"], .string("second"))

        let list = try await executor.execute(
            BodyActionRequest(
                capability: "device.files.app_owned",
                operation: "list",
                arguments: ["path": "notes"]
            )
        )
        XCTAssertEqual(list.output["count"], .number(1))

        _ = try await executor.execute(
            BodyActionRequest(
                capability: "device.files.app_owned",
                operation: "delete_file",
                arguments: ["path": "notes/lola.txt"]
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: root.appendingPathComponent("notes/lola.txt").path
            )
        )
    }

    func testFileConfinementRejectsTraversalAbsoluteAndSymlinkEscape() async throws {
        let root = try temporaryDirectory()
        let outside = FileManager.default.temporaryDirectory
            .appendingPathComponent("ecompanion-outside-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: outside)
        }

        let link = root.appendingPathComponent("escape")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)

        let driver = TestStockDeviceActionDriver(root: root)
        let executor = StockBodyActionExecutor(driver: driver)

        for path in ["../outside.txt", "/tmp/outside.txt", "escape/outside.txt"] {
            do {
                _ = try await executor.execute(
                    BodyActionRequest(
                        capability: "device.files.app_owned",
                        operation: "write_text",
                        arguments: [
                            "path": .string(path),
                            "text": "blocked"
                        ]
                    )
                )
                XCTFail("Expected \(path) to be rejected")
            } catch let error as BodyActionError {
                switch error {
                case .invalidArguments("BODY_ACTION_PATH_INVALID"),
                     .invalidArguments("BODY_ACTION_PATH_ESCAPE_FORBIDDEN"):
                    break
                default:
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }
    }
}
