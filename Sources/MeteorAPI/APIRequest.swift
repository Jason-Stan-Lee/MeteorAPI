import Foundation

public enum APIRequestParameters: Hashable {
    
    public static func == (lhs: APIRequestParameters, rhs: APIRequestParameters) -> Bool {
        switch (lhs, rhs) {
        case (.urlEncoded(let a), .urlEncoded(let b)):
            return a == b
        case (.multipart(let a), .multipart(let b)):
            return a == b
        case (.jsonEncoded(let a), .jsonEncoded(let b)):
            return AnyHashable(a) == AnyHashable(b)
        default:
            return false
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .jsonEncoded(let v):
            hasher.combine(v)
        case .multipart(let v):
            hasher.combine(v)
        case .urlEncoded(let v):
            hasher.combine(v)
        }
    }
    
    public enum MultipartFormItem: Hashable {
        case fileURL(url: URL, name: String, fileName: String, mimeType: String)
        case fileData(data: Data, name: String, fileName: String, mimeType: String)
        case partialFile(url: URL, offset: Int, length: Int, name: String, fileName: String, mimeType: String)
        case data(value: Data, name: String)
        
        var name: String {
            switch self {
            case .data(_, let name):
                return name
            case .fileData(_, let name, _, _):
                return name
            case .fileURL(_, let name, _, _):
                return name
            case .partialFile(_, _, _, let name, _, _):
                return name
            }
        }
        
        public static func fileURL(url: URL, name: String) -> MultipartFormItem {
            let uniformTypeIdentifier = UniformTypeIdentifier(pathExtension: url.pathExtension)
            return .fileURL(url: url, name: name, fileName: url.lastPathComponent, mimeType: uniformTypeIdentifier.mimeType)
        }
        
        public static func partialFile(url: URL, offset: Int, length: Int, name: String) -> MultipartFormItem {
            let uniformTypeIdentifier = UniformTypeIdentifier(pathExtension: url.pathExtension)
            return .partialFile(url: url, offset: offset, length: length, name: name, fileName: url.lastPathComponent, mimeType: uniformTypeIdentifier.mimeType)
        }
        
        public static func string(value: String, name: String) -> MultipartFormItem {
            return .data(value: value.data(using: .utf8)!, name: name)
        }
    }
    
    case urlEncoded([String: AnyHashable?])
    case multipart([MultipartFormItem])
    case jsonEncoded(any (Encodable & Hashable))
    
    public static func jsonEncoded(dictionary: [String: any (Encodable & Hashable)]) -> APIRequestParameters {
        let container = JSONEncodingContainer(dictionary)
        return APIRequestParameters.jsonEncoded(container)
    }
    
    private struct JSONEncodingContainer: Encodable, Hashable {
        static func == (lhs: JSONEncodingContainer, rhs: JSONEncodingContainer) -> Bool {
            let l = lhs.contents.mapValues({ v in AnyHashable(v) })
            let r = rhs.contents.mapValues({ v in AnyHashable(v) })
            return l == r
        }
        
        func hash(into hasher: inout Hasher) {
            for (key, value) in contents {
                hasher.combine(key)
                hasher.combine(value)
            }
        }
        
        private let contents: [String: any (Encodable & Hashable)]
        
        init(_ contents: [String: any (Encodable & Hashable)]) {
            self.contents = contents
        }
        
        struct CodingKey: Swift.CodingKey {
            let stringValue: String
            init?(stringValue: String) {
                fatalError()
            }
            let intValue: Int? = nil
            init?(intValue: Int) {
                fatalError()
            }
            init(_ string: String) {
                self.stringValue = string
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var keyedContainer = encoder.container(keyedBy: CodingKey.self)
            for (key, value) in contents {
                try keyedContainer.encode(value, forKey: CodingKey(key))
            }
        }
    }
}

public protocol APIRequest {
    associatedtype Response: Decodable
    
    /// Base URL of the request. If the baseURL is nil. APIClient is responsible for providing a proper value.
    var baseURL: URL? { get }
    
    /// Path of the request.
    var path: String { get }
    
    var queryItems: [URLQueryItem] { get }
    
    /// HTTP method of the request
    var method: HTTPMethod? { get }
    
    var headers: HTTPHeaders { get }
    
    var parameters: APIRequestParameters { get }
    
    var timeoutInterval: TimeInterval? { get }
    
    var mock: Result<Response,Error>? { get }
}

public extension APIRequest {
    
    var baseURL: URL? { nil }
    
    var queryItems: [URLQueryItem] { [] }
    
    var parameters: APIRequestParameters { .urlEncoded([:]) }
    
    var headers: HTTPHeaders { HTTPHeaders() }
    
    var method: HTTPMethod? { nil }

    var timeoutInterval: TimeInterval? { nil }
 
    var mock: Result<Response,Error>? { nil }
}

public struct AnyAPIRequest<Response: Decodable>: APIRequest {
    public let baseURL: URL?
    public let path: String
    public let method: HTTPMethod?
    public let headers: HTTPHeaders
    public let parameters: APIRequestParameters
    public let queryItems: [URLQueryItem]
    public let timeoutInterval: TimeInterval?
    public let mock: Result<Response,Error>?
    
    public init<Request: APIRequest>(_ request: Request) where Request.Response == Response {
        self.baseURL = request.baseURL
        self.headers = request.headers
        self.path = request.path
        self.method = request.method
        self.parameters = request.parameters
        self.timeoutInterval = request.timeoutInterval
        self.queryItems = request.queryItems
        self.mock = request.mock
    }
}
