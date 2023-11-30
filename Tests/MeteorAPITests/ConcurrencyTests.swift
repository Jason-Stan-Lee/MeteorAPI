import Foundation
import XCTest
@testable import MeteorAPI
@testable import MeteorAPIConcurrencySupport
import Alamofire
import Mocker

final class ConcurrencyTests: XCTestCase {
    
    private struct User: Codable {
        var name: String
    }
    
    override class func setUp() {
        Mock(url: URL(string: "https://www.example.com/user")!, dataType: .json, statusCode: 200, data: [
            .get: try! JSONEncoder().encode(User(name: "YuAo"))
        ]).register()
        Mock(url: URL(string: "https://www.example.com/user_failure")!, dataType: .json, statusCode: 400, data: [
            .get: Data()
        ]).register()
    }
    
    static func makeMockSession() -> Session {
        let configuration = URLSessionConfiguration.af.default
        configuration.protocolClasses = [MockingURLProtocol.self]
        let session = Alamofire.Session(configuration: configuration)
        return session
    }
    
    static func makeSimpleAPIClient() -> APIClient {
        SimpleAPIClient(session: APIClientTests.makeMockSession(), requestDefaults: APIRequestDefaults(baseURL: URL(string: "https://www.example.com")!, method: .get))
    }
    
    func testAsyncRequest() async throws {
        struct UserRequest: APIRequest {
            typealias Response = User
            let path: String = "/user"
        }
        let user = try await ConcurrencyTests.makeSimpleAPIClient().perform(UserRequest())
        XCTAssert(user.name == "YuAo")
    }
    
    func testAsyncRequest_asyncRequest_progress() async throws {
        struct UserRequest: APIRequest {
            typealias Response = User
            let path: String = "/user"
        }
        let asyncRequest = await ConcurrencyTests.makeSimpleAPIClient().send(UserRequest())
        let _ = asyncRequest.downloadProgress
        let user = try await asyncRequest.response
        XCTAssert(user.name == "YuAo")
    }
    
    func testAsyncRequest_asyncRequest_cancel() async throws {
        struct UserRequest: APIRequest {
            typealias Response = User
            let path: String = "/user"
        }
        let asyncRequest = await ConcurrencyTests.makeSimpleAPIClient().send(UserRequest())
        asyncRequest.cancel()
        do {
            let _ = try await asyncRequest.response
            XCTFail()
        } catch {
            XCTAssert(error.asAFError?.isExplicitlyCancelledError == true)
        }
    }
    
    func testAsyncRequest_asyncRequest_cancel_delayAwait() async throws {
        struct UserRequest: APIRequest {
            typealias Response = User
            let path: String = "/user"
        }
        let asyncRequest = await ConcurrencyTests.makeSimpleAPIClient().send(UserRequest())
        asyncRequest.cancel()
        do {
            try await Task.sleep(nanoseconds: NSEC_PER_SEC)
            let _ = try await asyncRequest.response
            XCTFail()
        } catch {
            XCTAssert(error.asAFError?.isExplicitlyCancelledError == true)
        }
    }
    
    func testAsyncRequest_asyncRequest_awaitTwice() async throws {
        struct UserRequest: APIRequest {
            typealias Response = User
            let path: String = "/user"
        }
        let asyncRequest = await ConcurrencyTests.makeSimpleAPIClient().send(UserRequest())
        let user1 = try await asyncRequest.response
        XCTAssert(user1.name == "YuAo")
        let user2 = try await asyncRequest.response
        XCTAssert(user2.name == "YuAo")
    }
    
    func testAsyncRequest_failure() async throws {
        struct UserRequest: APIRequest {
            typealias Response = User
            let path: String = "/user_xx"
        }
        do {
            let _ = try await ConcurrencyTests.makeSimpleAPIClient().perform(UserRequest())
            XCTFail()
        } catch {
            //expect failure
        }
    }
    
    func testAsyncRequest_cancel() async throws {
        struct UserRequest: APIRequest {
            typealias Response = User
            let path: String = "/user"
        }
        let taskHandler = Task {
            try await ConcurrencyTests.makeSimpleAPIClient().perform(UserRequest())
        }
        taskHandler.cancel()
        do {
            let _ = try await taskHandler.value
            XCTFail()
        } catch {
            XCTAssert(error is CancellationError)
        }
    }
    
    func testAsyncRequest_delayCancel() async throws {
        var mock = Mock(url: URL(string: "https://www.example.com/user_delay")!, dataType: .json, statusCode: 200, data: [
            .get: try! JSONEncoder().encode(User(name: "YuAo"))
        ])
        mock.delay = .seconds(3)
        mock.register()
        
        struct UserRequest: APIRequest {
            typealias Response = User
            let path: String = "/user_delay"
        }
        let taskHandler = Task {
            try await ConcurrencyTests.makeSimpleAPIClient().perform(UserRequest())
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0, execute: {
            taskHandler.cancel()
        })
        do {
            let _ = try await taskHandler.value
            XCTFail()
        } catch {
            XCTAssert(error.asAFError?.isExplicitlyCancelledError == true)
        }
    }
    
    func testAsyncRequest_delayCancelDetached() async throws {
        var mock = Mock(url: URL(string: "https://www.example.com/user_delay")!, dataType: .json, statusCode: 200, data: [
            .get: try! JSONEncoder().encode(User(name: "YuAo"))
        ])
        mock.delay = .seconds(3)
        mock.register()
        
        struct UserRequest: APIRequest {
            typealias Response = User
            let path: String = "/user_delay"
        }
        let taskHandler = Task.detached { () -> User in
            return try await ConcurrencyTests.makeSimpleAPIClient().perform(UserRequest())
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0, execute: {
            taskHandler.cancel()
        })
        do {
            let _ = try await taskHandler.value
            XCTFail()
        } catch {
            XCTAssert(error.asAFError?.isExplicitlyCancelledError == true)
        }
    }
    
    func testAsyncPullingTask() async throws {
        struct TaskResult: Codable {
            var hasError: Bool
        }
        
        struct Task: Codable {
            var id: String
            var result: TaskResult?
        }
        
        Mock(url: URL(string: "https://www.example.com/task_start")!, dataType: .json, statusCode: 200, data: [
            .post: try! JSONEncoder().encode(Task(id: "123", result: nil))
        ]).register()
        
        Mock(url: URL(string: "https://www.example.com/task_check?id=123")!, dataType: .json, statusCode: 200, data: [
            .get: try! JSONEncoder().encode(Task(id: "123", result: TaskResult(hasError: false)))
        ]).register()
        
        struct StartTaskRequest: APIRequest {
            typealias Response = Task
            let path: String = "/task_start"
        }
        struct CheckTaskRequest: APIRequest {
            typealias Response = Task
            let path: String = "/task_check"
            let parameters: APIRequestParameters
            let method: HTTPMethod? = .get
            init(taskID: String) {
                parameters = .urlEncoded(["id": taskID])
            }
        }
        
        let apiClient = APIClientTests.makeSimpleAPIClient()
        let _ = try await APIPollingTask.performTask(using: apiClient, initialRequest: StartTaskRequest(), coordinator: APIPollingTaskBlockCoordinator<StartTaskRequest, CheckTaskRequest, Void>(checkRequestMaker: { task in
            return CheckTaskRequest(taskID: task.id)
        }, checkResultHandler: { result in
            switch result {
            case .success(let v):
                if let result = v.result {
                    if result.hasError {
                        return .finished(.failure(URLError(.unknown)))
                    } else {
                        return .finished(.success(Void()))
                    }
                }
                return .progressing
            case .failure(let error):
                return .finished(.failure(error))
            }
        }))
    }
}

