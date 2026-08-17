import Foundation

struct DotEnvLoader {
    static func loadPasscode() -> String? {
        let fileManager = FileManager.default
        var possiblePaths: [String] = []

        // 1. App Bundle Resource Path (Contents/Resources/.env)
        if let bundlePath = Bundle.main.path(forResource: ".env", ofType: nil) {
            possiblePaths.append(bundlePath)
        }
        if let resourcePath = Bundle.main.resourcePath {
            possiblePaths.append((resourcePath as NSString).appendingPathComponent(".env"))
        }

        // 2. Executable Directory & Parent Directories
        let execPath = CommandLine.arguments[0]
        let execDir = (execPath as NSString).deletingLastPathComponent
        possiblePaths.append((execDir as NSString).appendingPathComponent(".env"))
        possiblePaths.append((execDir as NSString).appendingPathComponent("../Resources/.env"))

        // 3. Current Working Directory
        let currentDir = fileManager.currentDirectoryPath
        possiblePaths.append((currentDir as NSString).appendingPathComponent(".env"))
        possiblePaths.append("./.env")
        possiblePaths.append(".env")

        for path in possiblePaths {
            let normalizedPath = (path as NSString).standardizingPath
            if fileManager.fileExists(atPath: normalizedPath) {
                if let passcode = parsePasscode(fromFile: normalizedPath) {
                    print("[DotEnv] Loaded passcode from: \(normalizedPath)")
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
        var possiblePaths: [String] = []

        if let bundlePath = Bundle.main.path(forResource: ".env", ofType: nil) {
            possiblePaths.append(bundlePath)
        }
        if let resourcePath = Bundle.main.resourcePath {
            possiblePaths.append((resourcePath as NSString).appendingPathComponent(".env"))
        }

        let execPath = CommandLine.arguments[0]
        let execDir = (execPath as NSString).deletingLastPathComponent
        possiblePaths.append((execDir as NSString).appendingPathComponent(".env"))
        possiblePaths.append((execDir as NSString).appendingPathComponent("../Resources/.env"))

        let currentDir = fileManager.currentDirectoryPath
        possiblePaths.append((currentDir as NSString).appendingPathComponent(".env"))
        possiblePaths.append("./.env")
        possiblePaths.append(".env")

        for path in possiblePaths {
            let normalizedPath = (path as NSString).standardizingPath
            if fileManager.fileExists(atPath: normalizedPath) {
                if let content = try? String(contentsOfFile: normalizedPath, encoding: .utf8) {
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
                }
            }
        }

        if let sysEnv = ProcessInfo.processInfo.environment["TESTING"]?.lowercased() {
            return sysEnv == "true" || sysEnv == "1"
        }

        return false
    }
}
