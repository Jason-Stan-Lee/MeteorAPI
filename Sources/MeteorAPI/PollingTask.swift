import Foundation

public enum APIPollingTaskState<Response> {
    case progressing
    case finished(Result<Response, Error>)
}

public protocol APIPollingTaskCoordinator {
    associatedtype InitialRequest: APIRequest
    associatedtype CheckRequest: APIRequest
    associatedtype Response
    
    func makeCheckRequest(using result: InitialRequest.Response) throws -> CheckRequest
    func handleCheckResult(_ result: Result<CheckRequest.Response, Error>) -> APIPollingTaskState<Response>
    
    func handleTaskCancelled()
}

public struct APIPollingTaskBlockCoordinator<InitialRequest: APIRequest, CheckRequest: APIRequest, Response>: APIPollingTaskCoordinator {
    public typealias CheckRequestMaker = (InitialRequest.Response) throws -> CheckRequest
    public typealias CheckResultHandler = (Result<CheckRequest.Response, Error>) -> APIPollingTaskState<Response>
    
    private let checkRequestMaker: CheckRequestMaker
    private let checkResultHandler: CheckResultHandler
    private let cancellationHandler: () -> Void
    
    public init(checkRequestMaker: @escaping CheckRequestMaker,
         checkResultHandler: @escaping CheckResultHandler,
         cancellationHandler: @escaping () -> Void = {}) {
        self.checkRequestMaker = checkRequestMaker
        self.checkResultHandler = checkResultHandler
        self.cancellationHandler = cancellationHandler
    }
    
    public func makeCheckRequest(using result: InitialRequest.Response) throws -> CheckRequest {
        try self.checkRequestMaker(result)
    }
    
    public func handleCheckResult(_ result: Result<CheckRequest.Response, Error>) -> APIPollingTaskState<Response> {
        self.checkResultHandler(result)
    }
    
    public func handleTaskCancelled() {
        self.cancellationHandler()
    }
}

public class APIPollingTask<Coordinator> where Coordinator: APIPollingTaskCoordinator {
    
    public struct Configuration {
        public init(taskTimeoutInterval: TimeInterval = 600, checkInterval: TimeInterval = 1) {
            self.taskTimeoutInterval = taskTimeoutInterval
            self.checkInterval = checkInterval
        }
        public var taskTimeoutInterval: TimeInterval = 600
        public var checkInterval: TimeInterval = 1
    }
    
    private let initialRequest: Coordinator.InitialRequest
    private let coordinator: Coordinator
    private let api: APIClient
    private let configuration: Configuration
    
    private var completionHandler: ((Result<Coordinator.Response, Error>) -> Void)?
    private var isCancelled: Bool = false
    private weak var checkTimer: Timer?
    
    public init(api: APIClient, initialRequest: Coordinator.InitialRequest, coordinator: Coordinator, configuration: Configuration = Configuration(), completion: @escaping (Result<Coordinator.Response, Error>) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.configuration = configuration
        self.initialRequest = initialRequest
        self.coordinator = coordinator
        self.api = api
        self.completionHandler = completion
        self.api.send(initialRequest, completion: { result in
            guard !self.isCancelled else { return }
            switch result {
            case .failure(let error):
                self.taskFailed(error)
            case .success(let result):
                do {
                    let checkRequest = try self.coordinator.makeCheckRequest(using: result)
                    self.check(using: checkRequest)
                } catch {
                    self.taskFailed(error)
                }
            }
        })
    }
    
    private func check(using request: Coordinator.CheckRequest) {
        guard !self.isCancelled else { return }
        let startTime = CFAbsoluteTimeGetCurrent()
        self.api.send(request, completion: { result in
            guard !self.isCancelled else { return }
            let state = self.coordinator.handleCheckResult(result)
            switch state {
            case .progressing:
                let passedTime = CFAbsoluteTimeGetCurrent() - startTime
                if passedTime > self.configuration.checkInterval {
                    self.check(using: request)
                } else {
                    self.checkTimer?.invalidate()
                    let timer = Timer(timeInterval: self.configuration.checkInterval - passedTime, repeats: false, block: { _ in
                        self.check(using: request)
                    })
                    RunLoop.main.add(timer, forMode: .common)
                    self.checkTimer = timer
                }
            case .finished(let result):
                self.taskFinished(result)
            }
        })
    }
    
    private func taskFinished(_ result: Result<Coordinator.Response, Error>) {
        self.completionHandler?(result)
        self.completionHandler = nil
    }
    
    private func taskFailed(_ error: Error) {
        self.completionHandler?(.failure(error))
        self.completionHandler = nil
    }
    
    public func cancel() {
        dispatchPrecondition(condition: .onQueue(.main))
        self.isCancelled = true
        self.coordinator.handleTaskCancelled()
        self.taskFailed(URLError(.cancelled))
    }
}
