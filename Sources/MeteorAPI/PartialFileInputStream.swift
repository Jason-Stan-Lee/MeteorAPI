import Foundation

// InputStream is a class cluster, we need to override all of its method to subclass.
public final class PartialFileInputStream: InputStream {
    private var offset: Int!
    private var length: Int!
    private var parent: InputStream!
    
    private var bytesLeft: Int!
    
    public static func forReadingFile(at url: URL, offset: Int, length: Int) -> PartialFileInputStream? {
        guard let parentInputStream = InputStream(url: url) else {
            return nil
        }
        let stream = PartialFileInputStream()
        stream.parent = parentInputStream
        stream.length = length
        stream.bytesLeft = length
        stream.offset = offset
        return stream
    }
    
    public override func open() {
        parent.open()
        parent.setProperty(NSNumber(value: offset), forKey: .fileCurrentOffsetKey)
        bytesLeft = length
    }
    
    public override func close() {
        parent.close()
    }
    
    public override var delegate: StreamDelegate? {
        get {
            return parent.delegate
        }
        set {
            assertionFailure("=== not tested ===")
            parent.delegate = newValue
        }
    }
    
    public override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        assert(bytesLeft > 0)
        guard bytesLeft > 0 else {
            return 0
        }
        let readLength: Int
        if len > bytesLeft {
            readLength = bytesLeft
        } else {
            readLength = len
        }
        let bytesRead = parent.read(buffer, maxLength: readLength)
        bytesLeft -= bytesRead
        return bytesRead
    }
    
    public override func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool {
        return false
    }
    
    public override var hasBytesAvailable: Bool {
        if bytesLeft <= 0 {
            return false
        }
        return parent.hasBytesAvailable
    }
    
    public override var streamStatus: Stream.Status {
        parent.streamStatus
    }
    
    public override var streamError: Error? {
        parent.streamError
    }
    
    public override func property(forKey key: Stream.PropertyKey) -> Any? {
        parent.property(forKey: key)
    }
    
    public override func setProperty(_ property: Any?, forKey key: Stream.PropertyKey) -> Bool {
        parent.setProperty(property, forKey: key)
    }
    
    public override func schedule(in aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {
        parent.schedule(in: aRunLoop, forMode: mode)
    }
    
    public override func remove(from aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {
        parent.remove(from: aRunLoop, forMode: mode)
    }
}
