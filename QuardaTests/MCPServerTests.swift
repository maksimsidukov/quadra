import Network
import XCTest
@testable import Quarda

@MainActor
final class MCPServerTests: XCTestCase {
    private var server: MCPServer!
    private var port: UInt16!

    override func setUp() {
        super.setUp()
        server = MCPServer(router: MCPRouter(tools: StubTools()), port: 0)
        try! server.start()
        port = server.actualPort
    }

    override func tearDown() {
        server.stop()
        server = nil
        super.tearDown()
    }

    private func url() -> URL {
        URL(string: "http://127.0.0.1:\(port!)/mcp")!
    }

    func testPostInitializeReturnsResult() async throws {
        var request = URLRequest(url: url())
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"#.utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertTrue(String(data: data, encoding: .utf8)?.contains("quarda-mcp") == true)
    }

    func testGetReturns405() async throws {
        let (_, response) = try await URLSession.shared.data(from: url())
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 405)
    }

    func testMalformedJSONReturnsParseError() async throws {
        var request = URLRequest(url: url())
        request.httpMethod = "POST"
        request.httpBody = Data("not json".utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertTrue(String(data: data, encoding: .utf8)?.contains("-32700") == true)
    }

    func testBodySplitAcrossWrites() async throws {
        let connection = NWConnection(
            host: "127.0.0.1",
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp
        )
        connection.start(queue: .global(qos: .userInitiated))
        defer { connection.cancel() }

        // Ждём готовности соединения.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: continuation.resume()
                case .failed(let error): continuation.resume(throwing: error)
                default: break
                }
            }
        }

        func send(_ data: Data) async throws {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                connection.send(content: data, completion: .contentProcessed { error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                })
            }
        }

        let body = Data(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"#.utf8)
        let head = "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\n\r\n"

        // Заголовки и тело уходят тремя частями с паузами — сервер обязан дочитать всё.
        try await send(Data(head.utf8) + body.prefix(10))
        try await Task.sleep(nanoseconds: 200_000_000)
        try await send(Data(body.dropFirst(10).prefix(20)))
        try await Task.sleep(nanoseconds: 200_000_000)
        try await send(Data(body.dropFirst(30)))

        let received = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            var received = Data()
            func receiveNext() {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { content, _, isComplete, error in
                    if let content { received.append(content) }
                    if let error {
                        continuation.resume(throwing: error)
                    } else if isComplete {
                        continuation.resume(returning: received)
                    } else {
                        receiveNext()
                    }
                }
            }
            receiveNext()
        }

        XCTAssertTrue(String(data: received, encoding: .utf8)?.contains("quarda-mcp") == true)
    }
}
