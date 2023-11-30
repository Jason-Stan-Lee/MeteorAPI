import Foundation
import XCTest
@testable import MeteorAPI
import Alamofire

fileprivate struct Request: APIRequest {
    struct Response: Decodable, Hashable {
        
    }
    
    var baseURL: URL?  = URL(string: "https://example.com")!
    
    var path: String = "/test"
    
    var method: HTTPMethod = .post
    
    var headers: HTTPHeaders = HTTPHeaders([.authorization("token")])
    
    var parameters: APIRequestParameters = .urlEncoded(["key": "value"])
    
    var queryItems: [URLQueryItem] = [URLQueryItem(name: "key", value: "value")]
    
    var timeoutInterval: TimeInterval = 5
    
    var mock: Result<Response,Error>? = .success(Response())
}

final class RequestTests: XCTestCase {
    
    func testTypeEraser() throws {
        let request = Request()
        let typeErasedRequest = AnyAPIRequest<Request.Response>(request)
        XCTAssert(request.baseURL == typeErasedRequest.baseURL)
        XCTAssert(request.path == typeErasedRequest.path)
        XCTAssert(request.method == typeErasedRequest.method)
        XCTAssert(request.headers.dictionary == typeErasedRequest.headers.dictionary)
        XCTAssert(request.parameters == typeErasedRequest.parameters)
        XCTAssert(request.queryItems == typeErasedRequest.queryItems)
        XCTAssert(request.timeoutInterval == typeErasedRequest.timeoutInterval)
        XCTAssert(typeErasedRequest.mock != nil)
    }
    
    func testParameters_urlEncoded() throws {
        do {
            let parameters = APIRequestParameters.urlEncoded(["name": nil])
            switch parameters {
            case .urlEncoded(let value):
                XCTAssert(value == ["name": nil])
            default:
                XCTFail()
            }
        }
        do {
            let parameters = APIRequestParameters.urlEncoded(["name": "value"])
            switch parameters {
            case .urlEncoded(let value):
                XCTAssert(value == ["name": "value"])
            default:
                XCTFail()
            }
        }
    }
    
    func testRequestDefaults_protocolDefaults() throws {
        struct Request: APIRequest {
            struct Response: Decodable {}
            let path: String = "/"
        }
        let request = Request()
        XCTAssert(request.baseURL == nil)
        XCTAssert(request.path == "/")
        XCTAssert(request.method == nil)
        XCTAssert(request.parameters == .urlEncoded([:]))
        XCTAssert(request.queryItems == [])
        XCTAssert(request.timeoutInterval == nil)
        XCTAssert(request.headers.dictionary == [:])
        XCTAssert(request.mock == nil)
    }
    
    func testRequestDefaults_resolveDefaults_get() throws {
        struct Request: APIRequest {
            struct Response: Decodable {}
            let path: String = "/"
            let headers: HTTPHeaders = HTTPHeaders(["Cookie": "cookie=value"])
            let queryItems: [URLQueryItem] = [URLQueryItem(name: "id", value: "123")]
        }
        let requestDefaults = APIRequestDefaults(baseURL: URL(string: "https://example.com")!, method: .get, timeoutInterval: 15, headers: HTTPHeaders(["Authorization": "Basic YWxhZGRpbjpvcGVuc2VzYW1l"]), queryItems: [URLQueryItem(name: "name", value: "YuAo")], parameters: [:])
        
        let request = Request()
        let resolvedRequest = request.resolve(with: requestDefaults)
        XCTAssert(resolvedRequest.url == URL(string: "https://example.com/?name=YuAo&id=123"))
        XCTAssert(resolvedRequest.method == .get)
        XCTAssert(resolvedRequest.parameters == .urlEncoded([:]))
        XCTAssert(resolvedRequest.timeoutInterval == 15)
        XCTAssert(resolvedRequest.headers.dictionary == [
            "Authorization": "Basic YWxhZGRpbjpvcGVuc2VzYW1l",
            "Cookie": "cookie=value"
        ])
    }
    
    func testRequestDefaults_resolveDefaults_post() throws {
        struct Request: APIRequest {
            struct Response: Decodable {}
            let path: String = "/"
            let parameters: APIRequestParameters = .urlEncoded(["id": 123])
        }
        let requestDefaults = APIRequestDefaults(baseURL: URL(string: "https://example.com")!, method: .post, parameters: ["name": "YuAo"])
        
        let request = Request()
        let resolvedRequest = request.resolve(with: requestDefaults)
        XCTAssert(resolvedRequest.url == URL(string: "https://example.com/"))
        XCTAssert(resolvedRequest.method == .post)
        XCTAssert(resolvedRequest.parameters == .urlEncoded([
            "id": 123,
            "name": "YuAo"
        ]))
    }
    
    
    func testRequestDefaults_resolveDefaults_multipart() throws {
        struct Request: APIRequest {
            struct Response: Decodable {}
            let path: String = "/"
            let parameters: APIRequestParameters = .multipart([.data(value: Data(), name: "id")])
        }
        let requestDefaults = APIRequestDefaults(baseURL: URL(string: "https://example.com")!, method: .post, parameters: ["name": "YuAo"])
        
        let request = Request()
        let resolvedRequest = request.resolve(with: requestDefaults)
        XCTAssert(resolvedRequest.url == URL(string: "https://example.com/"))
        XCTAssert(resolvedRequest.method == .post)
        switch resolvedRequest.parameters {
        case .multipart(let items):
            XCTAssert(items == [.data(value: "YuAo".data(using: .utf8)!, name: "name"), .data(value: Data(), name: "id")])
        default:
            XCTFail()
        }
    }
    
    func testParameters_multipart() throws {
        do {
            let parameters = APIRequestParameters.multipart([])
            switch parameters {
            case .multipart(let items):
                XCTAssert(items == [])
            default:
                XCTFail()
            }
        }
        do {
            let parameters = APIRequestParameters.multipart([.data(value: "value".data(using: .utf8)!, name: "key")])
            switch parameters {
            case .multipart(let items):
                XCTAssert(items.first?.name == "key")
                XCTAssert(items.first == .data(value: "value".data(using: .utf8)!, name: "key"))
            default:
                XCTFail()
            }
        }
        do {
            let parameters = APIRequestParameters.multipart([.fileData(data: Data(), name: "key", fileName: "image.jpg", mimeType: "image/jpeg")])
            switch parameters {
            case .multipart(let items):
                XCTAssert(items.first?.name == "key")
            default:
                XCTFail()
            }
        }
        do {
            let parameters = APIRequestParameters.multipart([.string(value: "value", name: "key")])
            switch parameters {
            case .multipart(let items):
                XCTAssert(items.first?.name == "key")
                XCTAssert(items.first == .data(value: "value".data(using: .utf8)!, name: "key"))
            default:
                XCTFail()
            }
        }
        do {
            let parameters = APIRequestParameters.multipart([.fileURL(url: URL(fileURLWithPath: "/image.jpg"), name: "key")])
            switch parameters {
            case .multipart(let items):
                XCTAssert(items.first?.name == "key")
                XCTAssert(items.first == .fileURL(url: URL(fileURLWithPath: "/image.jpg"), name: "key", fileName: "image.jpg", mimeType: "image/jpeg"))
            default:
                XCTFail()
            }
        }
        do {
            let parameters = APIRequestParameters.multipart([.partialFile(url: URL(fileURLWithPath: "/image.jpg"), offset: 1, length: 123, name: "key")])
            switch parameters {
            case .multipart(let items):
                XCTAssert(items.first?.name == "key")
                XCTAssert(items.first == .partialFile(url: URL(fileURLWithPath: "/image.jpg"), offset: 1, length: 123, name: "key", fileName: "image.jpg", mimeType: "image/jpeg"))
            default:
                XCTFail()
            }
        }
        do {
            let parameters = APIRequestParameters.multipart([.partialFile(url: URL(fileURLWithPath: "/image"), offset: 1, length: 123, name: "key")])
            switch parameters {
            case .multipart(let items):
                XCTAssert(items.first?.name == "key")
                XCTAssert(items.first == .partialFile(url: URL(fileURLWithPath: "/image"), offset: 1, length: 123, name: "key", fileName: "image", mimeType: "application/octet-stream"))
            default:
                XCTFail()
            }
        }
    }
}
