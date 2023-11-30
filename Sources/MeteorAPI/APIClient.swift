import Foundation

public protocol APIClient {
    @discardableResult func send<Request: APIRequest>(_ request: Request, completion: @escaping (Result<Request.Response, Error>) -> Void) -> NetworkRequest
}
