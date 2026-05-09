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
    /// Read a file completely using POSIX read.
    static func readFile(at path: String) throws -> Data {
        let fd = open(path, O_RDONLY)
        if fd < 0 {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Could not open file at \(path)"])
        }
        defer { close(fd) }

        var data = Data()
        let bufferSize = 8192
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while true {
            let bytesRead = read(fd, buffer, bufferSize)
            if bytesRead < 0 {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Could not read file at \(path)"])
            }
            if bytesRead == 0 {
                break
            }
            data.append(buffer, count: bytesRead)
        }

        return data
    }
    
    /// Write data to a file using POSIX write.
    static func writeFile(data: Data, to path: String) throws {
        let fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o666)
        if fd < 0 {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Could not open file at \(path) for writing"])
        }
        defer { close(fd) }

        try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            var totalWritten = 0
            while totalWritten < rawBuffer.count {
                let bytesWritten = write(fd, baseAddress.advanced(by: totalWritten), rawBuffer.count - totalWritten)
                if bytesWritten < 0 {
                    throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Could not write to file at \(path)"])
                }
                totalWritten += bytesWritten
            }
        }
    }

    /// Read file as string using POSIX read.
    static func readString(at path: String) throws -> String {
        let data = try readFile(at: path)
        guard let string = String(data: data, encoding: .utf8) else {
            throw NSError(domain: NSCocoaErrorDomain, code: 261, userInfo: [NSLocalizedDescriptionKey: "Could not decode file at \(path) as UTF-8"])
        }
        return string
    }

    /// Write string to file using POSIX write.
    static func writeString(_ string: String, to path: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw NSError(domain: NSCocoaErrorDomain, code: 261, userInfo: [NSLocalizedDescriptionKey: "Could not encode string as UTF-8"])
        }
        try writeFile(data: data, to: path)
    }
}
