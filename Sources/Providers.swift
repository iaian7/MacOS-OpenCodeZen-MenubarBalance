import Foundation

struct ProviderInfo {
    let id: String
    let name: String
    let abbreviation: String
    let defaultURL: String
}

enum Providers {
    static let all: [ProviderInfo] = [
        ProviderInfo(
            id: "opencode",
            name: "OpenCode Zen",
            abbreviation: "zn",
            defaultURL: "https://opencode.ai/workspace/wrk_01KMY2B2MFPPDQ7XXAC1YSZNCR/billing"
        ),
        ProviderInfo(
            id: "anthropic",
            name: "Anthropic Claude",
            abbreviation: "an",
            defaultURL: "https://claude.ai/settings/usage"
        ),
        ProviderInfo(
            id: "openai",
            name: "OpenAI",
            abbreviation: "oa",
            defaultURL: "https://platform.openai.com/home"
        ),
        ProviderInfo(
            id: "openrouter",
            name: "OpenRouter",
            abbreviation: "or",
            defaultURL: "https://openrouter.ai/settings/credits"
        ),
    ]

    static func info(for id: String) -> ProviderInfo? {
        return all.first { $0.id == id }
    }

    private static func enabledKey(_ id: String) -> String { "provider.\(id).enabled" }
    private static func urlKey(_ id: String) -> String { "provider.\(id).url" }

    static func isEnabled(_ id: String) -> Bool {
        // Default: only opencode is on, to preserve prior single-provider behavior
        if UserDefaults.standard.object(forKey: enabledKey(id)) == nil {
            return id == "opencode"
        }
        return UserDefaults.standard.bool(forKey: enabledKey(id))
    }

    static func setEnabled(_ id: String, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: enabledKey(id))
    }

    static func url(for info: ProviderInfo) -> String {
        let stored = UserDefaults.standard.string(forKey: urlKey(info.id)) ?? ""
        return stored.isEmpty ? info.defaultURL : stored
    }

    static func storedURL(for id: String) -> String {
        return UserDefaults.standard.string(forKey: urlKey(id)) ?? ""
    }

    static func setURL(_ id: String, _ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: urlKey(id))
        } else {
            UserDefaults.standard.set(trimmed, forKey: urlKey(id))
        }
    }
}
