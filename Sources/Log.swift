import Foundation

/// Minimalny logger do pliku — ułatwia weryfikację, gdy appka działa jako agent w tle.
enum Log {
    static let path: String = {
        let dir = ("~/Library/Logs" as NSString).expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir + "/DownieClip.log"
    }()

    private static let queue = DispatchQueue(label: "com.github.sansavi.downieclip.log")
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    static func write(_ message: String) {
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        queue.async {
            if let handle = FileHandle(forWritingAtPath: path) {
                handle.seekToEndOfFile()
                if let data = line.data(using: .utf8) { handle.write(data) }
                try? handle.close()
            } else {
                try? line.write(toFile: path, atomically: true, encoding: .utf8)
            }
        }
    }
}
