import Foundation
import Alamofire

public typealias Empty = Alamofire.Empty
public typealias HTTPMethod = Alamofire.HTTPMethod
public typealias HTTPHeaders = Alamofire.HTTPHeaders

// Sendable:
// Alamofire.Request.cancel is Thread-safe.
// Progress (NSProgress) is Thread-safe.
struct AlamofireNetworkRequest: NetworkRequest, @unchecked Sendable {
    private let request: Alamofire.Request
    
    let downloadProgress: Progress
    let uploadProgress: Progress
    
    init(_ request: Alamofire.Request) {
        self.request = request
        self.downloadProgress = request.downloadProgress
        self.uploadProgress = request.uploadProgress
    }
    
    func cancel() {
        self.request.cancel()
    }
}
