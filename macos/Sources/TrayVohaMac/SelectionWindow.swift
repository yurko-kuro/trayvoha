import AppKit
import Foundation

final class SelectionWindowController: NSObject, NSWindowDelegate {
    let catalog: Catalog
    var selected: Set<String>
    var buttons: [(button: NSButton, key: String)] = []
    var accepted = false
    let window: NSWindow

    init(catalog: Catalog, selected: [String]) {
        self.catalog = catalog
        self.selected = Set(selected)
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.delegate = self
        window.title = "Вибір територій"
        window.center()
        window.isReleasedWhenClosed = false
        buildContent()
    }

    func runModal() -> [String]? {
        accepted = false
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.runModal(for: window)
        window.orderOut(nil)
        return accepted ? selected.sorted() : nil
    }

    func windowWillClose(_ notification: Notification) {
        if NSApp.modalWindow === window {
            NSApp.abortModal()
        }
    }

    func buildContent() {
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 10
        root.translatesAutoresizingMaskIntoConstraints = false

        let instruction = NSTextField(wrappingLabelWithString:
            "Розгорніть список і позначте потрібні області або райони. Вибір області означає весь регіон."
        )
        instruction.preferredMaxLayoutWidth = 550
        root.addArrangedSubview(instruction)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let content = NSStackView()
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 5
        content.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        content.translatesAutoresizingMaskIntoConstraints = false

        for oblast in catalog.oblasts {
            let oKey = oblastKey(oblast)
            let oblastButton = checkbox(title: oblast, key: oKey, bold: true)
            content.addArrangedSubview(oblastButton)

            for raion in catalog.raions.filter({ $0.oblast == oblast }) {
                let rKey = raionKey(raion.key)
                let row = NSStackView()
                row.orientation = .horizontal
                row.spacing = 0
                let spacer = NSView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                spacer.widthAnchor.constraint(equalToConstant: 24).isActive = true
                row.addArrangedSubview(spacer)
                row.addArrangedSubview(checkbox(title: raion.name, key: rKey, bold: false))
                content.addArrangedSubview(row)
            }
        }

        scroll.documentView = content
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            content.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            content.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        ])
        root.addArrangedSubview(scroll)

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8

        let clear = NSButton(title: "Зняти всі", target: self, action: #selector(clearAll))
        let flexible = NSView()
        flexible.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let cancel = NSButton(title: "Скасувати", target: self, action: #selector(cancelSelection))
        let save = NSButton(title: "Зберегти", target: self, action: #selector(saveSelection))
        save.keyEquivalent = "\r"

        buttonRow.addArrangedSubview(clear)
        buttonRow.addArrangedSubview(flexible)
        buttonRow.addArrangedSubview(cancel)
        buttonRow.addArrangedSubview(save)
        root.addArrangedSubview(buttonRow)

        let container = NSView()
        container.addSubview(root)
        window.contentView = container
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            root.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            root.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 500),
            buttonRow.widthAnchor.constraint(equalTo: root.widthAnchor),
        ])
    }

    func checkbox(title: String, key: String, bold: Bool) -> NSButton {
        let button = NSButton(checkboxWithTitle: title, target: self, action: #selector(toggle(_:)))
        button.state = selected.contains(key) ? .on : .off
        if bold {
            button.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        }
        buttons.append((button, key))
        return button
    }

    @objc func toggle(_ sender: NSButton) {
        guard let item = buttons.first(where: { $0.button === sender }) else { return }
        let key = item.key

        if sender.state == .on {
            selected.insert(key)
            if key.hasPrefix("oblast:") {
                guard let oblast = catalog.oblasts.first(where: { oblastKey($0) == key }) else { return }
                for raion in catalog.raions where raion.oblast == oblast {
                    selected.remove(raionKey(raion.key))
                }
            } else if key.hasPrefix("raion:") {
                guard let raion = catalog.raions.first(where: { raionKey($0.key) == key }) else { return }
                selected.remove(oblastKey(raion.oblast))
            }
        } else {
            selected.remove(key)
        }

        refreshButtons()
    }

    @objc func clearAll() {
        selected.removeAll()
        refreshButtons()
    }

    @objc func cancelSelection() {
        accepted = false
        NSApp.stopModal()
    }

    @objc func saveSelection() {
        accepted = true
        NSApp.stopModal()
    }

    func refreshButtons() {
        for item in buttons {
            item.button.state = selected.contains(item.key) ? .on : .off
        }
    }
}
