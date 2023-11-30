import Foundation
import Alamofire

public enum APIRequestEncodingError: Swift.Error, LocalizedError {
    case cannotBuildPartialFileInputStream
    
    public var errorDescription: String? {
        switch self {
        case .cannotBuildPartialFileInputStream:
            return "Cannot build partial file input stream."
        }
    }
}

public protocol APIEventHandler: AnyObject {
    func willSendRequest<Request: APIRequest>(client: APIClient, request: Request)
    func requestFailed(client: APIClient, url: URL, response: HTTPURLResponse?, responseData: Data?, error: Error, taskMetrics: NetworkTaskMetrics?)
    func didCollectTaskMetrics(client: APIClient, taskMetrics: NetworkTaskMetrics)
}

public protocol ResponseDecoder {
    func decode<T>(_ type: T.Type, from data: Data) throws -> T where T : Decodable
}

public struct JSONResponseDecoder: ResponseDecoder {
    public init() {
        
    }
    public func decode<T>(_ type: T.Type, from data: Data) throws -> T where T : Decodable {
        try JSONDecoder().decode(type, from: data)
    }
}

public class SimpleAPIClient: APIClient {
    
    public enum RequestDefaults {
        case value(APIRequestDefaults)
        case provider(() -> APIRequestDefaults)
        
        func get() -> APIRequestDefaults {
            switch self {
            case .value(let v):
                return v
            case .provider(let provider):
                return provider()
            }
        }
    }
    
    private let session: Session
    
    private let requestDefaults: RequestDefaults
    
    private let responseDecoder: ResponseDecoder
    
    private var eventHandlers = NSHashTable<AnyObject>.weakObjects()
    
    private let requestModifier: Session.RequestModifier?
    
    public init(session: Session? = nil, requestDefaults: APIRequestDefaults, responseDecoder: ResponseDecoder = JSONResponseDecoder()) {
        self.session = session ?? Session()
        self.requestDefaults = .value(requestDefaults)
        self.responseDecoder = responseDecoder
        self.requestModifier = nil
    }
    
    public init(session: Session? = nil, requestDefaultsProvider: @escaping () -> APIRequestDefaults, responseDecoder: ResponseDecoder = JSONResponseDecoder()) {
        self.session = session ?? Session()
        self.requestDefaults = .provider(requestDefaultsProvider)
        self.responseDecoder = responseDecoder
        self.requestModifier = nil
    }
    
    public init(session: Session? = nil, requestDefaults: RequestDefaults, requestModifier: Session.RequestModifier? = nil, responseDecoder: ResponseDecoder = JSONResponseDecoder()) {
        self.session = session ?? Session()
        self.requestDefaults = requestDefaults
        self.responseDecoder = responseDecoder
        self.requestModifier = requestModifier
    }
    
    public func addEventHandler(_ eventHandler: APIEventHandler) {
        dispatchPrecondition(condition: .onQueue(.main))
        eventHandlers.add(eventHandler)
    }
    
    public func removeEventHandler(_ eventHandler: APIEventHandler) {
        dispatchPrecondition(condition: .onQueue(.main))
        eventHandlers.remove(eventHandler)
    }
    
    private final class DecodableResponseSerializer<T: Decodable>: ResponseSerializer {
        let decoder: ResponseDecoder
        let dataPreprocessor: DataPreprocessor
        let emptyResponseCodes: Set<Int>
        let emptyRequestMethods: Set<HTTPMethod>
        
        public init(decoder: ResponseDecoder,
                    dataPreprocessor: DataPreprocessor = DecodableResponseSerializer.defaultDataPreprocessor,
                    emptyResponseCodes: Set<Int> = DecodableResponseSerializer.defaultEmptyResponseCodes,
                    emptyRequestMethods: Set<HTTPMethod> = DecodableResponseSerializer.defaultEmptyRequestMethods) {
            self.dataPreprocessor = dataPreprocessor
            self.decoder = decoder
            self.emptyResponseCodes = emptyResponseCodes
            self.emptyRequestMethods = emptyRequestMethods
        }
        
        func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> T {
            guard error == nil else { throw error! }
            
            guard var data = data, !data.isEmpty else {
                guard emptyResponseAllowed(forRequest: request, response: response) else {
                    throw AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)
                }
                
                guard let emptyResponseType = T.self as? Alamofire.EmptyResponse.Type, let emptyValue = emptyResponseType.emptyValue() as? T else {
                    throw AFError.responseSerializationFailed(reason: .invalidEmptyResponse(type: "\(T.self)"))
                }
                
                return emptyValue
            }
            
            data = try dataPreprocessor.preprocess(data)
            
            return try decoder.decode(T.self, from: data)
        }
    }
    
    @discardableResult
    public func send<Request: APIRequest>(_ request: Request, completion: @escaping (Result<Request.Response, Error>) -> Void) -> NetworkRequest {
        dispatchPrecondition(condition: .onQueue(.main))
        
        for case let handler as APIEventHandler in eventHandlers.allObjects {
            handler.willSendRequest(client: self, request: request)
        }
        
        if let mock = request.mock {
            return MockedNetworkRequest(result: mock, completion: completion)
        }
        
        let resolvedRequest = request.resolve(with: requestDefaults.get())
        
        let requestInterceptor: RequestInterceptor? = nil
        let afRequest: Alamofire.DataRequest
        
        let globalRequestModifier = self.requestModifier
        
        switch resolvedRequest.parameters {
        case .multipart(let items):
            var multipartFormDataBuildError: Error?
            let multipartFormData = MultipartFormData()
            for item in items {
                switch item {
                case .data(let value, let name):
                    multipartFormData.append(value, withName: name)
                case .fileData(let data, let name, let fileName, let mimeType):
                    multipartFormData.append(data, withName: name, fileName: fileName, mimeType: mimeType)
                case .fileURL(let url, let name, let fileName, let mimeType):
                    multipartFormData.append(url, withName: name, fileName: fileName, mimeType: mimeType)
                case .partialFile(let url, let offset, let length, let name, let fileName, let mimeType):
                    if let inputStream = PartialFileInputStream.forReadingFile(at: url, offset: offset, length: length) {
                        multipartFormData.append(inputStream, withLength: UInt64(length), name: name, fileName: fileName, mimeType: mimeType)
                    } else {
                        // This is unlikely to happen. https://github.com/apple/swift-corelibs-foundation/blob/6cd941a7526185bbbfcbc5dfa86e699bc317626f/Sources/Foundation/Stream.swift#L142
                        multipartFormDataBuildError = APIRequestEncodingError.cannotBuildPartialFileInputStream
                    }
                }
            }
            let requestModifier: Session.RequestModifier = { urlRequest in
                // No sync error reporter, so throw `multipartFormDataBuildError` here.
                if let multipartFormDataBuildError = multipartFormDataBuildError {
                    throw multipartFormDataBuildError
                }
                urlRequest.timeoutInterval = resolvedRequest.timeoutInterval
                urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
                try globalRequestModifier?(&urlRequest)
            }
            afRequest = session.upload(multipartFormData: multipartFormData, to: resolvedRequest.url, usingThreshold: MultipartFormData.encodingMemoryThreshold, method: resolvedRequest.method, headers: resolvedRequest.headers, interceptor: requestInterceptor, fileManager: .default, requestModifier: requestModifier)
        case .urlEncoded(let parameters):
            let requestModifier: Session.RequestModifier = { urlRequest in
                urlRequest.timeoutInterval = resolvedRequest.timeoutInterval
                urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
                try globalRequestModifier?(&urlRequest)
            }
            afRequest = session.request(resolvedRequest.url, method: resolvedRequest.method, parameters: parameters.compactMapValues({ $0 }), encoding: URLEncoding.default, headers: resolvedRequest.headers, interceptor: requestInterceptor, requestModifier: requestModifier)
        case .jsonEncoded(let data):
            let requestModifier: Session.RequestModifier = { urlRequest in
                urlRequest.timeoutInterval = resolvedRequest.timeoutInterval
                urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
                try globalRequestModifier?(&urlRequest)
            }
            afRequest = session.request(resolvedRequest.url, method: resolvedRequest.method, parameters: data, headers: resolvedRequest.headers, interceptor: requestInterceptor, requestModifier: requestModifier)
        }
        
        let upProgress = afRequest.uploadProgress
        let downProgress = afRequest.downloadProgress
        
        afRequest.response(responseSerializer: DecodableResponseSerializer<Request.Response>(decoder: self.responseDecoder)) { response in
            switch response.result {
            case .failure(let error):
                //Unwrap AFError
                let error = error.asAFError?.underlyingError ?? error
                
                let taskMetrics: NetworkTaskMetrics?
                if let metrics = response.metrics {
                    taskMetrics = NetworkTaskMetrics(metrics: metrics, uploadProgress: upProgress, downloadProgress: downProgress, error: error)
                } else {
                    taskMetrics = nil
                }
                
                for case let handler as APIEventHandler in self.eventHandlers.allObjects {
                    handler.requestFailed(client: self, url: resolvedRequest.url, response: response.response, responseData: response.data, error: error, taskMetrics: taskMetrics)
                }
                
                if let taskMetrics = taskMetrics {
                    for case let handler as APIEventHandler in self.eventHandlers.allObjects {
                        handler.didCollectTaskMetrics(client: self, taskMetrics: taskMetrics)
                    }
                }
                
                completion(.failure(error))
            case .success(let value):
                if let metrics = response.metrics {
                    for case let handler as APIEventHandler in self.eventHandlers.allObjects {
                        handler.didCollectTaskMetrics(client: self, taskMetrics: NetworkTaskMetrics(metrics: metrics, uploadProgress: upProgress, downloadProgress: downProgress, error: nil))
                    }
                }
                completion(.success(value))
            }
        }
        return AlamofireNetworkRequest(afRequest)
    }
    
    public func cancelAllRequests() {
        dispatchPrecondition(condition: .onQueue(.main))
        session.cancelAllRequests()
    }
}

extension Session {
    func request(_ convertible: URLConvertible,
                 method: HTTPMethod,
                 parameters: some Encodable,
                 headers: HTTPHeaders? = nil,
                 interceptor: RequestInterceptor? = nil,
                 requestModifier: RequestModifier? = nil) -> DataRequest {
        request(convertible, method: method, parameters: parameters, encoder: .json, headers: headers, interceptor: interceptor, requestModifier: requestModifier)
    }
}
