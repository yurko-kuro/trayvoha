import AppKit
import Foundation
import ServiceManagement
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    var catalog: Catalog!
    var settingsStore: SettingsStore!
    var settings = AppSettings()
    var client: NeptunClient!

    var statusItem: NSStatusItem!
    var statusMenuItem: NSMenuItem!
    var selectionMenuItem: NSMenuItem!
    var autostartMenuItem: NSMenuItem!
    var timer: Timer?

    var lastFingerprint: String?
    var lastIsActive: Bool?
    var checking = false
    var forcePending = false
    var manualRequested = false
    var consecutiveFailures = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if let bundleID = Bundle.main.bundleIdentifier {
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            if !others.isEmpty {
                NSApp.terminate(nil)
                return
            }
        }

        do {
            catalog = try Catalog.load()
            settingsStore = try SettingsStore(catalog: catalog)
            settings = settingsStore.load()
            client = NeptunClient(catalog: catalog)
        } catch {
            showFatal(error.localizedDescription)
            return
        }

        configureStatusMenu()
        requestNotificationAuthorization()

        if !settings.setupCompleted {
            configureTerritories(nil)
        }

        requestCheck(force: true, manual: false)
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.requestCheck(force: false, manual: false)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    func configureStatusMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon(kind: .unknown)
        statusItem.button?.toolTip = "TrayVoha — перевіряю стан"

        let menu = NSMenu()
        statusMenuItem = NSMenuItem(title: "Перевіряю стан…", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        selectionMenuItem = NSMenuItem(title: selectionSummary(), action: nil, keyEquivalent: "")
        selectionMenuItem.isEnabled = false
        menu.addItem(selectionMenuItem)
        menu.addItem(.separator())

        let configure = NSMenuItem(
            title: "Налаштувати території…",
            action: #selector(configureTerritories(_:)),
            keyEquivalent: ""
        )
        configure.target = self
        menu.addItem(configure)

        let check = NSMenuItem(
            title: "Показати стан зараз",
            action: #selector(checkNow(_:)),
            keyEquivalent: ""
        )
        check.target = self
        menu.addItem(check)

        autostartMenuItem = NSMenuItem(
            title: "Запускати разом із macOS",
            action: #selector(toggleAutostart(_:)),
            keyEquivalent: ""
        )
        autostartMenuItem.target = self
        refreshAutostartState()
        menu.addItem(autostartMenuItem)
        menu.addItem(.separator())

        let source = NSMenuItem(title: "Джерело: NEPTUN", action: nil, keyEquivalent: "")
        source.isEnabled = false
        menu.addItem(source)

        let quit = NSMenuItem(title: "Вийти", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc func configureTerritories(_ sender: Any?) {
        let controller = SelectionWindowController(catalog: catalog, selected: settings.selectedAreaKeys)
        guard let selected = controller.runModal() else { return }

        let previous = settings
        settings.selectedAreaKeys = selected
        settings.setupCompleted = true

        do {
            try settingsStore.save(settings)
        } catch {
            settings = previous
            showAlert(title: "Не вдалося зберегти вибір", body: error.localizedDescription)
            return
        }

        selectionMenuItem.title = selectionSummary()
        lastFingerprint = nil
        lastIsActive = nil
        requestCheck(force: true, manual: false)
    }

    @objc func checkNow(_ sender: Any?) {
        requestCheck(force: false, manual: true)
    }

    @objc func toggleAutostart(_ sender: Any?) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            refreshAutostartState()
        } catch {
            refreshAutostartState()
            showAlert(title: "Не вдалося змінити автозапуск", body: error.localizedDescription)
        }
    }

    @objc func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    func refreshAutostartState() {
        guard #available(macOS 13.0, *) else {
            autostartMenuItem?.state = .off
            autostartMenuItem?.isEnabled = false
            return
        }
        autostartMenuItem?.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    func requestCheck(force: Bool, manual: Bool) {
        if manual { manualRequested = true }

        let selected = settings.selectedAreaKeys
        guard !selected.isEmpty else {
            statusMenuItem.title = "Не вибрано територій"
            updateStatusIcon(kind: .unknown)
            statusItem.button?.toolTip = "TrayVoha — не вибрано територій"
            if manualRequested {
                manualRequested = false
                showAlert(
                    title: "Території не вибрані",
                    body: "Відкрийте меню TrayVoha та натисніть «Налаштувати території…»."
                )
            }
            return
        }

        if checking {
            forcePending = forcePending || force || manual
            return
        }

        checking = true
        let checkedSelection = selected

        Task { [weak self] in
            guard let self else { return }
            do {
                let state = try await self.client.getState(selectedAreaKeys: checkedSelection)
                await MainActor.run {
                    self.applyState(state, checkedSelection: checkedSelection, force: force)
                }
            } catch {
                await MainActor.run {
                    self.applyError()
                }
            }
        }
    }

    func applyState(_ state: AlertState, checkedSelection: [String], force: Bool) {
        checking = false
        guard Set(checkedSelection) == Set(settings.selectedAreaKeys) else {
            requestCheck(force: true, manual: manualRequested)
            return
        }

        consecutiveFailures = 0
        updateStatus(state)

        let changed = lastFingerprint != state.fingerprint
        if force || changed {
            showStateNotification(state, allClearTransition: lastIsActive == true && !state.isActive)
        }

        if manualRequested {
            manualRequested = false
            showAlert(
                title: state.isActive ? "Повітряна тривога" : "Тривоги немає",
                body: state.isActive ? activeAlertLines(state) : selectionLines()
            )
        }

        lastFingerprint = state.fingerprint
        lastIsActive = state.isActive
        runPendingIfNeeded()
    }

    func applyError() {
        checking = false
        consecutiveFailures += 1
        statusMenuItem.title = "Немає зв’язку з джерелом даних"
        updateStatusIcon(kind: .unknown)
        statusItem.button?.toolTip = "TrayVoha — дані недоступні"

        if manualRequested {
            manualRequested = false
            showAlert(
                title: "Не вдалося оновити стан",
                body: "Немає зв’язку з джерелом даних. Перевірка продовжиться автоматично."
            )
        }

        if consecutiveFailures == 3 {
            postNotification(
                title: "Дані тимчасово недоступні",
                body: "Не вдалося оновити стан повітряної тривоги. Перевірка продовжиться автоматично."
            )
        }

        runPendingIfNeeded()
    }

    func runPendingIfNeeded() {
        if forcePending {
            forcePending = false
            requestCheck(force: true, manual: manualRequested)
        }
    }

    func updateStatus(_ state: AlertState) {
        if !state.isActive {
            statusMenuItem.title = "Зараз: на вибраних територіях тривоги немає"
            updateStatusIcon(kind: .normal)
            statusItem.button?.toolTip = "TrayVoha — тривоги немає"
            return
        }

        statusMenuItem.title = "Зараз: тривога — \(state.activeAreas.count)"
        updateStatusIcon(kind: .alert)
        let names = state.activeAreas.map(\.name).uniqued().sorted()
        statusItem.button?.toolTip = String("TrayVoha — тривога: \(names.joined(separator: ", "))".prefix(120))
    }

    enum IconKind { case normal, alert, unknown }

    func updateStatusIcon(kind: IconKind) {
        guard let button = statusItem?.button else { return }
        let text: String
        let color: NSColor
        switch kind {
        case .normal:
            text = "●"
            color = .secondaryLabelColor
        case .alert:
            text = "●"
            color = .systemRed
        case .unknown:
            text = "!"
            color = .systemOrange
        }
        button.image = nil
        button.attributedTitle = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: color,
                .font: NSFont.boldSystemFont(ofSize: 15),
            ]
        )
    }

    func showStateNotification(_ state: AlertState, allClearTransition: Bool) {
        if state.isActive {
            postNotification(
                title: "Повітряна тривога",
                body: activeAlertLines(state) + "\n\nДжерело: NEPTUN"
            )
        } else {
            postNotification(
                title: allClearTransition ? "Відбій повітряної тривоги" : "Тривоги немає",
                body: selectionLines() + "\n\nДжерело: NEPTUN"
            )
        }
    }

    func activeAlertLines(_ state: AlertState) -> String {
        state.activeAreas.map { area in
            displayName(for: area.selectionKey) + "\nОголошено: " + formatAlertTime(area.since)
        }.joined(separator: "\n\n")
    }

    func selectionLines() -> String {
        settings.selectedAreaKeys.map(displayName).joined(separator: "\n")
    }

    func displayName(for selectionKey: String) -> String {
        if selectionKey.hasPrefix("raion:") {
            if let raion = catalog.raions.first(where: { normalize($0.key) == keyValue(selectionKey) }) {
                return "\(raion.name) (\(raion.oblast))"
            }
        } else if selectionKey.hasPrefix("oblast:") {
            if let oblast = catalog.oblasts.first(where: { normalize($0) == keyValue(selectionKey) }) {
                return oblast
            }
        }
        return selectionKey
    }

    func formatAlertTime(_ date: Date?) -> String {
        guard let date else { return "немає даних" }
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = calendar.isDateInToday(date) ? "HH:mm" : "dd.MM, HH:mm"
        return formatter.string(from: date)
    }

    func selectionSummary() -> String {
        let names = settings.selectedAreaKeys.map(displayName)
        if names.isEmpty { return "Території: нічого не вибрано" }
        if names.count <= 2 { return "Території: " + names.joined(separator: ", ") }
        return "Території: вибрано \(names.count)"
    }

    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func postNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func showAlert(title: String, body: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Гаразд")
        alert.runModal()
    }

    func showFatal(_ message: String) {
        showAlert(title: "TrayVoha не вдалося запустити", body: message)
        NSApp.terminate(nil)
    }
}
