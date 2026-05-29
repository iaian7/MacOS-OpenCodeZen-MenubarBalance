import Cocoa
import WebKit

class ProvidersWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
	weak var appDelegate: AppDelegate?
	
	private var splitView: NSSplitView!
	private var tableView: NSTableView!
	private var urlField: NSTextField!
	private var abbrevField: NSTextField!
	private var webContainer: NSView!
	private var currentWebView: WKWebView?
	private(set) var activeProviderId: String?
	
	private let initialSidebarWidth: CGFloat = 180
	
	init(owner: AppDelegate) {
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 1000, height: 600),
			styleMask: [.titled, .closable, .resizable, .miniaturizable],
			backing: .buffered,
			defer: false
		)
		window.title = "Providers"
		super.init(window: window)
		self.appDelegate = owner
		window.isReleasedWhenClosed = false
		window.center()
		buildUI()
		if !Providers.all.isEmpty {
			tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
			updateMainPane()
		}
		DispatchQueue.main.async { [weak self] in
			guard let self = self else { return }
			self.splitView.setPosition(self.initialSidebarWidth, ofDividerAt: 0)
		}
	}
	
	required init?(coder: NSCoder) { fatalError("not implemented") }
	
	private func buildUI() {
		guard let contentView = window?.contentView else { return }
		
		splitView = NSSplitView()
		splitView.isVertical = true
		splitView.dividerStyle = .thin
		splitView.translatesAutoresizingMaskIntoConstraints = false
		
		// Sidebar
		let sidebar = NSView()
		sidebar.translatesAutoresizingMaskIntoConstraints = false
		
		let scroll = NSScrollView()
		scroll.translatesAutoresizingMaskIntoConstraints = false
		scroll.hasVerticalScroller = true
		scroll.drawsBackground = false
		scroll.borderType = .noBorder
		
		tableView = NSTableView()
		tableView.headerView = nil
		tableView.allowsMultipleSelection = false
		tableView.allowsEmptySelection = false
		tableView.rowHeight = 28
		tableView.intercellSpacing = NSSize(width: 0, height: 2)
		tableView.selectionHighlightStyle = .regular
		if #available(macOS 11.0, *) {
			tableView.style = .sourceList
		}
		let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("provider"))
		col.resizingMask = .autoresizingMask
		tableView.addTableColumn(col)
		tableView.dataSource = self
		tableView.delegate = self
		scroll.documentView = tableView
		
		sidebar.addSubview(scroll)
		NSLayoutConstraint.activate([
			scroll.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
			scroll.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor),
			scroll.topAnchor.constraint(equalTo: sidebar.topAnchor),
			scroll.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor),
		])
		
		// Main pane
		let main = NSView()
		main.translatesAutoresizingMaskIntoConstraints = false
		
		urlField = NSTextField()
		urlField.translatesAutoresizingMaskIntoConstraints = false
		urlField.placeholderString = "Provider URL"
		urlField.delegate = self
		urlField.target = self
		urlField.action = #selector(commitURL(_:))
		urlField.bezelStyle = .roundedBezel
		urlField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

		abbrevField = NSTextField()
		abbrevField.translatesAutoresizingMaskIntoConstraints = false
		abbrevField.placeholderString = "abbr"
		abbrevField.delegate = self
		abbrevField.target = self
		abbrevField.action = #selector(commitAbbrev(_:))
		abbrevField.bezelStyle = .roundedBezel
		abbrevField.alignment = .center
		abbrevField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
		abbrevField.toolTip = "Short label shown in the menu bar when more than one provider is enabled"

		webContainer = NSView()
		webContainer.translatesAutoresizingMaskIntoConstraints = false
		webContainer.wantsLayer = true

		main.addSubview(abbrevField)
		main.addSubview(urlField)
		main.addSubview(webContainer)
		NSLayoutConstraint.activate([
			abbrevField.topAnchor.constraint(equalTo: main.topAnchor, constant: 10),
			abbrevField.leadingAnchor.constraint(equalTo: main.leadingAnchor, constant: 10),
			abbrevField.widthAnchor.constraint(equalToConstant: 64),
			abbrevField.firstBaselineAnchor.constraint(equalTo: urlField.firstBaselineAnchor),
			urlField.topAnchor.constraint(equalTo: main.topAnchor, constant: 10),
			urlField.leadingAnchor.constraint(equalTo: abbrevField.trailingAnchor, constant: 8),
			urlField.trailingAnchor.constraint(equalTo: main.trailingAnchor, constant: -10),
			webContainer.topAnchor.constraint(equalTo: urlField.bottomAnchor, constant: 10),
			webContainer.leadingAnchor.constraint(equalTo: main.leadingAnchor),
			webContainer.trailingAnchor.constraint(equalTo: main.trailingAnchor),
			webContainer.bottomAnchor.constraint(equalTo: main.bottomAnchor),
		])
		
		splitView.addArrangedSubview(sidebar)
		splitView.addArrangedSubview(main)
		
		contentView.addSubview(splitView)
		NSLayoutConstraint.activate([
			splitView.topAnchor.constraint(equalTo: contentView.topAnchor),
			splitView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			splitView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			splitView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
			sidebar.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
			main.widthAnchor.constraint(greaterThanOrEqualToConstant: 500),
		])
		splitView.setHoldingPriority(NSLayoutConstraint.Priority(260), forSubviewAt: 0)
	}
	
	func show(selecting id: String? = nil) {
		if let id = id, let row = providerRow(for: id) {
			tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
			updateMainPane()
		}
		NSApp.activate(ignoringOtherApps: true)
		window?.makeKeyAndOrderFront(nil)
	}
	
	func reloadSidebar() {
		tableView.reloadData()
	}
	
	// MARK: - NSTableViewDataSource
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return Providers.all.count
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		let info = Providers.all[row]
		let identifier = NSUserInterfaceItemIdentifier("ProviderRow")
		let cell: ProviderRowView
		if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? ProviderRowView {
			cell = reused
		} else {
			cell = ProviderRowView(frame: .zero)
			cell.identifier = identifier
		}
		cell.configure(info: info)
		cell.toggleHandler = { [weak self] id, enabled in
			self?.appDelegate?.setProviderEnabled(id, enabled)
		}
		return cell
	}
	
	// MARK: - NSTableViewDelegate
	
	func tableViewSelectionDidChange(_ notification: Notification) {
		updateMainPane()
	}
	
	private func providerRow(for id: String) -> Int? {
		return Providers.all.firstIndex { $0.id == id }
	}
	
	private func currentProviderInfo() -> ProviderInfo? {
		let row = tableView.selectedRow
		guard row >= 0, row < Providers.all.count else { return nil }
		return Providers.all[row]
	}
	
	private func updateMainPane() {
		guard let info = currentProviderInfo() else { return }
		activeProviderId = info.id
		urlField.stringValue = Providers.url(for: info)
		abbrevField.stringValue = Providers.abbreviation(for: info)
		window?.title = "Providers — \(info.name)"
		
		guard let state = appDelegate?.providerState(for: info.id) else { return }
		
		if currentWebView !== state.webView {
			currentWebView?.removeFromSuperview()
			let wv = state.webView!
			wv.translatesAutoresizingMaskIntoConstraints = false
			webContainer.addSubview(wv)
			NSLayoutConstraint.activate([
				wv.topAnchor.constraint(equalTo: webContainer.topAnchor),
				wv.leadingAnchor.constraint(equalTo: webContainer.leadingAnchor),
				wv.trailingAnchor.constraint(equalTo: webContainer.trailingAnchor),
				wv.bottomAnchor.constraint(equalTo: webContainer.bottomAnchor),
			])
			currentWebView = wv
		}
		
		if state.webView.url == nil {
			state.refresh()
		}
	}
	
	// MARK: - URL editing
	
	@objc private func commitURL(_ sender: Any?) {
		guard let info = currentProviderInfo() else { return }
		Providers.setURL(info.id, urlField.stringValue)
		urlField.stringValue = Providers.url(for: info)
		appDelegate?.providerState(for: info.id)?.refresh()
	}

	@objc private func commitAbbrev(_ sender: Any?) {
		guard let info = currentProviderInfo() else { return }
		Providers.setAbbreviation(info.id, abbrevField.stringValue)
		abbrevField.stringValue = Providers.abbreviation(for: info)
		appDelegate?.updateDisplay()
	}

	func controlTextDidEndEditing(_ obj: Notification) {
		guard let info = currentProviderInfo() else { return }
		if (obj.object as AnyObject) === abbrevField {
			Providers.setAbbreviation(info.id, abbrevField.stringValue)
			abbrevField.stringValue = Providers.abbreviation(for: info)
			appDelegate?.updateDisplay()
		} else {
			let typed = urlField.stringValue
			let storedOrDefault = Providers.url(for: info)
			if typed != storedOrDefault {
				Providers.setURL(info.id, typed)
			}
		}
	}
}

class ProviderRowView: NSTableCellView {
	private let checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
	private let label = NSTextField(labelWithString: "")
	private var providerId: String = ""
	var toggleHandler: ((String, Bool) -> Void)?
	
	override init(frame: NSRect) {
		super.init(frame: frame)
		checkbox.translatesAutoresizingMaskIntoConstraints = false
		label.translatesAutoresizingMaskIntoConstraints = false
		label.alignment = .left
		label.lineBreakMode = .byTruncatingTail
		addSubview(checkbox)
		addSubview(label)
		checkbox.target = self
		checkbox.action = #selector(toggled(_:))
		NSLayoutConstraint.activate([
			checkbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
			checkbox.centerYAnchor.constraint(equalTo: centerYAnchor),
			label.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: 8),
			label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
			label.centerYAnchor.constraint(equalTo: centerYAnchor),
		])
	}
	
	required init?(coder: NSCoder) { fatalError() }
	
	func configure(info: ProviderInfo) {
		providerId = info.id
		label.stringValue = info.name
		checkbox.state = Providers.isEnabled(info.id) ? .on : .off
	}
	
	@objc private func toggled(_ sender: NSButton) {
		toggleHandler?(providerId, sender.state == .on)
	}
}
