import Foundation

struct DocumentResult: Identifiable {
    let id = UUID()
    let name: String
    let urls: [String]
    let failedLines: Int
    let totalLines: Int
}

enum Processor {
    /// Process one document's text, one line at a time:
    /// - http(s) lines pass through unchanged
    /// - other lines are treated as Base64 AES-128-ECB ciphertexts and decrypted with `key`
    /// URLs are de-duplicated, keeping first-seen order.
    static func process(name: String, text: String, key: String) -> DocumentResult {
        var urls: [String] = []
        var seen = Set<String>()
        var failed = 0
        var total = 0
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            total += 1
            if line.hasPrefix("http://") || line.hasPrefix("https://") {
                if seen.insert(line).inserted { urls.append(line) }
            } else if let plain = AESDecryptor.decrypt(base64: line, key: key),
                      plain.hasPrefix("http://") || plain.hasPrefix("https://") {
                if seen.insert(plain).inserted { urls.append(plain) }
            } else {
                failed += 1
            }
        }
        return DocumentResult(name: name, urls: urls, failedLines: failed, totalLines: total)
    }
}
