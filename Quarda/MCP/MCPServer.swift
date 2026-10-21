import Foundation
import Network

/// Локальный HTTP-сервер MCP поверх NWListener. Слушает только loopback.
/// Все колбэки Network.framework выполняются на внутренней serial-очереди,
/// обращение к задачам — через MCPRouter/TaskToolHandler на MainActor.
final class MCPServer: @unchecked Sendable {
    struct StartError: Error, CustomStringConvertible {
        let description: String
    }

    private struct HTTPRequest {
        let method: String
        let path: String
        let body: Data
    }

    private let router: MCPRouter
    private let requestedPort: UInt16
    private let queue = DispatchQueue(label: "ru.msidukov.Quarda.mcp")
    private var listener: NWListener?

    /// Фактический порт после start() (полезно при порте 0 в тестах).
    private(set) var actualPort: UInt16?

    init(router: MCPRouter, port: UInt16 = 31415) {
        self.router = router
        self.requestedPort = port
    }

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .loopback
        guard let port = NWEndpoint.Port(rawValue: requestedPort) else {
            throw StartError(description: "Invalid port: \(requestedPort)")
        }

        let listener: NWListener
        do {
            listener = try NWListener(using: parameters, on: port)
        } catch {
            throw StartError(description: "Cannot create listener: \(error.localizedDescription)")
        }

        final class Outcome: @unchecked Sendable {
            var error: String?
        }
        let outcome = Outcome()
        let semaphore = DispatchSemaphore(value: 0)

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                semaphore.signal()
            case .failed(let error):
                outcome.error = error.localizedDescription
                semaphore.signal()
            case .cancelled:
                outcome.error = outcome.error ?? "Listener cancelled"
                semaphore.signal()
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: queue)
        semaphore.wait()

        if let error = outcome.error {
            throw StartError(
                description: "Cannot listen on 127.0.0.1:\(requestedPort): \(error)"
            )
        }
        self.listener = listener
        self.actualPort = listener.port?.rawValue
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connections (вызываются на self.queue)

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveMore(connection, buffer: Data())
    }

    private func receiveMore(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) {
            [weak self] content, _, isComplete, error in
            var buffer = buffer
            if let content {
                buffer.append(content)
            }
            if let request = Self.parseHTTPRequest(buffer) {
                self?.respond(connection, to: request)
            } else if isComplete || error != nil {
                connection.cancel()
            } else {
                self?.receiveMore(connection, buffer: buffer)
            }
        }
    }

    /// Парсит HTTP-запрос целиком; возвращает nil, пока данных недостаточно.
    private static func parseHTTPRequest(_ buffer: Data) -> HTTPRequest? {
        guard let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) else {
            return nil
        }
        guard let headerString = String(data: buffer[..<headerEnd.lowerBound], encoding: .utf8) else {
            return nil
        }
        var lines = headerString.components(separatedBy: "\r\n")
        let requestLine = lines.removeFirst()
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }

        var contentLength = 0
        for line in lines {
            let header = line.split(separator: ":", maxSplits: 1)
            guard header.count == 2 else { continue }
            if header[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" {
                contentLength = Int(header[1].trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }

        let bodyStart = headerEnd.upperBound
        guard buffer.count >= bodyStart + contentLength else { return nil }

        return HTTPRequest(
            method: String(parts[0]),
            path: String(parts[1]),
            body: buffer.subdata(in: bodyStart..<(bodyStart + contentLength))
        )
    }

    private func respond(_ connection: NWConnection, to request: HTTPRequest) {
        switch (request.method, request.path) {
        case ("POST", "/mcp"):
            let router = self.router
            Task {
                let (status, body) = await Self.handleRPC(request.body, router: router)
                self.send(connection, status: status, body: body)
            }
        case ("GET", "/mcp"):
            send(connection, status: "405 Method Not Allowed", body: Data())
        default:
            send(connection, status: "404 Not Found", body: Data())
        }
    }

    private static func handleRPC(
        _ body: Data,
        router: MCPRouter
    ) async -> (status: String, body: Data) {
        guard let parsed = try? JSONSerialization.jsonObject(with: body) else {
            return ("200 OK", encode(JSONRPCResponse.error(id: nil, code: -32700, message: "Parse error")))
        }
        guard parsed is [String: Any] else {
            return ("200 OK", encode(JSONRPCResponse.error(
                id: nil,
                code: -32600,
                message: "Invalid Request: batch requests are not supported"
            )))
        }
        guard let request = try? JSONDecoder().decode(JSONRPCRequest.self, from: body) else {
            return ("200 OK", encode(JSONRPCResponse.error(id: nil, code: -32600, message: "Invalid Request")))
        }
        guard let response = await router.handle(request) else {
            return ("202 Accepted", Data())
        }
        return ("200 OK", encode(response))
    }

    private static func encode(_ value: JSONValue) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    private func send(_ connection: NWConnection, status: String, body: Data) {
        let head = "HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var data = Data(head.utf8)
        data.append(body)
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
