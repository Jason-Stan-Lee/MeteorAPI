import Foundation
import XCTest
@testable import MeteorAPI
import Alamofire
import Mocker

fileprivate extension InputStream {
    func readString(bufferSize: Int = 4096) -> String {
        guard let data = NSMutableData(capacity: bufferSize) else { return "" }
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        self.open()
        defer {
            self.close()
        }
        var bytesRead = 0
        repeat {
            bytesRead = read(buffer, maxLength: bufferSize)
            data.append(buffer, length: bytesRead)
        } while bytesRead == bufferSize
        
        let string = String(data: data as Data, encoding: .utf8)
        return string ?? ""
    }
}

final class APIClientTests: XCTestCase {
    
    private struct User: Codable {
        var name: String
    }
    
    override class func setUp() {
        Mock(url: URL(string: "https://www.example.com/user_post")!, dataType: .json, statusCode: 200, data: [
            .post: try! JSONEncoder().encode(User(name: "YuAo"))
        ]).register()
        
        Mock(url: URL(string: "https://www.example.com/user_get")!, dataType: .json, statusCode: 200, data: [
            .get: try! JSONEncoder().encode(User(name: "YuAo"))
        ]).register()
        
        Mock(url: URL(string: "https://www.example.com/user_failure")!, dataType: .json, statusCode: 400, data: [
            .post: Data()
        ]).register()
    }
    
    static func makeMockSession() -> Session {
        let configuration = URLSessionConfiguration.af.default
        configuration.protocolClasses = [MockingURLProtocol.self]
        let session = Alamofire.Session(configuration: configuration)
        return session
    }
    
    static func makeSimpleAPIClient(defaultHTTPMethod: HTTPMethod = .post) -> APIClient {
        SimpleAPIClient(session: APIClientTests.makeMockSession(), requestDefaults: APIRequestDefaults(baseURL: URL(string: "https://www.example.com")!, method: defaultHTTPMethod))
    }
    
    func testJSONParameters() throws {
        var mock = Mock(url: URL(string: "https://www.example.com/test_json_parameters")!, dataType: .json, statusCode: 200, data: [
            .post: try! JSONEncoder().encode(Empty.value)
        ])
        mock.onRequest = { request, parameters in
            XCTAssert(request.httpBodyStream?.readString() == "{\"id\":123}")
        }
        mock.register()
        
        let apiClient = APIClientTests.makeSimpleAPIClient()
        
        struct Request: APIRequest {
            typealias Response = Empty
            let path: String = "/test_json_parameters"
            let parameters: APIRequestParameters = .jsonEncoded(["id": 123])
        }
        let expectation = XCTestExpectation()
        apiClient.send(Request(), completion: { result in
            do {
                let _ = try result.get()
            } catch {
                XCTFail()
            }
            expectation.fulfill()
        })
        XCTWaiter().wait(for: [expectation], timeout: 3.0)
    }
    
    func testJSONParameters_dictionary() throws {
        var mock = Mock(url: URL(string: "https://www.example.com/test_json_parameters_dict")!, dataType: .json, statusCode: 200, data: [
            .post: try! JSONEncoder().encode(Empty.value)
        ])
        mock.onRequest = { request, parameters in
            XCTAssert(request.httpBodyStream?.readString() == "{\"id\":123}")
        }
        mock.register()
        
        let apiClient = APIClientTests.makeSimpleAPIClient()
        
        struct Request: APIRequest {
            typealias Response = Empty
            let path: String = "/test_json_parameters_dict"
            let parameters: APIRequestParameters = .jsonEncoded(dictionary: ["id": 123])
        }
        let expectation = XCTestExpectation()
        apiClient.send(Request(), completion: { result in
            do {
                let _ = try result.get()
            } catch {
                XCTFail()
            }
            expectation.fulfill()
        })
        XCTWaiter().wait(for: [expectation], timeout: 3.0)
    }
    
    func testJSONParameters_dictionary_multi() throws {
        var mock = Mock(url: URL(string: "https://www.example.com/test_json_parameters_dict_multi")!, dataType: .json, statusCode: 200, data: [
            .post: try! JSONEncoder().encode(Empty.value)
        ])
        mock.onRequest = { request, parameters in
            do {
                let data = try XCTUnwrap(request.httpBodyStream?.readString().data(using: .utf8))
                let jsonObject = try JSONSerialization.jsonObject(with: data)
                XCTAssertEqual((jsonObject as AnyObject).value(forKey: "id") as? Int, 123)
                XCTAssertEqual((jsonObject as AnyObject).value(forKey: "name") as? String, "YuAo")
            } catch {
                XCTFail()
            }
        }
        mock.register()
        
        let apiClient = APIClientTests.makeSimpleAPIClient()
        
        struct Request: APIRequest {
            typealias Response = Empty
            let path: String = "/test_json_parameters_dict_multi"
            let parameters: APIRequestParameters = .jsonEncoded(dictionary: ["id": 123,
                                                                             "name": "YuAo"])
        }
        let expectation = XCTestExpectation()
        apiClient.send(Request(), completion: { result in
            do {
                let _ = try result.get()
            } catch {
                XCTFail()
            }
            expectation.fulfill()
        })
        XCTWaiter().wait(for: [expectation], timeout: 3.0)
    }

    
    func testJSONParameters_withDefaultParameters() throws {
        var mock = Mock(url: URL(string: "https://www.example.com/test_json_parameters_with_defaults")!, dataType: .json, statusCode: 200, data: [
            .post: try! JSONEncoder().encode(Empty.value)
        ])
        mock.onRequest = { request, parameters in
            XCTAssert(request.httpBodyStream?.readString() == "{\"type\":\"0\",\"id\":123}")
        }
        mock.register()
        
        let apiClient = SimpleAPIClient(session: APIClientTests.makeMockSession(), requestDefaults: APIRequestDefaults(baseURL: URL(string: "https://www.example.com")!, method: .post, parameters: ["type": "0"]))
        
        struct Request: APIRequest {
            typealias Response = Empty
            let path: String = "/test_json_parameters_with_defaults"
            let parameters: APIRequestParameters = .jsonEncoded(["id": 123])
        }
        let expectation = XCTestExpectation()
        apiClient.send(Request(), completion: { result in
            do {
                let _ = try result.get()
            } catch {
                XCTFail()
            }
            expectation.fulfill()
        })
        XCTWaiter().wait(for: [expectation], timeout: 3.0)
    }
    
    func testPostParameters_single() throws {
        var mock = Mock(url: URL(string: "https://www.example.com/test_post_parameters_single")!, dataType: .json, statusCode: 200, data: [
            .post: try! JSONEncoder().encode(Empty.value)
        ])
        mock.onRequest = { request, parameters in
            XCTAssert(request.httpBodyStream?.readString() == "id=123")
        }
        mock.register()
        
        let apiClient = APIClientTests.makeSimpleAPIClient()

        struct Request: APIRequest {
            typealias Response = Empty
            let path: String = "/test_post_parameters_single"
            let parameters: APIRequestParameters = .urlEncoded(["id": "123"])
        }
        let expectation = XCTestExpectation()
        apiClient.send(Request(), completion: { result in
            do {
                let _ = try result.get()
            } catch {
                XCTFail()
            }
            expectation.fulfill()
        })
        XCTWaiter().wait(for: [expectation], timeout: 3.0)
    }
    
    func testPostParameters_multiple() throws {
        var mock = Mock(url: URL(string: "https://www.example.com/test_post_parameters_multiple")!, dataType: .json, statusCode: 200, data: [
            .post: try! JSONEncoder().encode(Empty.value)
        ])
        mock.onRequest = { request, parameters in
            XCTAssert(
                request.httpBodyStream?.readString() == "id=123&name=YuAo" ||
                request.httpBodyStream?.readString() == "name=YuAo&id=123"
            )
        }
        mock.register()
        
        let apiClient = APIClientTests.makeSimpleAPIClient()
        
        struct Request: APIRequest {
            typealias Response = Empty
            let path: String = "/test_post_parameters_multiple"
            let parameters: APIRequestParameters = .urlEncoded([
                "id": "123",
                "name": "YuAo"
            ])
        }
        let expectation = XCTestExpectation()
        apiClient.send(Request(), completion: { result in
            do {
                let _ = try result.get()
            } catch {
                XCTFail()
            }
            expectation.fulfill()
        })
        XCTWaiter().wait(for: [expectation], timeout: 3.0)
    }
    
    func testRequestUser_get() throws {
        let apiClient = APIClientTests.makeSimpleAPIClient()
        
        struct UserRequest: APIRequest {
            typealias Response = User
            let path: String = "/user_get"
            let method: HTTPMethod? = .get
        }
        let expectation = XCTestExpectation()
        apiClient.send(UserRequest(), completion: { result in
            do {
                let value = try result.get()
                XCTAssert(value.name == "YuAo")
            } catch {
                XCTFail()
            }
            expectation.fulfill()
        })
        XCTWaiter().wait(for: [expectation], timeout: 3.0)
    }
    
    func testRequestUser_queryItems_get() throws {
        let apiClient = APIClientTests.makeSimpleAPIClient()
        
        let mock = Mock(url: URL(string: "https://www.example.com/user_get?id=123")!, dataType: .json, statusCode: 200, data: [
            .get: try! JSONEncoder().encode(User(name: "YuAo"))
        ])
        mock.register()
        
        do {
            struct UserRequest: APIRequest {
                typealias Response = User
                let path: String = "/user_get"
                let method: HTTPMethod? = .get
                let parameters: APIRequestParameters = .urlEncoded(["id": "123"])
            }
            
            let expectation = XCTestExpectation()
            apiClient.send(UserRequest(), completion: { result in
                do {
                    let value = try result.get()
                    XCTAssert(value.name == "YuAo")
                } catch {
                    XCTFail()
                }
                expectation.fulfill()
            })
            XCTWaiter().wait(for: [expectation], timeout: 3.0)
        }
        
        do {
            struct UserRequest: APIRequest {
                typealias Response = User
                let path: String = "/user_get"
                let method: HTTPMethod? = .get
                let queryItems: [URLQueryItem] = [URLQueryItem(name: "id", value: "123")]
            }
            
            let expectation = XCTestExpectation()
            apiClient.send(UserRequest(), completion: { result in
                do {
                    let value = try result.get()
                    XCTAssert(value.name == "YuAo")
                } catch {
                    XCTFail()
                }
                expectation.fulfill()
            })
            XCTWaiter().wait(for: [expectation], timeout: 3.0)
        }
    }
    
    func testRequestUser_queryItems_post() throws {
        let apiClient = APIClientTests.makeSimpleAPIClient()
        
        var mock = Mock(url: URL(string: "https://www.example.com/user_post?id=123")!, dataType: .json, statusCode: 200, data: [
            .post: try! JSONEncoder().encode(User(name: "YuAo"))
        ])
        mock.onRequest = { request, parameters in
            XCTAssert(request.httpBodyStream?.readString() == "name=YuAo")
        }
        mock.register()
        
        struct UserRequest: APIRequest {
            typealias Response = User
            let path: String = "/user_post"
            let parameters: APIRequestParameters = .urlEncoded(["name": "YuAo"])
            let queryItems: [URLQueryItem] = [URLQueryItem(name: "id", value: "123")]
        }
        
        let expectation = XCTestExpectation()
        apiClient.send(UserRequest(), completion: { result in
            do {
                let value = try result.get()
                XCTAssert(value.name == "YuAo")
            } catch {
                XCTFail()
            }
            expectation.fulfill()
        })
        XCTWaiter().wait(for: [expectation], timeout: 3.0)
    }
    
    func testRequestUser() throws {
        let apiClient = APIClientTests.makeSimpleAPIClient()

        struct UserRequest: APIRequest {
            typealias Response = User
            let path: String = "/user_post"
        }
        let expectation = XCTestExpectation()
        apiClient.send(UserRequest(), completion: { result in
            do {
                let value = try result.get()
                XCTAssert(value.name == "YuAo")
            } catch {
                XCTFail()
            }
            expectation.fulfill()
        })
        XCTWaiter().wait(for: [expectation], timeout: 3.0)
    }
    
    func testRequestUser_cancel() throws {
        let apiClient = APIClientTests.makeSimpleAPIClient()
        
        struct UserRequest: APIRequest {
            typealias Response = User
            let path: String = "/user_post"
        }
        let expectation = XCTestExpectation()
        let request = apiClient.send(UserRequest(), completion: { result in
            do {
                let _ = try result.get()
                XCTFail()
            } catch {
                XCTAssert(error.asAFError?.isExplicitlyCancelledError == true)
            }
            expectation.fulfill()
        })
        request.cancel()
        XCTWaiter().wait(for: [expectation], timeout: 3.0)
    }
    
    func testRequestUser_cancelAll() throws {
        let apiClient = SimpleAPIClient(session: APIClientTests.makeMockSession(), requestDefaults: APIRequestDefaults(baseURL: URL(string: "https://www.example.com")!, method: .post))
        struct UserRequest: APIRequest {
            typealias Response = User
            let path: String = "/user_post"
        }
        let expectation = XCTestExpectation()
        let _ = apiClient.send(UserRequest(), completion: { result in
            do {
                let _ = try result.get()
                XCTFail()
            } catch {
                XCTAssert(error.asAFError?.isExplicitlyCancelledError == true)
            }
            expectation.fulfill()
        })
        apiClient.cancelAllRequests()
        XCTWaiter().wait(for: [expectation], timeout: 3.0)
    }
    
    func testRequestUser_emptyResponse() throws {
        let apiClient = APIClientTests.makeSimpleAPIClient()

        struct UserRequest: APIRequest {
            typealias Response = Empty
            let path: String = "/user_post"
        }
        let expectation = XCTestExpectation()
        apiClient.send(UserRequest(), completion: { result in
            do {
                let _ = try result.get()
            } catch {
                XCTFail()
            }
            expectation.fulfill()
        })
        XCTWaiter().wait(for: [expectation], timeout: 3.0)
    }
    
    func testRequestUser_methodFailure() throws {
        let apiClient = APIClientTests.makeSimpleAPIClient()

        struct UserRequest: APIRequest {
            typealias Response = User
            let path: String = "/user_post"
            let method: HTTPMethod? = .get
        }
        let expectation = XCTestExpectation()
        apiClient.send(UserRequest(), completion: { result in
            do {
                let _ = try result.get()
                XCTFail()
            } catch {
                let _ = error
            }
            expectation.fulfill()
        })
        XCTWaiter().wait(for: [expectation], timeout: 3.0)
    }
    
    func testRequestUser_defaultMethodFailure() throws {
        let apiClient = APIClientTests.makeSimpleAPIClient(defaultHTTPMethod: .get)

        struct UserRequest: APIRequest {
            typealias Response = User
            let path: String = "/user_post"
        }
        let expectation = XCTestExpectation()
        apiClient.send(UserRequest(), completion: { result in
            do {
                let _ = try result.get()
                XCTFail()
            } catch {
                let _ = error
            }
            expectation.fulfill()
        })
        XCTWaiter().wait(for: [expectation], timeout: 3.0)
    }
    
    func testRequestUser_decodeFailure() throws {
        let apiClient = APIClientTests.makeSimpleAPIClient()

        struct UserRequest: APIRequest {
            struct Response: Decodable {
                var name: Int
            }
            let path: String = "/user_post"
        }
        let expectation = XCTestExpectation()
        apiClient.send(UserRequest(), completion: { result in
            do {
                let _ = try result.get()
                XCTFail()
            } catch {
                XCTAssert(error is DecodingError)
            }
            expectation.fulfill()
        })
        XCTWaiter().wait(for: [expectation], timeout: 3.0)
    }
    
    func testRequestUser_emptyResponse_failure() throws {
        let apiClient = APIClientTests.makeSimpleAPIClient()

        struct UserRequest: APIRequest {
            typealias Response = Empty
            let path: String = "/user_failure"
        }
        let expectation = XCTestExpectation()
        apiClient.send(UserRequest(), completion: { result in
            do {
                let _ = try result.get()
                XCTFail()
            } catch {
                let _ = error
            }
            expectation.fulfill()
        })
        XCTWaiter().wait(for: [expectation], timeout: 3.0)
    }
    
    func testRequestUser_failure() throws {
        let apiClient = APIClientTests.makeSimpleAPIClient()

        struct UserRequest: APIRequest {
            typealias Response = User
            let path: String = "/user_failure"
        }
        let expectation = XCTestExpectation()
        apiClient.send(UserRequest(), completion: { result in
            do {
                let _ = try result.get()
                XCTFail()
            } catch {
                let _ = error
            }
            expectation.fulfill()
        })
        XCTWaiter().wait(for: [expectation], timeout: 3.0)
    }
    
    func testPullingTask() throws {
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
        
        do {
            let expectation = XCTestExpectation()
            let _ = APIPollingTask(api: apiClient, initialRequest: StartTaskRequest(), coordinator: APIPollingTaskBlockCoordinator<StartTaskRequest, CheckTaskRequest, Void>(checkRequestMaker: { task in
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
            }), completion: { result in
                do {
                    let _ = try result.get()
                } catch {
                    XCTFail()
                }
                expectation.fulfill()
            })
            XCTWaiter().wait(for: [expectation], timeout: 3.0)
        }
        
        do {
            let expectation = XCTestExpectation()
            let request = APIPollingTask(api: apiClient, initialRequest: StartTaskRequest(), coordinator: APIPollingTaskBlockCoordinator<StartTaskRequest, CheckTaskRequest, Void>(checkRequestMaker: { task in
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
            }), completion: { result in
                do {
                    let _ = try result.get()
                    XCTFail()
                } catch {
                    XCTAssert((error as? URLError)?.code == .cancelled)
                }
                expectation.fulfill()
            })
            request.cancel()
            XCTWaiter().wait(for: [expectation], timeout: 3.0)
        }
    }
    
    func testUpload() throws {
        var uploadMock = Mock(url: URL(string: "https://www.example.com/upload")!, dataType: .json, statusCode: 200, data: [
            .post: try! JSONEncoder().encode(Empty.value)
        ])
        uploadMock.onRequest = { request, parameters in
            guard let lengthString = request.headers.value(for: "Content-Length"), let length = Int(lengthString) else {
                XCTFail()
                return
            }
            XCTAssert(length == 2470)
        }
        uploadMock.register()
        
        let fileData = Data(count: 2341)
        
        let apiClient = APIClientTests.makeSimpleAPIClient()
        struct UploadRequest: APIRequest {
            typealias Response = Empty
            let path: String = "/upload"
            let parameters: APIRequestParameters
            init(data: Data) {
                parameters = .multipart([.data(value: data, name: "file")])
            }
        }
        let expectation = XCTestExpectation()
        apiClient.send(UploadRequest(data: fileData), completion: { result in
            do {
                let _ = try result.get()
            } catch {
                XCTFail()
            }
            expectation.fulfill()
        })
        XCTWaiter().wait(for: [expectation], timeout: 3.0)
    }
    
    func testUpload_partialFile() throws {
        var uploadMock = Mock(url: URL(string: "https://www.example.com/upload_partial")!, dataType: .json, statusCode: 200, data: [
            .post: try! JSONEncoder().encode(Empty.value)
        ])
        uploadMock.onRequest = { request, parameters in
            let bodyText = request.httpBodyStream?.readString() ?? ""
            XCTAssert(bodyText.contains("quick"))
            XCTAssert(!bodyText.contains("A"))
            XCTAssert(!bodyText.contains("brown"))
        }
        uploadMock.register()
                
        let apiClient = APIClientTests.makeSimpleAPIClient()
        struct UploadRequest: APIRequest {
            typealias Response = Empty
            let path: String = "/upload_partial"
            let parameters: APIRequestParameters = .multipart([.partialFile(url: Bundle.module.url(forResource: "sample", withExtension: "txt", subdirectory: "Fixture")!, offset: 2, length: 5, name: "file")])
        }
        let expectation = XCTestExpectation()
        apiClient.send(UploadRequest(), completion: { result in
            do {
                let _ = try result.get()
            } catch {
                XCTFail()
            }
            expectation.fulfill()
        })
        XCTWaiter().wait(for: [expectation], timeout: 3.0)
    }
    
    func testUpload_partialFile_error() throws {
        var uploadMock = Mock(url: URL(string: "https://www.example.com/upload_partial")!, dataType: .json, statusCode: 200, data: [
            .post: try! JSONEncoder().encode(Empty.value)
        ])
        uploadMock.onRequest = { request, parameters in
            let bodyText = request.httpBodyStream?.readString() ?? ""
            XCTAssert(bodyText.contains("quick"))
            XCTAssert(!bodyText.contains("A"))
            XCTAssert(!bodyText.contains("brown"))
        }
        uploadMock.register()
        
        let apiClient = APIClientTests.makeSimpleAPIClient()
        struct UploadRequest: APIRequest {
            typealias Response = Empty
            let path: String = "/upload_partial"
            let parameters: APIRequestParameters = .multipart([.partialFile(url: URL(fileURLWithPath: "/non_existing_ab39b2db-c8e5-4932-a6c1-41973b63f0ba.txt"), offset: 2, length: 5, name: "file")])
        }
        let expectation = XCTestExpectation()
        apiClient.send(UploadRequest(), completion: { result in
            do {
                let _ = try result.get()
            } catch {
                XCTAssert(error is Alamofire.AFError.UnexpectedInputStreamLength)
            }
            expectation.fulfill()
        })
        XCTWaiter().wait(for: [expectation], timeout: 3.0)
    }
    
    func testProtocolOverride() {
        do {
            struct Request: DemoAPIRequest {
                typealias Response = Empty
                let path: String = "/"
            }
            let request = Request()
            XCTAssert(request.timeoutInterval == 30)
            XCTAssert(request.method == .get)
        }
        do {
            struct Request: APIRequest {
                typealias Response = Empty
                let path: String = "/"
            }
            let request = Request()
            XCTAssert(request.timeoutInterval == nil)
            XCTAssert(request.method == nil)
        }
    }
}

protocol DemoAPIRequest: APIRequest {
    
}

extension DemoAPIRequest {
    var method: HTTPMethod? { .get }
    var timeoutInterval: TimeInterval? { 30 }
}
