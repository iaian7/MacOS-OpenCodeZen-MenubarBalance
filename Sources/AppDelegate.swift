import Cocoa
import WebKit
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
	var statusItem: NSStatusItem!
	var timer: Timer?
	var providerStates: [String: ProviderState] = [:]
	var providersWindowController: ProvidersWindowController!
	
	let intervals: [Int] = [1, 2, 5, 10, 15, 30, 60]
	let intervalKey = "refreshIntervalMinutes"
	
	var refreshIntervalMinutes: Int {
		let stored = UserDefaults.standard.integer(forKey: intervalKey)
		return stored == 0 ? 5 : stored
	}
	
	func applicationDidFinishLaunching(_ notification: Notification) {
		installMainMenu()
		
		statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
		statusItem.button?.title = "Loading…"
		
		for info in Providers.all {
			providerStates[info.id] = ProviderState(info: info, owner: self)
		}
		
		providersWindowController = ProvidersWindowController(owner: self)
		
		buildMenu()
		refreshAllEnabled()
		startTimer()
	}
	
	// MARK: - Provider access
	
	func providerState(for id: String) -> ProviderState? {
		return providerStates[id]
	}
	
	func setProviderEnabled(_ id: String, _ enabled: Bool) {
		Providers.setEnabled(id, enabled)
		if enabled {
			providerStates[id]?.refresh()
		}
		updateDisplay()
	}
	
	// MARK: - Refresh
	
	@objc func refreshAllEnabled() {
		for info in Providers.all where Providers.isEnabled(info.id) {
			providerStates[info.id]?.refresh()
		}
		updateDisplay()
	}
	
	func startTimer() {
		timer?.invalidate()
		let interval = TimeInterval(refreshIntervalMinutes * 60)
		timer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(refreshAllEnabled), userInfo: nil, repeats: true)
	}
	
	@objc func setInterval(_ sender: NSMenuItem) {
		UserDefaults.standard.set(sender.tag, forKey: intervalKey)
		startTimer()
		buildMenu()
	}
	
	// MARK: - ProviderState callbacks
	
	func providerStateDidUpdate(_ state: ProviderState) {
		updateDisplay()
	}
	
	private let didAutoSurfaceAuthKey = "didAutoSurfaceAuth"
	
	func providerStateNeedsAuth(_ state: ProviderState) {
		// One-shot: on the first time we ever detect auth-needed, surface the window
		// for the user so they know where to log in. After that, stay out of the way —
		// the menubar's "Auth!" indicator is the signal, and switching tabs here would
		// interrupt the user mid-login on another provider.
		guard !UserDefaults.standard.bool(forKey: didAutoSurfaceAuthKey) else { return }
		UserDefaults.standard.set(true, forKey: didAutoSurfaceAuthKey)
		DispatchQueue.main.async {
			guard self.providersWindowController.window?.isVisible != true else { return }
			self.providersWindowController.show(selecting: state.info.id)
		}
	}
	
	// MARK: - Menu
	
	func buildMenu() {
		let menu = NSMenu()
		
		let enabled = Providers.all.filter { Providers.isEnabled($0.id) }
		if enabled.isEmpty {
			let item = NSMenuItem(title: "No providers enabled", action: nil, keyEquivalent: "")
			item.isEnabled = false
			menu.addItem(item)
		} else {
			for info in enabled {
				let bal = providerStates[info.id]?.balance ?? "…"
				let item = NSMenuItem(title: "\(info.name): \(bal)", action: nil, keyEquivalent: "")
				item.isEnabled = false
				menu.addItem(item)
			}
		}
		menu.addItem(NSMenuItem.separator())
		
		menu.addItem(NSMenuItem(title: "Show Providers Window…", action: #selector(showProvidersWindow), keyEquivalent: "s"))
		menu.addItem(NSMenuItem(title: "Refresh All", action: #selector(refreshAllEnabled), keyEquivalent: "r"))
		
		let intervalItem = NSMenuItem(title: "Refresh Interval", action: nil, keyEquivalent: "")
		let intervalMenu = NSMenu()
		for minutes in intervals {
			let title = minutes == 1 ? "1 minute" : "\(minutes) minutes"
			let item = NSMenuItem(title: title, action: #selector(setInterval(_:)), keyEquivalent: "")
			item.tag = minutes
			item.state = (minutes == refreshIntervalMinutes) ? .on : .off
			intervalMenu.addItem(item)
		}
		intervalItem.submenu = intervalMenu
		menu.addItem(intervalItem)
		
		let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleOpenAtLogin), keyEquivalent: "")
		loginItem.state = isOpenAtLoginEnabled() ? .on : .off
		menu.addItem(loginItem)
		
		menu.addItem(NSMenuItem.separator())
		menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
		statusItem.menu = menu
	}
	
	@objc func showProvidersWindow() {
		providersWindowController.show()
	}
	
	// MARK: - Main Menu
	
	private func installMainMenu() {
		let appName = ProcessInfo.processInfo.processName
		let main = NSMenu()
		
		// Application menu (its title slot is replaced by the app name automatically)
		let appItem = NSMenuItem()
		let appMenu = NSMenu()
		appMenu.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
		let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
		hideOthers.keyEquivalentModifierMask = [.command, .option]
		appMenu.addItem(hideOthers)
		appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
		appMenu.addItem(NSMenuItem.separator())
		appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
		appItem.submenu = appMenu
		main.addItem(appItem)
		
		// Edit menu — selectors route through the responder chain to the focused control
		let editItem = NSMenuItem()
		let editMenu = NSMenu(title: "Edit")
		editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
		let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
		redo.keyEquivalentModifierMask = [.command, .shift]
		editMenu.addItem(redo)
		editMenu.addItem(NSMenuItem.separator())
		editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
		editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
		editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
		let pasteMatch = NSMenuItem(title: "Paste and Match Style", action: #selector(NSTextView.pasteAsPlainText(_:)), keyEquivalent: "v")
		pasteMatch.keyEquivalentModifierMask = [.command, .option, .shift]
		editMenu.addItem(pasteMatch)
		editMenu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
		editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
		editItem.submenu = editMenu
		main.addItem(editItem)
		
		// Window menu — gives us Cmd-W close and Cmd-M minimize
		let windowItem = NSMenuItem()
		let windowMenu = NSMenu(title: "Window")
		windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
		windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
		windowMenu.addItem(NSMenuItem.separator())
		windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
		windowMenu.addItem(NSMenuItem.separator())
		windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
		windowItem.submenu = windowMenu
		main.addItem(windowItem)
		NSApp.windowsMenu = windowMenu
		
		NSApp.mainMenu = main
	}
	
	// MARK: - Open at Login
	
	func isOpenAtLoginEnabled() -> Bool {
		if #available(macOS 13.0, *) {
			return SMAppService.mainApp.status == .enabled
		}
		return false
	}
	
	@objc func toggleOpenAtLogin() {
		if #available(macOS 13.0, *) {
			do {
				if SMAppService.mainApp.status == .enabled {
					try SMAppService.mainApp.unregister()
				} else {
					try SMAppService.mainApp.register()
				}
			} catch {
				NSLog("Failed to toggle login item: \(error)")
			}
			buildMenu()
		}
	}
	
	// MARK: - Display
	
	func updateDisplay() {
		DispatchQueue.main.async {
			self.applyMenubarTitle()
			self.buildMenu()
		}
	}
	
	private func applyMenubarTitle() {
		guard let button = statusItem.button else { return }
		button.image = nil
		button.imagePosition = .noImage
		
		let enabledStates = Providers.all
		.filter { Providers.isEnabled($0.id) }
		.compactMap { providerStates[$0.id] }
		
		if enabledStates.isEmpty {
			button.attributedTitle = NSAttributedString(string: "No providers")
			return
		}
		
		if enabledStates.count == 1 {
			button.attributedTitle = NSAttributedString(
				string: enabledStates[0].balance,
				attributes: [.font: NSFont.menuBarFont(ofSize: 0)]
			)
			return
		}
		
		let rows = 2
		let cols = Int(ceil(Double(enabledStates.count) / Double(rows)))
		var rowStrings: [String] = Array(repeating: "", count: rows)
		
		for c in 0..<cols {
			var cells: [(Int, String)] = []
			for r in 0..<rows {
				let i = c * rows + r
				if i < enabledStates.count {
					let s = enabledStates[i]
					cells.append((r, "\(Providers.abbreviation(for: s.info)) \(s.balance)"))
				}
			}
			let maxLen = cells.map { $0.1.count }.max() ?? 0
			for (r, cell) in cells {
				let padded = cell.padding(toLength: maxLen, withPad: " ", startingAt: 0)
				if c > 0 { rowStrings[r] += "  " }
				rowStrings[r] += padded
			}
		}
		
		let fontSize: CGFloat = 10
		let lineHeight: CGFloat = 9
		let verticalShift: CGFloat = -4
		let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
		let para = NSMutableParagraphStyle()
		para.lineSpacing = 0
		para.maximumLineHeight = lineHeight
		para.minimumLineHeight = lineHeight
		para.alignment = .left
		
		let attrs: [NSAttributedString.Key: Any] = [
			.font: font,
			.paragraphStyle: para,
			.baselineOffset: verticalShift
		]
		let text = rowStrings.joined(separator: "\n")
		button.attributedTitle = NSAttributedString(string: text, attributes: attrs)
	}
}

// MARK: - ProviderState

class ProviderState: NSObject, WKNavigationDelegate {
	let info: ProviderInfo
	weak var owner: AppDelegate?
	var webView: WKWebView!
	var balance: String = "…"
	var authNeeded: Bool = false
	
	init(info: ProviderInfo, owner: AppDelegate) {
		self.info = info
		self.owner = owner
		super.init()
		setupWebView()
	}
	
	private func setupWebView() {
		let config = WKWebViewConfiguration()
		config.websiteDataStore = WKWebsiteDataStore.default()
		webView = WKWebView(frame: .zero, configuration: config)
		webView.navigationDelegate = self
		webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
	}
	
	func refresh() {
		balance = "…"
		owner?.providerStateDidUpdate(self)
		let urlString = Providers.url(for: info)
		guard let url = URL(string: urlString) else {
			balance = "URL?"
			owner?.providerStateDidUpdate(self)
			return
		}
		webView.load(URLRequest(url: url))
	}
	
	// MARK: WKNavigationDelegate
	
	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		guard let url = webView.url else { return }
		let s = url.absoluteString.lowercased()
		if s.contains("login") || s.contains("signin") || s.contains("/auth") || s.contains("github.com") || s.contains("accounts.google.com") {
			authNeeded = true
			balance = "Auth!"
			owner?.providerStateDidUpdate(self)
			owner?.providerStateNeedsAuth(self)
		} else {
			authNeeded = false
			extractBalance(retryCount: 0)
		}
	}
	
	private func extractBalance(retryCount: Int) {
		let js = """
		(function() {
			function fmt(n) {
				if (!isFinite(n)) return null;
				return (n < 0 ? '-$' : '$') + Math.abs(n).toFixed(2);
			}
			function parseAmount(s) {
				if (!s) return null;
				var m = s.match(/([-−])?\\s*\\$?\\s*([-−])?\\s*([0-9]+(?:\\.[0-9]+)?)/);
				if (!m) return null;
				var sign = (m[1] || m[2]) ? -1 : 1;
				return sign * Number(m[3]);
			}
			var card = document.querySelector('[aria-label^="Remaining credits" i], [aria-label^="Current balance" i], [aria-label^="Credit balance" i], [aria-label^="Balance:" i]');
			if (card) {
				var n = parseAmount(card.getAttribute('aria-label'));
				if (n !== null) return fmt(n);
			}
			var nodes = document.querySelectorAll('div, span, p, td, th, dt');
			for (var i = 0; i < nodes.length; i++) {
				var t = (nodes[i].textContent || '').trim();
				if (t === 'Credit balance' || t === 'Current balance' || t === 'Remaining credits') {
					var sib = nodes[i].nextElementSibling;
					var val = sib ? parseAmount(sib.textContent) : null;
					if (val !== null) return fmt(val);
					var parent = nodes[i].parentElement;
					if (parent) {
						val = parseAmount(parent.textContent.replace(t, ''));
						if (val !== null) return fmt(val);
					}
				}
			}
			var text = document.body.innerText;
			var spent = text.match(/\\$([0-9]+(?:\\.[0-9]+)?)\\s+of\\s+\\$([0-9]+(?:\\.[0-9]+)?)\\s+spent/i);
			if (spent) return fmt(Number(spent[2]) - Number(spent[1]));
			var match = text.match(/([-−])?\\$([-−])?([0-9]+(?:\\.[0-9]+)?)/);
			if (match) {
				var sign = (match[1] || match[2]) ? -1 : 1;
				return fmt(sign * Number(match[3]));
			}
			return null;
		})();
		"""
		webView.evaluateJavaScript(js) { [weak self] result, _ in
			guard let self = self else { return }
			if let value = result as? String {
				self.balance = value
				self.owner?.providerStateDidUpdate(self)
			} else if retryCount < 5 {
				DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
					self.extractBalance(retryCount: retryCount + 1)
				}
			} else {
				self.balance = "?"
				self.owner?.providerStateDidUpdate(self)
			}
		}
	}
}
