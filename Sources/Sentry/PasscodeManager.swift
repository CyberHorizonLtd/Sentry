import Foundation
import CommonCrypto

enum PasscodeResult {
    case matchingNext
    case unlocked
    case wrongKey
}

final class PasscodeManager {
    private let targetHashes: [String]
    private var currentPrefix: String = ""
    private var currentIndex: Int = 0

    init(hashes: [String]) {
        self.targetHashes = hashes
    }

    init(passcode: String) {
        self.targetHashes = PasscodeManager.generateHashes(for: passcode)
    }

    static func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func generateHashes(for passcode: String) -> [String] {
        var hashes: [String] = []
        var prefix = ""
        for char in passcode {
            prefix.append(char)
            hashes.append(sha256(prefix))
        }
        return hashes
    }

    func reset() {
        currentPrefix = ""
        currentIndex = 0
    }

    func processCharacter(_ input: String) -> PasscodeResult {
        guard !input.isEmpty, currentIndex < targetHashes.count else { return .matchingNext }

        currentPrefix.append(input)
        let computedHash = PasscodeManager.sha256(currentPrefix)
        let expectedHash = targetHashes[currentIndex]

        if computedHash == expectedHash {
            currentIndex += 1
            if currentIndex == targetHashes.count {
                return .unlocked
            }
            return .matchingNext
        } else {
            reset()
            return .wrongKey
        }
    }
}
