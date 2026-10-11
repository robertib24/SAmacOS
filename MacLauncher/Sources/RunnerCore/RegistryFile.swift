import Foundation

/// Builds a .reg file so all registry settings are applied with a single
/// `wine reg import` (the old launcher started ~20 separate `wine reg add`
/// processes, each paying Wine's startup cost).
public struct RegistryFile: Equatable {
    public enum Value: Equatable {
        case string(String)
        case dword(UInt32)
    }

    public private(set) var sections: [(key: String, values: [(name: String, value: Value)])] = []

    public init() {}

    public mutating func set(_ key: String, _ name: String, _ value: Value) {
        if let index = sections.firstIndex(where: { $0.key == key }) {
            if let existing = sections[index].values.firstIndex(where: { $0.name == name }) {
                sections[index].values[existing].value = value
            } else {
                sections[index].values.append((name, value))
            }
        } else {
            sections.append((key, [(name, value)]))
        }
    }

    /// Text in "Windows Registry Editor Version 5.00" format.
    public func render() -> String {
        var lines = ["Windows Registry Editor Version 5.00", ""]
        for section in sections {
            lines.append("[\(section.key)]")
            for (name, value) in section.values {
                lines.append("\(Self.quote(name))=\(Self.render(value))")
            }
            lines.append("")
        }
        return lines.joined(separator: "\r\n")
    }

    /// UTF-16LE with BOM, the encoding regedit expects for version 5.00 files.
    public func encoded() -> Data {
        var data = Data([0xFF, 0xFE])
        data.append(render().data(using: .utf16LittleEndian)!)
        return data
    }

    static func quote(_ string: String) -> String {
        let escaped = string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    static func render(_ value: Value) -> String {
        switch value {
        case .string(let s): return quote(s)
        case .dword(let d): return "dword:" + String(format: "%08x", d)
        }
    }

    public static func == (lhs: RegistryFile, rhs: RegistryFile) -> Bool {
        lhs.render() == rhs.render()
    }
}

extension RegistryFile {
    /// Everything the launcher manages in the prefix registry.
    public static func launcherSettings(_ settings: Settings, gameExeWindowsPath: String) -> RegistryFile {
        let settings = settings.normalized()
        var reg = RegistryFile()
        let yesNo: (Bool) -> Value = { .string($0 ? "y" : "n") }

        let mac = #"HKEY_CURRENT_USER\Software\Wine\Mac Driver"#
        reg.set(mac, "RetinaMode", yesNo(settings.retinaMode))
        reg.set(mac, "LeftOptionIsAlt", yesNo(settings.optionKeyAsAlt))
        reg.set(mac, "RightOptionIsAlt", yesNo(settings.optionKeyAsAlt))
        // Don't keep game windows floating above other apps after Cmd-Tab.
        reg.set(mac, "WindowsFloatWhenInactive", .string("none"))

        // No "program crashed" dialogs stacking up behind a crashed game.
        reg.set(#"HKEY_CURRENT_USER\Software\Wine\WineDbg"#, "ShowCrashDialog", .dword(0))

        // samp.exe reads both of these: where the game is, and the nickname.
        let samp = #"HKEY_CURRENT_USER\Software\SAMP"#
        reg.set(samp, "gta_sa_exe", .string(gameExeWindowsPath))
        reg.set(samp, "PlayerName", .string(settings.nickname))

        return reg
    }
}
