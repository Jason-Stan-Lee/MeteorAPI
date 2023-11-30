import Foundation

public struct NetworkTaskMetrics: Codable {
    
    public enum ResourceFetchType: String, Codable {
        case unknown
        case networkLoad
        case serverPush
        case localCache
    }
    
    public enum DomainResolutionProtocol: String, Codable {
        case unknown
        case udp
        case tcp
        case tls
        case https
    }
    
    public struct TransactionMetrics: Codable {
        
        public struct Response: Codable {
            public var statusCode: Int
            public var mimeType: String?
            public var expectedContentLength: Int64
        }
        
        public struct Request: Codable {
            public var url: URL?
            public var bodyByteCount: Int?
        }
        
        public var request: Request
        
        public var response: Response?
        
        public var fetchStartDate: Date?
        
        public var domainLookupStartDate: Date?
        
        public var domainLookupEndDate: Date?
        
        public var connectStartDate: Date?
        
        public var secureConnectionStartDate: Date?
        
        public var secureConnectionEndDate: Date?
        
        public var connectEndDate: Date?
        
        public var requestStartDate: Date?
        
        public var requestEndDate: Date?
        
        public var responseStartDate: Date?
        
        public var responseEndDate: Date?
        
        public var networkProtocolName: String?
        
        public var isProxyConnection: Bool
        
        public var isReusedConnection: Bool
        
        public var resourceFetchType: ResourceFetchType
        
        public var countOfRequestHeaderBytesSent: Int64
        
        public var countOfRequestBodyBytesSent: Int64
        
        public var countOfRequestBodyBytesBeforeEncoding: Int64
        
        public var countOfResponseHeaderBytesReceived: Int64
        
        public var countOfResponseBodyBytesReceived: Int64
        
        public var countOfResponseBodyBytesAfterDecoding: Int64
        
        public var localAddress: String?
        
        public var localPort: Int?
        
        public var remoteAddress: String?
        
        public var remotePort: Int?
        
        public var isCellular: Bool
        
        public var isExpensive: Bool
        
        public var isConstrained: Bool
        
        public var isMultipath: Bool
        
        public var domainResolutionProtocol: DomainResolutionProtocol?
        
        public init(transactionMetrics: URLSessionTaskTransactionMetrics) {
            request = Request(url: transactionMetrics.request.url, bodyByteCount: transactionMetrics.request.httpBody?.count)
            response = (transactionMetrics.response as? HTTPURLResponse).map({ Response(statusCode: $0.statusCode, mimeType: $0.mimeType, expectedContentLength: $0.expectedContentLength) })
            fetchStartDate = transactionMetrics.fetchStartDate
            domainLookupStartDate = transactionMetrics.domainLookupStartDate
            domainLookupEndDate = transactionMetrics.domainLookupEndDate
            connectStartDate = transactionMetrics.connectStartDate
            connectEndDate = transactionMetrics.connectEndDate
            secureConnectionStartDate = transactionMetrics.secureConnectionStartDate
            secureConnectionEndDate = transactionMetrics.secureConnectionEndDate
            requestStartDate = transactionMetrics.requestStartDate
            requestEndDate = transactionMetrics.requestEndDate
            responseStartDate = transactionMetrics.responseStartDate
            responseEndDate = transactionMetrics.responseEndDate
            networkProtocolName = transactionMetrics.networkProtocolName
            isProxyConnection = transactionMetrics.isProxyConnection
            isReusedConnection = transactionMetrics.isReusedConnection
            resourceFetchType = {
                switch transactionMetrics.resourceFetchType {
                case .unknown:
                    return .unknown
                case .localCache:
                    return .localCache
                case .networkLoad:
                    return .networkLoad
                case .serverPush:
                    return .serverPush
                @unknown default:
                    return .unknown
                }
            }()
            countOfRequestHeaderBytesSent = transactionMetrics.countOfRequestHeaderBytesSent
            countOfRequestBodyBytesSent = transactionMetrics.countOfRequestBodyBytesSent
            countOfRequestBodyBytesBeforeEncoding = transactionMetrics.countOfRequestBodyBytesBeforeEncoding
            countOfResponseHeaderBytesReceived = transactionMetrics.countOfResponseHeaderBytesReceived
            countOfResponseBodyBytesReceived = transactionMetrics.countOfResponseBodyBytesReceived
            countOfResponseBodyBytesAfterDecoding = transactionMetrics.countOfResponseBodyBytesAfterDecoding
            localAddress = transactionMetrics.localAddress
            localPort = transactionMetrics.localPort
            remoteAddress = transactionMetrics.remoteAddress
            remotePort = transactionMetrics.remotePort
            isCellular = transactionMetrics.isCellular
            isExpensive = transactionMetrics.isExpensive
            isConstrained = transactionMetrics.isConstrained
            isMultipath = transactionMetrics.isMultipath
            domainResolutionProtocol = {
                if #available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 5.0, *) {
                    if transactionMetrics.responds(to: #selector(getter: URLSessionTaskTransactionMetrics.domainResolutionProtocol)) {
                        switch transactionMetrics.domainResolutionProtocol {
                        case .https:
                            return .https
                        case .tcp:
                            return .tcp
                        case .tls:
                            return .tls
                        case .udp:
                            return .udp
                        case .unknown:
                            return .unknown
                        @unknown default:
                            return .unknown
                        }
                    } else {
                        return nil
                    }
                } else {
                    return nil
                }
            }()
        }
    }
    
    public var transactionMetrics: [TransactionMetrics]
    
    public var taskInterval: DateInterval
    
    public var redirectCount: Int
    
    public var uploadProgress: TransmissionProgress?
    
    public var downloadProgress: TransmissionProgress?
    
    public struct TransmissionProgress: Codable {
        public var totalUnitCount: Int64
        public var completedUnitCount: Int64
    }
    
    public struct TaskError: Codable {
        public var domain: String
        public var code: Int
        public var errorDescription: String
    }
    
    public var error: TaskError?
    
    public init(metrics: URLSessionTaskMetrics, uploadProgress: Progress?, downloadProgress: Progress?, error: Error?) {
        transactionMetrics = metrics.transactionMetrics.map(TransactionMetrics.init(transactionMetrics:))
        taskInterval = metrics.taskInterval
        redirectCount = metrics.redirectCount
        if let uploadProgress = uploadProgress, uploadProgress.totalUnitCount > 0 {
            self.uploadProgress = TransmissionProgress(totalUnitCount: uploadProgress.totalUnitCount, completedUnitCount: uploadProgress.completedUnitCount)
        }
        if let downloadProgress = downloadProgress, downloadProgress.totalUnitCount > 0 {
            self.downloadProgress = TransmissionProgress(totalUnitCount: downloadProgress.totalUnitCount, completedUnitCount: downloadProgress.completedUnitCount)
        }
        if let error = error {
            let nsError = error as NSError
            self.error = TaskError(domain: nsError.domain, code: nsError.code, errorDescription: nsError.localizedDescription)
        }
    }
}
