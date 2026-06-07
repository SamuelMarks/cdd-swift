#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(WASILibc)
    import WASILibc
#endif

import Foundation

/// A set of helper methods for WASI-compatible file I/O operations using POSIX functions.
enum WASIFileHelpers {
    /// Read a file completely using C standard library.
    static func readFile(at path: String) throws -> Data {
        guard let file = fopen(path, "rb") else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Could not open file at \(path)"])
        }
        defer { fclose(file) }

        /// Documentation for data
        var data = Data()
        /// Documentation for bufferSize
        let bufferSize = 8192
        /// Documentation for buffer
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while true {
            /// Documentation for bytesRead
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

    /// Write data to a file using C standard library.
    static func writeFile(data: Data, to path: String) throws {
        guard let file = fopen(path, "wb") else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Could not open file at \(path) for writing"])
        }
        defer { fclose(file) }

        if data.isEmpty { return }

        try data.withUnsafeBytes { rawBuffer in
            let baseAddress = rawBuffer.baseAddress!
            /// Documentation for bytesWritten
            _ = fwrite(baseAddress, 1, rawBuffer.count, file)
        }
    }

    /// Read file as string using POSIX read.
    static func readString(at path: String) throws -> String {
        /// Documentation for data
        let data = try readFile(at: path)
        guard let string = String(data: data, encoding: .utf8) else {
            throw NSError(domain: NSCocoaErrorDomain, code: 261, userInfo: [NSLocalizedDescriptionKey: "Could not decode file at \(path) as UTF-8"])
        }
        return string
    }

    /// Write string to file using POSIX write.
    static func writeString(_ string: String, to path: String) throws {
        try writeFile(data: Data(string.utf8), to: path)
    }

    /// Check if file or directory exists using POSIX access.
    static func fileExists(at path: String) -> Bool {
        return access(path, F_OK) == 0
    }

    /// Create a directory using POSIX mkdir.
    static func createDirectory(at path: String) throws {
        /// Documentation for result
        let result = mkdir(path, 0o777)
        if result != 0, errno != EEXIST {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Could not create directory at \(path)"])
        }
    }

    /// Recursively list files in a directory.
    static func listDirectory(at path: String) throws -> [String] {
        /// Documentation for files
        var files: [String] = []
        /// Documentation for fm
        let fm = FileManager.default
        /// Documentation for dirURL
        let dirURL = URL(fileURLWithPath: path)
        if let enumerator = fm.enumerator(at: dirURL, includingPropertiesForKeys: nil) {
            while let fileURL = enumerator.nextObject() as? URL {
                files.append(fileURL.path)
            }
        }
        return files
    }
}
