import Foundation

struct DotEnvLoader {
    static func userHomeConfigPath() -> String {
        let home = NSString(string: "~/.sentry/.env").expandingTildeInPath
        return home
    }

    static func savePasscodeToUserHome(_ passcode: String) {
        let filePath = userHomeConfigPath()
        let dirPath = (filePath as NSString).deletingLastPathComponent
        
        do {
            try FileManager.default.createDirectory(atPath: dirPath, withIntermediateDirectories: true, attributes: nil)
            let content = "# CyberHorizon Sentry Configuration\nSENTRY_PASSWORD=\(passcode)\n"
            try content.write(toFile: filePath, atomically: true, encoding: .utf8)
            print("[DotEnv] Saved passcode to user home config: \(filePath)")
        } catch {
            print("[DotEnv] Error saving passcode to \(filePath): \(error)")
        }
    }

    static func loadPasscode() -> String? {
        let fileManager = FileManager.default
        let userHomePath = userHomeConfigPath()

        // 1. User Home Directory Config (~/.sentry/.env) - Always Highest Priority
        if fileManager.fileExists(atPath: userHomePath) {
            if let passcode = parsePasscode(fromFile: userHomePath) {
                print("[DotEnv] Loaded user passcode from: \(userHomePath)")
                return passcode
            }
        }

        // 2. Only check local development .env if running via CLI (not bundled .app)
        let isAppBundle = Bundle.main.bundlePath.hasSuffix(".app")
        if !isAppBundle {
            let currentDir = fileManager.currentDirectoryPath
            let localEnvPath = (currentDir as NSString).appendingPathComponent(".env")
            if fileManager.fileExists(atPath: localEnvPath) {
                if let passcode = parsePasscode(fromFile: localEnvPath) {
                    print("[DotEnv] Loaded CLI dev passcode from: \(localEnvPath)")
                    return passcode
                }
            }
        }

        return nil
    }

    private static func parsePasscode(fromFile path: String) -> String? {
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            
            for rawLine in lines {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                if line.isEmpty || line.hasPrefix("#") { continue }
                
                let parts = line.components(separatedBy: "=")
                if parts.count >= 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces).uppercased()
                    var value = parts[1...].joined(separator: "=").trimmingCharacters(in: .whitespaces)
                    
                    if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
                        value = String(value.dropFirst().dropLast())
                    }
                    
                    if ["PASSWORD", "PASSCODE", "SENTRY_PASSWORD", "SENTRY_PASSCODE"].contains(key) {
                        return value
                    }
                }
            }
        } catch {
            print("[DotEnv] Error reading file at \(path): \(error)")
        }
        return nil
    }

    static func loadTestingMode() -> Bool {
        let fileManager = FileManager.default
        let userHomePath = userHomeConfigPath()

        if fileManager.fileExists(atPath: userHomePath) {
            if let content = try? String(contentsOfFile: userHomePath, encoding: .utf8) {
                if parseTestingMode(fromContent: content) {
                    return true
                }
            }
        }

        let isAppBundle = Bundle.main.bundlePath.hasSuffix(".app")
        if !isAppBundle {
            let currentDir = fileManager.currentDirectoryPath
            let localEnvPath = (currentDir as NSString).appendingPathComponent(".env")
            if fileManager.fileExists(atPath: localEnvPath) {
                if let content = try? String(contentsOfFile: localEnvPath, encoding: .utf8) {
                    if parseTestingMode(fromContent: content) {
                        return true
                    }
                }
            }
        }

        if let sysEnv = ProcessInfo.processInfo.environment["TESTING"]?.lowercased() {
            return sysEnv == "true" || sysEnv == "1"
        }

        return false
    }

    private static func parseTestingMode(fromContent content: String) -> Bool {
        let lines = content.components(separatedBy: .newlines)
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.components(separatedBy: "=")
            if parts.count >= 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces).uppercased()
                var value = parts[1...].joined(separator: "=").trimmingCharacters(in: .whitespaces).lowercased()
                if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
                    value = String(value.dropFirst().dropLast())
                }
                if ["TESTING", "TEST", "TEST_MODE"].contains(key) {
                    return value == "true" || value == "1" || value == "yes"
                }
            }
        }
        return false
    }
}
