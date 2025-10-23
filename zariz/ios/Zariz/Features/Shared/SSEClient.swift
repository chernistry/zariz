import Foundation

final class SSEClient: NSObject {
    private let delegateQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        q.qualityOfService = .userInitiated
        return q
    }()

    private var session: URLSession!

    private var task: URLSessionDataTask?
    private var buffer = Data()
    private let url: URL
    private let onEvent: (Any) -> Void

    init(url: URL, onEvent: @escaping (Any) -> Void) {
        self.url = url
        self.onEvent = onEvent
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 0
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: delegateQueue)
    }

    func start() {
        stop()
        var req = URLRequest(url: url)
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 0
        task = session.dataTask(with: req)
        task?.resume()
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    deinit { task?.cancel() }

    private func handleChunk(_ data: Data) {
        buffer.append(data)
        let delimiter = "\n\n".data(using: .utf8)!
        while let range = buffer.range(of: delimiter) {
            let packet = buffer.subdata(in: 0..<range.lowerBound)
            buffer.removeSubrange(0..<range.upperBound)
            if let line = String(data: packet, encoding: .utf8) {
                for part in line.split(separator: "\n") {
                    if part.hasPrefix("data:") {
                        let jsonStr = part.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if let payload = jsonStr.data(using: .utf8),
                           let obj = try? JSONSerialization.jsonObject(with: payload) {
                            Task { @MainActor in self.onEvent(obj) }
                        }
                    }
                }
            }
        }
    }
}

extension SSEClient: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        handleChunk(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // handle completion if needed
    }
}
