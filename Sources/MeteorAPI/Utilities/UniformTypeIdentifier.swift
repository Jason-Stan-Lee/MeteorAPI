import Foundation
import CoreServices

public struct UniformTypeIdentifier {
    public let pathExtension: String
    public let mimeType: String
    public let typeID: String
    
    public init(typeID: String) {
        self.typeID = typeID
        if let mimeType = UTTypeCopyPreferredTagWithClass(typeID as CFString, kUTTagClassMIMEType)?.takeRetainedValue() {
            self.mimeType = mimeType as String
        } else {
            self.mimeType = "application/octet-stream"
        }
        if let pathExtension = UTTypeCopyPreferredTagWithClass(typeID as CFString, kUTTagClassFilenameExtension)?.takeRetainedValue() {
            self.pathExtension = pathExtension as String
        } else {
            self.pathExtension = "bin"
        }
    }
    
    public init(pathExtension: String) {
        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as CFString, nil)?.takeRetainedValue() {
            self.init(typeID: uti as String)
        } else {
            self.init(typeID: kUTTypeData as String)
        }
    }
}
