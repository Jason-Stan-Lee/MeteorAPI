# MeteorAPI

API networking abstraction layer.

There are two primary components `APIRequest` and `APIClient` which are both protocols.

`APIRequest` represents an API endpoint. It supports multiple levels of customization. It is strongly typed and has the support for uploading partial files as well as mocking response.  

`AnyAPIRequest<Response>` is a type eraser for `APIRequest`.

`APIClient` is responsible for performing a request. You can use the returned `NetworkRequest` object to get the progress of a request or cancel a request. 

`APIClient` also has the support for async/await style concurrency: 

- MeteorAPIConcurrencySupport, using [Swift Concurrency](https://github.com/apple/swift-evolution/blob/3fb72ecd4951b951999130d07f337e2668b443a9/proposals/0296-async-await.md)

## Quick Start

### Build a request

Define an API endpoint by implementing the `APIRequest` protocol.

Most of the time, we only want to focus on `path`, `response`, and `parameters` of an API.

```swift
struct UserInfoRequest: APIRequest {
    typealias Response = User
    
    let path = "/v1/user"
    let parameters: APIRequestParameters
    
    init(id: String) {
        parameters = .urlEncoded(["id": id])
    }
}
```

### Send a request

After an `APIRequest` is created, you can send it using an `APIClient`.

```swift
let apiClient: APIClient = ...

apiClient.send(UserInfoRequest(id: "123"), completion: { result in
    switch result {
        case .success(let user):
            print(user)
        case .failure(let error):
            print(error)
    }
})
```

With [Swift Concurrency](https://github.com/apple/swift-evolution/blob/3fb72ecd4951b951999130d07f337e2668b443a9/proposals/0296-async-await.md)

```swift
import MeteorAPIConcurrencySupport

let user = try await apiClient.perform(UserInfoRequest(id: "123"))
```

## APIRequest

An `APIRequest` represents an API endpoint. 

```swift
/// APIRequest protocol declaration.
public protocol APIRequest {
    associatedtype Response: Decodable
    
    var baseURL: URL? { get }
    var path: String { get }
    var queryItems: [URLQueryItem] { get }
    var method: HTTPMethod? { get }
    var headers: HTTPHeaders { get }
    var parameters: APIRequestParameters { get }
    var timeoutInterval: TimeInterval? { get }
    var mock: Result<Response,Error>? { get }
}
```

`Response` and `path` is required for every request.

You can optionally provide `parameters`, `baseURL`, `method`, `headers`, `timeoutInterval` and `queryItems`. If no value is provided for `baseURL`, `method`, `timeoutInterval`, the `APIClient` object is responsible for providing proper values.

Examples:

```swift
struct CurrentUserInfoRequest: APIRequest {
    typealias Response = User
    let path = "/v1/user/my/base"
}

struct UploadFileRequest: APIRequest {
    struct Response: Decodable {
        let url: URL
    }
    
    let path = "/v1/upload"
    let parameters: APIRequestParameters
    
    init(fileURL: URL) {
        parameters = .multipart([.fileURL(url: fileURL, name: "file")])
    }
}

struct GetRequest: APIRequest {
    typealias Response = User
    let path = "/v1/user/my/base"
    let method: HTTPMethod? = .get
}

struct SlowRequest: APIRequest {
    typealias Response = User
    let path = "/v1/user/my/base"
    let timeoutInterval: TimeInterval? = 60
}
```

You may also group requests using protocol inheritance.

```swift
protocol GetRequest: APIRequest { }
extension GetRequest {
    var method: HTTPMethod? { .get }
}

// LyricsRequest, SongDetailRequest, UserInfoRequest all have `.get` as default value for `method`.
struct UserInfoRequest: GetRequest { ... }
struct SongDetailRequest: GetRequest { ... }
struct LyricsRequest: GetRequest { ... }

```

## APIClient

`APIClient` is responsible for sending requests.

```swift
public protocol APIClient {
    @discardableResult func send<Request: APIRequest>(_ request: Request, completion: @escaping (Result<Request.Response, Error>) -> Void) -> NetworkRequest
}
```

There is a default implementation of `APIClient` - `SimpleAPIClient`. You can also build your own `APIClient` if the `SimpleAPIClient` is not suitable.

