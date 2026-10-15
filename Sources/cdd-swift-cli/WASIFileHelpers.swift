#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(WASILibc)
    import WASILibc
#endif

import CDDSwift
import Foundation

/// A set of helper methods for WASI-compatible file I/O operations using POSIX functions.
enum WASIFileHelpers {
    /// Reads a file completely into `Data` using the C standard library.
    ///
    /// - Parameter path: The filesystem path of the file to read.
    /// - Returns: The raw bytes read from the file.
    /// - Throws: `CDDError.fileIOError` if the file cannot be opened.
    static func readFile(at path: String) throws -> Data {
        guard let file = fopen(path, "rb") else {
            throw CDDError.fileIOError(
                path: path,
                operation: "read",
                errno: errno,
                message: "Could not open file at \(path)"
            )
        }
        defer { fclose(file) }

        var data = Data()
        let bufferSize = 8192
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while true {
            let bytesRead = fread(buffer, 1, bufferSize, file)
            if bytesRead > 0 {
                data.append(buffer, count: bytesRead)
            }
            if bytesRead < bufferSize {
                break
            }
        }

        return data
    }

    /// Writes `Data` to a file at the specified path using the C standard library.
    ///
    /// - Parameters:
    ///   - data: The raw bytes to write.
    ///   - path: The destination filesystem path.
    /// - Throws: `CDDError.fileIOError` if the file cannot be opened for writing.
    static func writeFile(data: Data, to path: String) throws {
        guard let file = fopen(path, "wb") else {
            throw CDDError.fileIOError(
                path: path,
                operation: "write",
                errno: errno,
                message: "Could not open file at \(path) for writing"
            )
        }
        defer { fclose(file) }

        if data.isEmpty {
            return
        }

        data.withUnsafeBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress {
                _ = fwrite(baseAddress, 1, rawBuffer.count, file)
            }
        }
    }

    /// Reads a file at the specified path as a UTF-8 `String`.
    ///
    /// - Parameter path: The filesystem path of the file to read.
    /// - Returns: The decoded UTF-8 string contents.
    /// - Throws: `CDDError.fileIOError` if reading fails, or `CDDError.utf8DecodingFailed` if the bytes are not valid UTF-8.
    static func readString(at path: String) throws -> String {
        let data = try readFile(at: path)
        guard let string = String(data: data, encoding: .utf8) else {
            throw CDDError.utf8DecodingFailed(path: path)
        }
        return string
    }

    /// Writes a UTF-8 `String` to a file at the specified path.
    ///
    /// - Parameters:
    ///   - string: The string content to write.
    ///   - path: The destination filesystem path.
    /// - Throws: `CDDError.fileIOError` if the file cannot be written.
    static func writeString(_ string: String, to path: String) throws {
        try writeFile(data: Data(string.utf8), to: path)
    }

    /// Checks whether a file or directory exists at the specified path using POSIX `access`.
    ///
    /// - Parameter path: The filesystem path to check.
    /// - Returns: `true` if the path exists and is accessible, `false` otherwise.
    static func fileExists(at path: String) -> Bool {
        return access(path, F_OK) == 0
    }

    /// Creates a single directory at the specified path using POSIX `mkdir`.
    ///
    /// - Parameter path: The directory path to create.
    /// - Throws: `CDDError.fileIOError` if directory creation fails with an error other than `EEXIST`.
    static func createDirectory(at path: String) throws {
        let result = mkdir(path, 0o777)
        if result != 0, errno != EEXIST {
            throw CDDError.fileIOError(
                path: path,
                operation: "mkdir",
                errno: errno,
                message: "Could not create directory at \(path)"
            )
        }
    }

    /// Creates a directory and all intermediate parent directories recursively.
    ///
    /// - Parameter path: The target directory path to create.
    /// - Throws: `CDDError.fileIOError` if any directory component cannot be created.
    static func createDirectoryRecursive(at path: String) throws {
        let components = path.split(separator: "/")
        var currentPath = path.hasPrefix("/") ? "/" : ""
        for component in components {
            if currentPath == "/" || currentPath.isEmpty {
                currentPath += component
            } else {
                currentPath += "/" + component
            }
            if !fileExists(at: currentPath) {
                try createDirectory(at: currentPath)
            }
        }
    }

    /// Recursively lists all file paths within a directory.
    ///
    /// - Parameter path: The root directory path to enumerate.
    /// - Returns: An array of full file paths discovered under `path`.
    /// - Throws: An error if enumeration fails.
    static func listDirectory(at path: String) throws -> [String] {
        var files: [String] = []
        let fm = FileManager.default
        let dirURL = URL(fileURLWithPath: path)
        if let enumerator = fm.enumerator(at: dirURL, includingPropertiesForKeys: nil) {
            while let fileURL = enumerator.nextObject() as? URL {
                files.append(fileURL.path)
            }
        }
        return files
    }
}
