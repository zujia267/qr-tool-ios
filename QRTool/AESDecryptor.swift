import Foundation
import CommonCrypto

/// AES-128-ECB (PKCS7) decryption, matching the verified y2wm box-code tool:
/// Base64 ciphertext -> AES-128-ECB decrypt with a 16-byte key -> UTF-8 URL.
enum AESDecryptor {
    static func decrypt(base64 input: String, key: String) -> String? {
        guard let keyData = key.data(using: .utf8), keyData.count == 16 else { return nil }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let cipherData = Data(base64Encoded: trimmed) else { return nil }
        var outData = Data(count: cipherData.count + kCCBlockSizeAES128)
        var outLength = 0
        let status = outData.withUnsafeMutableBytes { outPtr in
            cipherData.withUnsafeBytes { cipherPtr in
                keyData.withUnsafeBytes { keyPtr in
                    CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode),
                            keyPtr.baseAddress, kCCKeySizeAES128,
                            nil,
                            cipherPtr.baseAddress, cipherData.count,
                            outPtr.baseAddress, outData.count,
                            &outLength)
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        outData.count = outLength
        return String(data: outData, encoding: .utf8)
    }
}
