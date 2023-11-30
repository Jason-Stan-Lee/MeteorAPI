import Foundation
import XCTest
@testable import MeteorAPI

fileprivate class MockAPIClient: APIClient {
    enum APIError: Error {
        case cannotPerformRequest
    }
    
    @discardableResult
    func send<Request>(_ request: Request, completion: @escaping (Result<Request.Response, Error>) -> Void) -> NetworkRequest where Request : APIRequest {
        if let mock = request.mock {
            return MockedNetworkRequest(result: mock, completion: completion)
        }
        return MockedNetworkRequest(result: .failure(APIError.cannotPerformRequest), completion: completion)
    }
}

final class APIRequestMockTests: XCTestCase {
    
    func testMock() throws {
        struct MockedRequest: APIRequest {
            struct Response: Decodable {
                var payload = "test"
            }
            let path: String = "/"
            let mock: Result<Response, Error>? = .success(Response())
        }
        
        let apiClient = MockAPIClient()
        let expectation = XCTestExpectation()
        apiClient.send(MockedRequest(), completion: { result in
            do {
                let value = try result.get()
                XCTAssert(value.payload == "test")
            } catch {
                XCTFail()
            }
            expectation.fulfill()
        })
        let waiter = XCTWaiter()
        waiter.wait(for: [expectation], timeout: 3.0)
    }
    
    func testMock_cancel() throws {
        struct MockedRequest: APIRequest {
            struct Response: Decodable {
                var payload = "test"
            }
            let path: String = "/"
            let mock: Result<Response, Error>? = .success(Response())
        }
        let apiClient = MockAPIClient()
        let expectation = XCTestExpectation()
        let requestHandler = apiClient.send(MockedRequest(), completion: { result in
            do {
                let _ = try result.get()
                XCTFail()
            } catch {
                XCTAssert((error as? URLError)?.code == .cancelled)
            }
            expectation.fulfill()
        })
        requestHandler.cancel()
        let waiter = XCTWaiter()
        waiter.wait(for: [expectation], timeout: 3.0)
    }
}
