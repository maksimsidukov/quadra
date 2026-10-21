import XCTest
@testable import Quarda

final class MCPProtocolTests: XCTestCase {
    func testRequestDecodesWithIntId() throws {
        let data = #"{"jsonrpc":"2.0","id":1,"method":"ping"}"#.data(using: .utf8)!
        let request = try JSONDecoder().decode(JSONRPCRequest.self, from: data)
        XCTAssertEqual(request.jsonrpc, "2.0")
        XCTAssertEqual(request.id, .number(1))
        XCTAssertEqual(request.method, "ping")
        XCTAssertNil(request.params)
    }

    func testRequestDecodesWithStringId() throws {
        let data = #"{"jsonrpc":"2.0","id":"abc","method":"ping"}"#.data(using: .utf8)!
        let request = try JSONDecoder().decode(JSONRPCRequest.self, from: data)
        XCTAssertEqual(request.id, .string("abc"))
    }

    func testBoolDoesNotDecodeAsNumber() throws {
        let boolValue = try JSONDecoder().decode(JSONValue.self, from: Data("true".utf8))
        XCTAssertEqual(boolValue, .bool(true))

        let numberValue = try JSONDecoder().decode(JSONValue.self, from: Data("1".utf8))
        XCTAssertEqual(numberValue, .number(1))
    }

    func testResultResponseKeepsId() throws {
        let response = JSONRPCResponse.result(id: .string("abc"), .object([:]))
        let data = try JSONEncoder().encode(response)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["id"] as? String, "abc")
        XCTAssertEqual(object["jsonrpc"] as? String, "2.0")
        XCTAssertNotNil(object["result"] as? [String: Any])
    }
}
