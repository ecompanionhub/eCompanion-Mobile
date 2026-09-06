import Foundation

protocol StockDeviceActionDriver: Sendable {
    func openURL(_ url: URL) async -> Bool
    func readClipboardText() async -> String?
    func writeClipboardText(_ text: String) async
    func clearClipboard() async
    func appDocumentsDirectory() async throws -> URL
}

enum StockActionLimits {
    static let openURLBytes = 4_096
    static let clipboardTextBytes = 256_000
    static let fileTextBytes = 2_000_000
    static let relativePathBytes = 1_024
    static let listEntries = 500
}

enum StockActionSupport {
    static func rejectUnexpectedArguments(
        _ arguments: [String: JSONValue],
        allowed: Set<String>
    ) throws {
        guard arguments.keys.allSatisfy(allowed.contains) else {
            throw BodyActionError.invalidArguments("BODY_ACTION_ARGUMENT_UNEXPECTED")
        }
    }

    static func requiredString(
        _ arguments: [String: JSONValue],
        key: String,
        maxBytes: Int,
        allowEmpty: Bool = false
    ) throws -> String {
        guard let value = arguments[key]?.stringValue,
              !value.contains("\0"),
              (allowEmpty || !value.isEmpty),
              value.utf8.count <= maxBytes else {
            throw BodyActionError.invalidArguments("BODY_ACTION_ARGUMENT_\(key.uppercased())_INVALID")
        }
        return value
    }

    static func optionalString(
        _ arguments: [String: JSONValue],
        key: String,
        maxBytes: Int,
        default defaultValue: String = ""
    ) throws -> String {
        guard let raw = arguments[key] else { return defaultValue }
        guard let value = raw.stringValue,
              !value.contains("\0"),
              value.utf8.count <= maxBytes else {
            throw BodyActionError.invalidArguments("BODY_ACTION_ARGUMENT_\(key.uppercased())_INVALID")
        }
        return value
    }

    static func optionalBool(
        _ arguments: [String: JSONValue],
        key: String,
        default defaultValue: Bool = false
    ) throws -> Bool {
        guard let raw = arguments[key] else { return defaultValue }
        guard let value = raw.boolValue else {
            throw BodyActionError.invalidArguments("BODY_ACTION_ARGUMENT_\(key.uppercased())_INVALID")
        }
        return value
    }

    static func confinedURL(
        root: URL,
        relativePath: String,
        allowRoot: Bool
    ) throws -> URL {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        if normalized.isEmpty {
            guard allowRoot else {
                throw BodyActionError.invalidArguments("BODY_ACTION_PATH_REQUIRED")
            }
            return root.standardizedFileURL.resolvingSymlinksInPath()
        }
        guard normalized.utf8.count <= StockActionLimits.relativePathBytes,
              !normalized.hasPrefix("/"),
              !normalized.contains("\0") else {
            throw BodyActionError.invalidArguments("BODY_ACTION_PATH_INVALID")
        }
        let components = normalized.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw BodyActionError.invalidArguments("BODY_ACTION_PATH_INVALID")
        }

        let resolvedRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        var candidate = resolvedRoot
        for component in components {
            candidate.appendPathComponent(String(component), isDirectory: false)
        }
        let resolvedCandidate = candidate.standardizedFileURL.resolvingSymlinksInPath()
        let rootPath = resolvedRoot.path.hasSuffix("/") ? resolvedRoot.path : resolvedRoot.path + "/"
        guard resolvedCandidate.path.hasPrefix(rootPath) else {
            throw BodyActionError.invalidArguments("BODY_ACTION_PATH_ESCAPE_FORBIDDEN")
        }
        return resolvedCandidate
    }
}

struct StockBodyActionExecutor: BodyActionExecutor {
    let capabilities: Set<String> = [
        "device.open_url",
        "device.clipboard",
        "device.files.app_owned"
    ]

    private let driver: any StockDeviceActionDriver

    init(driver: any StockDeviceActionDriver) {
        self.driver = driver
    }

    func execute(_ request: BodyActionRequest) async throws -> BodyActionResult {
        switch request.capability {
        case "device.open_url":
            return try await executeOpenURL(request)
        case "device.clipboard":
            return try await executeClipboard(request)
        case "device.files.app_owned":
            return try await executeFiles(request)
        default:
            throw BodyActionError.unknownCapability(request.capability)
        }
    }

    private func executeOpenURL(_ request: BodyActionRequest) async throws -> BodyActionResult {
        guard request.operation == "open" else {
            throw BodyActionError.operationDenied(request.operation)
        }
        try StockActionSupport.rejectUnexpectedArguments(request.arguments, allowed: ["url"])
        let raw = try StockActionSupport.requiredString(
            request.arguments,
            key: "url",
            maxBytes: StockActionLimits.openURLBytes
        )
        guard let components = URLComponents(string: raw),
              let scheme = components.scheme?.lowercased(),
              !scheme.isEmpty,
              !["file", "data", "javascript"].contains(scheme),
              !(["http", "https"].contains(scheme) && components.host?.isEmpty != false),
              let url = components.url else {
            throw BodyActionError.invalidArguments("BODY_ACTION_URL_INVALID")
        }
        guard await driver.openURL(url) else {
            throw BodyActionError.executionFailed("BODY_ACTION_OPEN_URL_REJECTED")
        }
        return BodyActionResult(
            requestID: request.id,
            capability: request.capability,
            output: ["opened": .bool(true), "scheme": .string(scheme)]
        )
    }

    private func executeClipboard(_ request: BodyActionRequest) async throws -> BodyActionResult {
        switch request.operation {
        case "read_text":
            try StockActionSupport.rejectUnexpectedArguments(request.arguments, allowed: [])
            let text = await driver.readClipboardText()
            if let text, text.utf8.count > StockActionLimits.clipboardTextBytes {
                throw BodyActionError.executionFailed("BODY_ACTION_CLIPBOARD_TEXT_TOO_LARGE")
            }
            return BodyActionResult(
                requestID: request.id,
                capability: request.capability,
                output: ["text": text.map(JSONValue.string) ?? .null]
            )
        case "write_text":
            try StockActionSupport.rejectUnexpectedArguments(request.arguments, allowed: ["text"])
            let text = try StockActionSupport.requiredString(
                request.arguments,
                key: "text",
                maxBytes: StockActionLimits.clipboardTextBytes,
                allowEmpty: true
            )
            await driver.writeClipboardText(text)
            return BodyActionResult(
                requestID: request.id,
                capability: request.capability,
                output: ["written": .bool(true), "bytes": .number(Double(text.utf8.count))]
            )
        case "clear":
            try StockActionSupport.rejectUnexpectedArguments(request.arguments, allowed: [])
            await driver.clearClipboard()
            return BodyActionResult(
                requestID: request.id,
                capability: request.capability,
                output: ["cleared": .bool(true)]
            )
        default:
            throw BodyActionError.operationDenied(request.operation)
        }
    }

    private func executeFiles(_ request: BodyActionRequest) async throws -> BodyActionResult {
        let root: URL
        do {
            root = try await driver.appDocumentsDirectory()
        } catch {
            throw BodyActionError.executionFailed("BODY_ACTION_DOCUMENTS_UNAVAILABLE")
        }

        switch request.operation {
        case "list":
            try StockActionSupport.rejectUnexpectedArguments(request.arguments, allowed: ["path"])
            let relativePath = try StockActionSupport.optionalString(
                request.arguments,
                key: "path",
                maxBytes: StockActionLimits.relativePathBytes
            )
            let directory = try StockActionSupport.confinedURL(root: root, relativePath: relativePath, allowRoot: true)
            return try listDirectory(request, directory: directory)
        case "read_text":
            try StockActionSupport.rejectUnexpectedArguments(request.arguments, allowed: ["path"])
            let relativePath = try StockActionSupport.requiredString(
                request.arguments,
                key: "path",
                maxBytes: StockActionLimits.relativePathBytes
            )
            let file = try StockActionSupport.confinedURL(root: root, relativePath: relativePath, allowRoot: false)
            return try readText(request, file: file)
        case "write_text":
            try StockActionSupport.rejectUnexpectedArguments(request.arguments, allowed: ["path", "text", "overwrite"])
            let relativePath = try StockActionSupport.requiredString(
                request.arguments,
                key: "path",
                maxBytes: StockActionLimits.relativePathBytes
            )
            let text = try StockActionSupport.requiredString(
                request.arguments,
                key: "text",
                maxBytes: StockActionLimits.fileTextBytes,
                allowEmpty: true
            )
            let overwrite = try StockActionSupport.optionalBool(request.arguments, key: "overwrite")
            let file = try StockActionSupport.confinedURL(root: root, relativePath: relativePath, allowRoot: false)
            return try writeText(request, file: file, text: text, overwrite: overwrite)
        case "create_directory":
            try StockActionSupport.rejectUnexpectedArguments(request.arguments, allowed: ["path", "with_intermediates"])
            let relativePath = try StockActionSupport.requiredString(
                request.arguments,
                key: "path",
                maxBytes: StockActionLimits.relativePathBytes
            )
            let intermediates = try StockActionSupport.optionalBool(request.arguments, key: "with_intermediates")
            let directory = try StockActionSupport.confinedURL(root: root, relativePath: relativePath, allowRoot: false)
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: intermediates)
            } catch {
                throw BodyActionError.executionFailed("BODY_ACTION_DIRECTORY_CREATE_FAILED")
            }
            return BodyActionResult(
                requestID: request.id,
                capability: request.capability,
                output: ["created": .bool(true), "path": .string(relativePath)]
            )
        case "delete_file":
            try StockActionSupport.rejectUnexpectedArguments(request.arguments, allowed: ["path"])
            let relativePath = try StockActionSupport.requiredString(
                request.arguments,
                key: "path",
                maxBytes: StockActionLimits.relativePathBytes
            )
            let file = try StockActionSupport.confinedURL(root: root, relativePath: relativePath, allowRoot: false)
            return try deleteFile(request, file: file, relativePath: relativePath)
        default:
            throw BodyActionError.operationDenied(request.operation)
        }
    }

    private func listDirectory(_ request: BodyActionRequest, directory: URL) throws -> BodyActionResult {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .fileSizeKey]
        let values: [URL]
        do {
            values = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: Array(keys),
                options: []
            ).sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        } catch {
            throw BodyActionError.executionFailed("BODY_ACTION_DIRECTORY_LIST_FAILED")
        }
        let limited = values.prefix(StockActionLimits.listEntries)
        let entries: [JSONValue] = limited.map { url in
            let resource = try? url.resourceValues(forKeys: keys)
            let kind = resource?.isDirectory == true ? "directory" : (resource?.isRegularFile == true ? "file" : "other")
            let bytes: JSONValue = resource?.fileSize.map { .number(Double($0)) } ?? .null
            return .object([
                "name": .string(url.lastPathComponent),
                "kind": .string(kind),
                "bytes": bytes
            ])
        }
        return BodyActionResult(
            requestID: request.id,
            capability: request.capability,
            output: [
                "entries": .array(entries),
                "count": .number(Double(entries.count)),
                "truncated": .bool(values.count > StockActionLimits.listEntries)
            ]
        )
    }

    private func readText(_ request: BodyActionRequest, file: URL) throws -> BodyActionResult {
        let resource: URLResourceValues
        do {
            resource = try file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        } catch {
            throw BodyActionError.executionFailed("BODY_ACTION_FILE_READ_FAILED")
        }
        guard resource.isRegularFile == true else {
            throw BodyActionError.executionFailed("BODY_ACTION_FILE_NOT_REGULAR")
        }
        guard (resource.fileSize ?? 0) <= StockActionLimits.fileTextBytes else {
            throw BodyActionError.executionFailed("BODY_ACTION_FILE_TOO_LARGE")
        }
        do {
            let data = try Data(contentsOf: file, options: [.mappedIfSafe])
            guard data.count <= StockActionLimits.fileTextBytes,
                  let text = String(data: data, encoding: .utf8) else {
                throw BodyActionError.executionFailed("BODY_ACTION_FILE_TEXT_INVALID")
            }
            return BodyActionResult(
                requestID: request.id,
                capability: request.capability,
                output: ["text": .string(text), "bytes": .number(Double(data.count))]
            )
        } catch let error as BodyActionError {
            throw error
        } catch {
            throw BodyActionError.executionFailed("BODY_ACTION_FILE_READ_FAILED")
        }
    }

    private func writeText(
        _ request: BodyActionRequest,
        file: URL,
        text: String,
        overwrite: Bool
    ) throws -> BodyActionResult {
        if FileManager.default.fileExists(atPath: file.path), !overwrite {
            throw BodyActionError.executionFailed("BODY_ACTION_FILE_EXISTS")
        }
        guard let data = text.data(using: .utf8), data.count <= StockActionLimits.fileTextBytes else {
            throw BodyActionError.invalidArguments("BODY_ACTION_FILE_TEXT_INVALID")
        }
        do {
            try data.write(to: file, options: [.atomic])
        } catch {
            throw BodyActionError.executionFailed("BODY_ACTION_FILE_WRITE_FAILED")
        }
        return BodyActionResult(
            requestID: request.id,
            capability: request.capability,
            output: ["written": .bool(true), "bytes": .number(Double(data.count))]
        )
    }

    private func deleteFile(
        _ request: BodyActionRequest,
        file: URL,
        relativePath: String
    ) throws -> BodyActionResult {
        do {
            let resource = try file.resourceValues(forKeys: [.isRegularFileKey])
            guard resource.isRegularFile == true else {
                throw BodyActionError.executionFailed("BODY_ACTION_FILE_NOT_REGULAR")
            }
            try FileManager.default.removeItem(at: file)
        } catch let error as BodyActionError {
            throw error
        } catch {
            throw BodyActionError.executionFailed("BODY_ACTION_FILE_DELETE_FAILED")
        }
        return BodyActionResult(
            requestID: request.id,
            capability: request.capability,
            output: ["deleted": .bool(true), "path": .string(relativePath)]
        )
    }
}
