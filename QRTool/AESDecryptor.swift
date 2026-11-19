import Foundation
import CommonCrypto

/// AES-128-ECB (PKCS7) decryption, matching the verified y2wm box-code tool:
/// Base64 ciphertext -> AES-128-ECB decrypt with a 16-byte key -> UTF-8 URL.
enum AESDecryptor {
    static func decrypt(base64 input: String, key: String) -> String? {
        guard let keyData = key.data(using: .utf8), keyData.count == 16 else { return nil }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let cipherData = Data(base64Encoded: trimmed) else { return nil }
        let keyBytes = [UInt8](keyData)
        let cipherBytes = [UInt8](cipherData)
        var outBytes = [UInt8](repeating: 0, count: cipherBytes.count + kCCBlockSizeAES128)
        var outLength = 0
        let status = CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES),
                             CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode),
                             keyBytes, kCCKeySizeAES128,
                             nil,
                             cipherBytes, cipherBytes.count,
                             &outBytes, outBytes.count,
                             &outLength)
        guard status == kCCSuccess else { return nil }
        return String(bytes: outBytes.prefix(outLength), encoding: .utf8)
    }
}
