import Foundation

enum PasscodeResult {
    case matchingNext
    case unlocked
    case wrongKey
}

final class PasscodeManager {
    private let targetPasscode: String
    private var currentIndex: Int = 0

    init(passcode: String) {
        self.targetPasscode = passcode
    }

    func reset() {
        currentIndex = 0
    }

    func processCharacter(_ input: String) -> PasscodeResult {
        guard !input.isEmpty else { return .matchingNext }
        
        let targetChars = Array(targetPasscode)
        guard currentIndex < targetChars.count else {
            return .unlocked
        }

        // Compare first character of input with expected character in passcode
        let expectedChar = String(targetChars[currentIndex])
        
        if input == expectedChar {
            currentIndex += 1
            if currentIndex == targetChars.count {
                return .unlocked
            }
            return .matchingNext
        } else {
            // Reset index on wrong key to require full password entry again
            currentIndex = 0
            return .wrongKey
        }
    }
}
