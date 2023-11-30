import Foundation
import MeteorAPI

// Sendable:
// The result is not touched.
// All internal state is guarded by a lock.
private final class APIRequestPromise<T>: @unchecked Sendable {
    private var callbacks: [(Result<T, Error>) -> Void] = []
    private var result: Result<T, Error>?
    private let lock = UnfairLock()
    
    func addCallback(_ callback: @escaping (Result<T, Error>) -> Void) {
        lock.lock()
        defer {
            lock.unlock()
        }
        if let result = result {
            callback(result)
        } else {
            callbacks.append(callback)
        }
    }
    
    func complete(with result: Result<T, Error>) {
        lock.lock()
        defer {
            lock.unlock()
        }
        precondition(self.result == nil)
        self.result = result
        callbacks.forEach({ $0(result) })
        callbacks = []
    }
}

public struct AsyncAPIRequest<Response>: Sendable {
    private let networkRequest: NetworkRequest
    private let promise: APIRequestPromise<Response>
    
    public func cancel() {
        networkRequest.cancel()
    }
    
    public var uploadProgress: Progress { networkRequest.uploadProgress }
    
    public var downloadProgress: Progress { networkRequest.downloadProgress }
    
    public var response: Response {
        get async throws {
            let request = self.networkRequest
            return try await withTaskCancellationHandler(operation: {
                try Task.checkCancellation()
                return try await withCheckedThrowingContinuation({ continuation in
                    self.promise.addCallback(continuation.resume(with:))
                })
            }, onCancel: {
                request.cancel()
            })
        }
    }
    
    fileprivate init(networkRequest: NetworkRequest, promise: APIRequestPromise<Response>) {
        self.networkRequest = networkRequest
        self.promise = promise
    }
}

extension APIClient {
    @MainActor
    public func send<T: APIRequest>(_ request: T) -> AsyncAPIRequest<T.Response> {
        let promise = APIRequestPromise<T.Response>()
        let networkRequest = send(request, completion: { result in
            promise.complete(with: result)
        })
        return AsyncAPIRequest(networkRequest: networkRequest, promise: promise)
    }
}

extension APIClient {
    @MainActor
    public func perform<T: APIRequest>(_ request: T) async throws -> T.Response {
        try await send(request).response
    }
}

