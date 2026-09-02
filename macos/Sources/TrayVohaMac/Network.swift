import Foundation

final class NeptunClient: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {
    let catalog: Catalog
    var session: URLSession!
    let lock = NSLock()
    var states: [Int: RequestState] = [:]

    init(catalog: Catalog) {
        self.catalog = catalog
        super.init()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 8
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpShouldSetCookies = false
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    deinit {
        session.invalidateAndCancel()
    }

    func getState(selectedAreaKeys: [String]) async throws -> AlertState {
        var request = URLRequest(url: neptunEndpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.setValue("TrayVoha/\(appVersion)", forHTTPHeaderField: "User-Agent")

        let data: Data = try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request)
            lock.lock()
            states[task.taskIdentifier] = RequestState(continuation: continuation)
            lock.unlock()
            task.resume()
        }

        let response: AlertsResponse
        do {
            response = try JSONDecoder().decode(AlertsResponse.self, from: data)
        } catch {
            throw AppError.message("Джерело даних повернуло некоректний JSON.")
        }

        return computeState(response: response, selectedAreaKeys: selectedAreaKeys)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection newRequest: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            finish(taskIdentifier: dataTask.taskIdentifier, result: .failure(
                AppError.message("Джерело даних повернуло помилковий HTTP-статус.")
            ))
            completionHandler(.cancel)
            return
        }

        if response.expectedContentLength > Int64(maxResponseBytes) {
            finish(taskIdentifier: dataTask.taskIdentifier, result: .failure(
                AppError.message("Джерело даних повернуло завелику відповідь.")
            ))
            completionHandler(.cancel)
            return
        }

        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        guard let state = states[dataTask.taskIdentifier] else {
            lock.unlock()
            return
        }

        if state.data.count + data.count > maxResponseBytes {
            states.removeValue(forKey: dataTask.taskIdentifier)
            lock.unlock()
            state.continuation.resume(throwing: AppError.message(
                "Джерело даних повернуло завелику відповідь."
            ))
            dataTask.cancel()
            return
        }

        state.data.append(data)
        lock.unlock()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        lock.lock()
        guard let state = states.removeValue(forKey: task.taskIdentifier) else {
            lock.unlock()
            return
        }
        let data = state.data
        lock.unlock()

        if let error {
            state.continuation.resume(throwing: error)
        } else if data.isEmpty {
            state.continuation.resume(throwing: AppError.message(
                "Джерело даних повернуло порожню відповідь."
            ))
        } else {
            state.continuation.resume(returning: data)
        }
    }

    func finish(taskIdentifier: Int, result: Result<Data, Error>) {
        lock.lock()
        guard let state = states.removeValue(forKey: taskIdentifier) else {
            lock.unlock()
            return
        }
        lock.unlock()

        switch result {
        case .success(let data): state.continuation.resume(returning: data)
        case .failure(let error): state.continuation.resume(throwing: error)
        }
    }

    func computeState(response: AlertsResponse, selectedAreaKeys: [String]) -> AlertState {
        var activeAreas: [ActiveArea] = []
        var fingerprintParts: [String] = []

        for selectionKey in selectedAreaKeys.sorted() {
            if selectionKey.hasPrefix("oblast:") {
                addOblastState(
                    selectionKey: selectionKey,
                    response: response,
                    activeAreas: &activeAreas,
                    fingerprintParts: &fingerprintParts
                )
            } else if selectionKey.hasPrefix("raion:") {
                addRaionState(
                    selectionKey: selectionKey,
                    response: response,
                    activeAreas: &activeAreas,
                    fingerprintParts: &fingerprintParts
                )
            }
        }

        return AlertState(
            fingerprint: fingerprintParts.sorted().joined(separator: ";"),
            activeAreas: activeAreas
        )
    }

    func addOblastState(
        selectionKey: String,
        response: AlertsResponse,
        activeAreas: inout [ActiveArea],
        fingerprintParts: inout [String]
    ) {
        let normalized = keyValue(selectionKey)
        guard let oblast = catalog.oblasts.first(where: { normalize($0) == normalized }) else { return }

        let wholeAlerts = response.oblasts.filter { belongsToOblast($0, oblast: oblast) }
        let raionAlerts = response.raions
            .filter { belongsToOblast($0, oblast: oblast) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        for alert in wholeAlerts {
            fingerprintParts.append(fingerprint(selectionKey, "oblast", alert))
        }
        for alert in raionAlerts {
            fingerprintParts.append(fingerprint(selectionKey, "raion", alert))
        }

        if !wholeAlerts.isEmpty {
            activeAreas.append(ActiveArea(
                selectionKey: selectionKey,
                name: oblast,
                since: earliestSince(wholeAlerts + raionAlerts)
            ))
            return
        }

        for alert in raionAlerts {
            activeAreas.append(ActiveArea(
                selectionKey: raionKey(alert.key),
                name: alert.name,
                since: parseDate(alert.since)
            ))
        }
    }

    func addRaionState(
        selectionKey: String,
        response: AlertsResponse,
        activeAreas: inout [ActiveArea],
        fingerprintParts: inout [String]
    ) {
        let normalized = keyValue(selectionKey)
        guard let raion = catalog.raions.first(where: { normalize($0.key) == normalized }) else { return }

        let raionAlerts = response.raions.filter { normalize($0.key) == normalize(raion.key) }
        let wholeAlerts = response.oblasts.filter { belongsToOblast($0, oblast: raion.oblast) }

        for alert in wholeAlerts {
            fingerprintParts.append(fingerprint(selectionKey, "oblast", alert))
        }
        for alert in raionAlerts {
            fingerprintParts.append(fingerprint(selectionKey, "raion", alert))
        }

        let matched = wholeAlerts + raionAlerts
        if !matched.isEmpty {
            activeAreas.append(ActiveArea(
                selectionKey: selectionKey,
                name: raion.name,
                since: earliestSince(matched)
            ))
        }
    }

    func belongsToOblast(_ item: AlertEntry, oblast: String) -> Bool {
        normalize(item.oblast) == normalize(oblast) || normalize(item.name) == normalize(oblast)
    }

    func earliestSince(_ alerts: [AlertEntry]) -> Date? {
        alerts.compactMap { parseDate($0.since) }.min()
    }

    func fingerprint(_ selectionKey: String, _ sourceType: String, _ alert: AlertEntry) -> String {
        "\(selectionKey)|\(sourceType)|\(normalize(alert.key))|\(alert.since ?? "")"
    }
}

func parseDate(_ value: String?) -> Date? {
    guard let value, !value.isEmpty else { return nil }
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: value) { return date }
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    return plain.date(from: value)
}
