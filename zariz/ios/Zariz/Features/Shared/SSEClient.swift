import Foundation

final class SSEClient: NSObject, @preconcurrency URLSessionDataDelegate {
    private var task: URLSessionDataTask?
    private var buffer = Data()
    private let url: URL
    private let onEvent: (Any) -> Void
    private let parseQueue = DispatchQueue(label: "sse.client.parse")

    init(url: URL, onEvent: @escaping (Any) -> Void) {
        self.url = url
        self.onEvent = onEvent
    }

    func start() {
        stop()
        var req = URLRequest(url: url)
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 0
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        task = session.dataTask(with: req)
        task?.resume()
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func handleChunk(_ data: Data) {
        parseQueue.async { [weak self] in
            guard let self else { return }
            self.buffer.append(data)
            let delimiter = "\n\n".data(using: .utf8)!
            while let range = self.buffer.range(of: delimiter) {
                let packet = self.buffer.subdata(in: 0..<range.lowerBound)
                self.buffer.removeSubrange(0..<range.upperBound)
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

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        handleChunk(data)
    }
}
