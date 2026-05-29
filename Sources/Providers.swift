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
			id: "chatgpt",
			name: "ChatGPT",
			abbreviation: "gpt",
			defaultURL: "https://platform.openai.com/home"
		),
		ProviderInfo(
			id: "claude",
			name: "Claude",
			abbreviation: "cld",
			defaultURL: "https://claude.ai/settings/usage"
		),
		ProviderInfo(
			id: "openrouter",
			name: "OpenRouter",
			abbreviation: "ort",
			defaultURL: "https://openrouter.ai/settings/credits"
		),
		ProviderInfo(
			id: "zen",
			name: "Zen",
			abbreviation: "zen",
			defaultURL: "https://opencode.ai/workspace/billing"
		),
	]
	
	static func info(for id: String) -> ProviderInfo? {
		return all.first { $0.id == id }
	}
	
	private static func enabledKey(_ id: String) -> String { "provider.\(id).enabled" }
	private static func urlKey(_ id: String) -> String { "provider.\(id).url" }
	private static func abbrevKey(_ id: String) -> String { "provider.\(id).abbreviation" }
	
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

	static func abbreviation(for info: ProviderInfo) -> String {
		let stored = UserDefaults.standard.string(forKey: abbrevKey(info.id)) ?? ""
		return stored.isEmpty ? info.abbreviation : stored
	}

	static func storedAbbreviation(for id: String) -> String {
		return UserDefaults.standard.string(forKey: abbrevKey(id)) ?? ""
	}

	static func setAbbreviation(_ id: String, _ value: String) {
		let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
		if trimmed.isEmpty {
			UserDefaults.standard.removeObject(forKey: abbrevKey(id))
		} else {
			UserDefaults.standard.set(trimmed, forKey: abbrevKey(id))
		}
	}
}
