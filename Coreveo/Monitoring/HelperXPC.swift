import Foundation

/// XPC interface for privileged helper (scaffold only; no implementation here).
@objc public protocol HelperServiceProtocol {
	/// Best-effort read of restricted sensor by key or path.
	/// - Parameters:
	///   - request: A simple request describing the operation.
	///   - reply: Completion with a response or error code encapsulated in the response.
	func readRestricted(_ request: HelperRequest, with reply: @escaping (HelperResponse) -> Void)
}

/// Simple request describing what to read.
@objc public class HelperRequest: NSObject, NSSecureCoding {
	public static var supportsSecureCoding: Bool = true
	public let kind: String      // e.g., "smc", "nvme", "gpu"
	public let identifier: String // key/path/channel

	public init(kind: String, identifier: String) {
		self.kind = kind
		self.identifier = identifier
	}

	public required convenience init?(coder: NSCoder) {
		guard let k = coder.decodeObject(of: NSString.self, forKey: "kind") as String?,
				let i = coder.decodeObject(of: NSString.self, forKey: "identifier") as String? else { return nil }
		self.init(kind: k, identifier: i)
	}

	public func encode(with coder: NSCoder) {
		coder.encode(kind as NSString, forKey: "kind")
		coder.encode(identifier as NSString, forKey: "identifier")
	}
}

/// Simple response payload for helper operations.
@objc public class HelperResponse: NSObject, NSSecureCoding {
	public static var supportsSecureCoding: Bool = true
	public let ok: Bool
	public let value: NSNumber?
	public let message: NSString?

	public init(ok: Bool, value: NSNumber?, message: NSString?) {
		self.ok = ok
		self.value = value
		self.message = message
	}

	public required convenience init?(coder: NSCoder) {
		let ok = coder.decodeBool(forKey: "ok")
		let value = coder.decodeObject(of: NSNumber.self, forKey: "value")
		let message = coder.decodeObject(of: NSString.self, forKey: "message")
		self.init(ok: ok, value: value, message: message)
	}

	public func encode(with coder: NSCoder) {
		coder.encode(ok, forKey: "ok")
		coder.encode(value, forKey: "value")
		coder.encode(message, forKey: "message")
	}
}

/// Client wrapper used by the app; will later bridge to NSXPCConnection.
public final class HelperClient {
	private let service: HelperServiceProtocol
    private var lastHeartbeat: Date?

	public init(service: HelperServiceProtocol) {
		self.service = service
	}

	public func readRestricted(kind: String, identifier: String, completion: @escaping (Result<Double, Error>) -> Void) {
		let req = HelperRequest(kind: kind, identifier: identifier)
		service.readRestricted(req) { resp in
			if resp.ok, let v = resp.value?.doubleValue {
				completion(.success(v))
			} else {
				let reason = resp.message as String? ?? "helper error"
				completion(.failure(NSError(domain: "HelperClient", code: -1, userInfo: [NSLocalizedDescriptionKey: reason])))
			}
		}
	}

    /// Simple heartbeat update to detect helper liveness.
    public func heartbeat(receivedAt date: Date = Date()) { lastHeartbeat = date }
    public func isAlive(now: Date = Date(), timeout: TimeInterval = 5.0) -> Bool {
        guard let hb = lastHeartbeat else { return false }
        return now.timeIntervalSince(hb) < timeout
    }
}


