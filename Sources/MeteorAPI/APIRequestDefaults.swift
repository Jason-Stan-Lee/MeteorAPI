import Foundation
import Alamofire

public struct APIRequestDefaults {
    public init(baseURL: URL, method: HTTPMethod, timeoutInterval: TimeInterval = 30, headers: HTTPHeaders = HTTPHeaders(), queryItems: [URLQueryItem] = [], parameters: [String : String] = [:]) {
        self.baseURL = baseURL
        self.method = method
        self.timeoutInterval = timeoutInterval
        self.headers = headers
        self.queryItems = queryItems
        self.parameters = parameters
    }
    
    public var baseURL: URL
    public var method: HTTPMethod
    public var timeoutInterval: TimeInterval = 30
    public var headers: HTTPHeaders = HTTPHeaders()
    public var queryItems: [URLQueryItem] = []
    public var parameters: [String: String] = [:]
}

public struct ResolvedAPIRequest<Response: Decodable> {
    var url: URL
    var method: HTTPMethod
    var headers: HTTPHeaders
    var parameters: APIRequestParameters
    var timeoutInterval: TimeInterval
}

public extension APIRequest {
    func resolve(with defaults: APIRequestDefaults) -> ResolvedAPIRequest<Response> {
        let baseURL: URL = self.baseURL ?? defaults.baseURL
        var url = baseURL.appendingPathComponent(self.path)
        do {
            var urlComponent = URLComponents(url: url, resolvingAgainstBaseURL: true)
            var queryItems = urlComponent?.queryItems ?? []
            queryItems.append(contentsOf: defaults.queryItems)
            queryItems.append(contentsOf: self.queryItems)
            urlComponent?.queryItems = queryItems
            if queryItems.count > 0, let urlWithQueryItems = urlComponent?.url {
                url = urlWithQueryItems
            }
        }
        
        let timeoutInterval = self.timeoutInterval ?? defaults.timeoutInterval
        let method: HTTPMethod = self.method ?? defaults.method
        
        var headers: HTTPHeaders = HTTPHeaders()
        for header in defaults.headers {
            headers.add(header)
        }
        for header in self.headers {
            headers.add(header)
        }
        
        let parameters: APIRequestParameters
        let defaultParameters: [String: String] = defaults.parameters
        
        switch self.parameters {
        case .multipart(let items):
            var resolvedItems: [APIRequestParameters.MultipartFormItem] = defaultParameters.map({ .data(value: $0.value.data(using: .utf8)!, name: $0.key) })
            for item in items {
                resolvedItems.removeAll(where: { $0.name == item.name })
                resolvedItems.append(item)
            }
            parameters = .multipart(resolvedItems)
        case .urlEncoded(let map):
            var resolvedMap: [String: AnyHashable?] = defaultParameters
            for (key, value) in map {
                resolvedMap[key] = value
            }
            parameters = .urlEncoded(resolvedMap)
        case .jsonEncoded(let data):
            func makeJSONParameters(content: some Encodable & Hashable, defaultParameters: [String: String]) -> some Encodable & Hashable {
                JSONParameters(content: content, defaultParameters: defaultParameters)
            }
            parameters = .jsonEncoded(makeJSONParameters(content: data, defaultParameters: defaultParameters))
        }
        
        return ResolvedAPIRequest<Response>(url: url, method: method, headers: headers, parameters: parameters, timeoutInterval: timeoutInterval)
    }
}

fileprivate struct JSONParameters<T>: Encodable, Hashable where T: Encodable & Hashable {
    var content: T
    var defaultParameters: [String: String]
    func encode(to encoder: Encoder) throws {
        try defaultParameters.encode(to: encoder)
        try content.encode(to: encoder)
    }
}
