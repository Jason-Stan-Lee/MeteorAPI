import Foundation
import MeteorAPI

@MainActor
fileprivate final class APIPollingTaskCancellationWrapper<Coordinator: APIPollingTaskCoordinator> {
    var task: APIPollingTask<Coordinator>?
    init() {}
}

extension APIPollingTask {
    @MainActor
    public static func performTask(using api: APIClient, initialRequest: Coordinator.InitialRequest, coordinator: Coordinator, configuration: Configuration = Configuration()) async throws -> Coordinator.Response {
        let taskCancellationWrapper = APIPollingTaskCancellationWrapper<Coordinator>()
        return try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation({ continuation in
                dispatchPrecondition(condition: .onQueue(.main))
                let task = APIPollingTask(api: api, initialRequest: initialRequest, coordinator: coordinator, completion: continuation.resume(with:))
                taskCancellationWrapper.task = task
            })
        }, onCancel: {
            Task { @MainActor in
                taskCancellationWrapper.task?.cancel()
            }
        })        
    }
}
