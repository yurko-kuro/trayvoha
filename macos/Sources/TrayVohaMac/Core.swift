import Foundation

let appVersion = "1.0.0"
let neptunEndpoint = URL(string: "https://neptun.in.ua/api/v1/alerts")!
let maxResponseBytes = 1_048_576
let pollInterval: TimeInterval = 10

func normalize(_ value: String) -> String {
    value.precomposedStringWithCanonicalMapping
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
}

func oblastKey(_ oblast: String) -> String { "oblast:" + normalize(oblast) }
func raionKey(_ key: String) -> String { "raion:" + normalize(key) }
func keyValue(_ selectionKey: String) -> String {
    guard let separator = selectionKey.firstIndex(of: ":") else { return "" }
    return String(selectionKey[selectionKey.index(after: separator)...])
}

struct Catalog: Decodable {
    let oblasts: [String]
    let raions: [Raion]

    struct Raion: Decodable {
        let key: String
        let name: String
        let oblast: String
    }

    static func load() throws -> Catalog {
        guard let url = Bundle.main.url(forResource: "districts", withExtension: "json") else {
            throw AppError.message("Не знайдено каталог територій districts.json.")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Catalog.self, from: data)
    }

    var validSelectionKeys: Set<String> {
        Set(oblasts.map(oblastKey) + raions.map { raionKey($0.key) })
    }
}

struct AppSettings: Codable {
    var version: Int = 2
    var setupCompleted: Bool = false
    var selectedAreaKeys: [String] = []
}

final class SettingsStore {
    let catalog: Catalog
    let settingsURL: URL

    init(catalog: Catalog) throws {
        self.catalog = catalog
        let fm = FileManager.default
        let base = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("TrayVoha", isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        settingsURL = directory.appendingPathComponent("settings.json")
    }

    func load() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsURL),
              var settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        if settings.version < 2 {
            settings = AppSettings()
        }
        settings.selectedAreaKeys = sanitize(settings.selectedAreaKeys)
        return settings
    }

    func save(_ settings: AppSettings) throws {
        var sanitized = settings
        sanitized.version = 2
        sanitized.selectedAreaKeys = sanitize(settings.selectedAreaKeys)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(sanitized)
        try data.write(to: settingsURL, options: .atomic)
    }

    func sanitize(_ values: [String]) -> [String] {
        Array(Set(values.filter(catalog.validSelectionKeys.contains))).sorted()
    }
}

struct AlertsResponse: Decodable {
    let version: Int?
    let updatedAt: String?
    let raions: [AlertEntry]
    let oblasts: [AlertEntry]
}

struct AlertEntry: Decodable {
    let key: String
    let name: String
    let oblast: String
    let since: String?
}

struct ActiveArea {
    let selectionKey: String
    let name: String
    let since: Date?
}

struct AlertState {
    let fingerprint: String
    let activeAreas: [ActiveArea]
    var isActive: Bool { !activeAreas.isEmpty }
}

enum AppError: Error, LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}

final class RequestState {
    var data = Data()
    let continuation: CheckedContinuation<Data, Error>

    init(continuation: CheckedContinuation<Data, Error>) {
        self.continuation = continuation
    }
}

extension Array where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0.lowercased()).inserted }
    }
}
