import Foundation

struct DotEnvLoader {
    static func loadPasscode() -> String? {
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath
        let envPath = (currentDir as NSString).appendingPathComponent(".env")

        guard fileManager.fileExists(atPath: envPath) else {
            return nil
        }

        do {
            let content = try String(contentsOfFile: envPath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            
            for rawLine in lines {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                if line.isEmpty || line.hasPrefix("#") { continue }
                
                let parts = line.components(separatedBy: "=")
                if parts.count >= 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces).uppercased()
                    var value = parts[1...].joined(separator: "=").trimmingCharacters(in: .whitespaces)
                    
                    // Strip surrounding quotes if present
                    if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
                        value = String(value.dropFirst().dropLast())
                    }
                    
                    if ["PASSWORD", "PASSCODE", "SENTRY_PASSWORD", "SENTRY_PASSCODE"].contains(key) {
                        return value
                    }
                }
            }
        } catch {
            print("[DotEnv] Error reading .env file: \(error)")
        }

        return nil
    }

    static func loadTestingMode() -> Bool {
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath
        let envPath = (currentDir as NSString).appendingPathComponent(".env")

        if fileManager.fileExists(atPath: envPath) {
            do {
                let content = try String(contentsOfFile: envPath, encoding: .utf8)
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
            } catch {}
        }

        if let sysEnv = ProcessInfo.processInfo.environment["TESTING"]?.lowercased() {
            return sysEnv == "true" || sysEnv == "1"
        }

        return false
    }
}
