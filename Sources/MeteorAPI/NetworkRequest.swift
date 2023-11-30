import Foundation

public protocol NetworkRequest: Sendable {
    func cancel()
    var uploadProgress: Progress { get }
    var downloadProgress: Progress { get }
}

// Sendable:
// Progress (NSProgress) is Thread-safe.
// All operation happens on main thread.
final class MockedNetworkRequest<Response>: NetworkRequest, @unchecked Sendable {
    
    func cancel() {
        DispatchQueue.main.async {
            if !self.isFinished {
                self.isFinished = true
                self.completion?(.failure(URLError(.cancelled)))
                self.completion = nil
            }
        }
    }
    
    private let result: Result<Response, Error>
    
    private var isFinished: Bool = false
    
    private var completion: ((Result<Response, Error>) -> Void)?
    
    init(result: Result<Response, Error>, completion: @escaping (Result<Response,Error>) -> Void) {
        self.result = result
        self.completion = completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if !self.isFinished {
                self.isFinished = true
                self.completion?(result)
                self.completion = nil
            }
        }
    }
    
    let uploadProgress: Progress = Progress()
    let downloadProgress: Progress = Progress()
}
