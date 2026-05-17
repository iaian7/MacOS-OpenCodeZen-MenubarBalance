import Cocoa
import WebKit
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    var statusItem: NSStatusItem!
    var webView: WKWebView!
    var window: NSWindow!
    var timer: Timer?
    
    let targetURL = URL(string: "https://opencode.ai/workspace/wrk_01KMY2B2MFPPDQ7XXAC1YSZNCR/billing")!
    
    let intervals: [Int] = [1, 2, 5, 10, 15, 30, 60]
    let intervalKey = "refreshIntervalMinutes"
    
    var refreshIntervalMinutes: Int {
        let stored = UserDefaults.standard.integer(forKey: intervalKey)
        return stored == 0 ? 5 : stored
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "Loading..."
        }
        
        buildMenu()
        
        setupWebView()
        setupWindow()
        
        // Load the page
        refreshBalance()
        
        startTimer()
    }
    
    func buildMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Refresh Balance", action: #selector(refreshBalance), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Show Web View", action: #selector(showAuthWindow), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())
        
        // Refresh interval submenu
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
        
        // Open at Login toggle
        let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleOpenAtLogin), keyEquivalent: "")
        loginItem.state = isOpenAtLoginEnabled() ? .on : .off
        menu.addItem(loginItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    func startTimer() {
        timer?.invalidate()
        let interval = TimeInterval(refreshIntervalMinutes * 60)
        timer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(refreshBalance), userInfo: nil, repeats: true)
    }
    
    @objc func setInterval(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.tag, forKey: intervalKey)
        startTimer()
        buildMenu()
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
    
    func setupWebView() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        // Custom User Agent can sometimes help bypass basic bot checks
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    }
    
    func setupWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "OpenCode Zen Billing Auth (Close window to hide)"
        window.contentView = webView
        window.center()
        
        // Make it close instead of release so we can reuse it
        window.isReleasedWhenClosed = false
    }
    
    @objc func refreshBalance() {
        updateStatus("Refreshing...")
        webView.load(URLRequest(url: targetURL))
    }
    
    @objc func showAuthWindow() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
    
    func hideAuthWindow() {
        window.orderOut(nil)
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        
        let urlString = url.absoluteString.lowercased()
        
        // Check if we hit an auth or login wall (like GitHub OAuth)
        if urlString.contains("login") || urlString.contains("auth") || urlString.contains("github.com") {
            showAuthWindow()
            updateStatus("Auth Needed")
        } else {
            // Give the SPA a moment to fetch data and render, then extract
            extractBalance(retryCount: 0)
        }
    }
    
    func extractBalance(retryCount: Int) {
        // Look for the $XX.XX format in the body text using JavaScript regex
        let js = """
        (function() {
            var text = document.body.innerText;
            var match = text.match(/\\$[0-9]+\\.[0-9]{2}/);
            return match ? match[0] : null;
        })();
        """
        
        webView.evaluateJavaScript(js) { [weak self] (result, error) in
            guard let self = self else { return }
            
            if let balance = result as? String {
                self.updateStatus(balance)
                self.hideAuthWindow() // Hide window if it was successfully fetched
            } else {
                if retryCount < 5 {
                    // Retry every 2 seconds if not found yet (SPA might still be loading API results)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.extractBalance(retryCount: retryCount + 1)
                    }
                } else {
                    self.updateStatus("Balance ?")
                }
            }
        }
    }
    
    func updateStatus(_ text: String) {
        DispatchQueue.main.async {
            self.statusItem.button?.title = text
        }
    }
}
