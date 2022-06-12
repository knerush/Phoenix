public protocol AppVersionProtocol {
    var major: Int { get }
    var minor: Int { get }
    var hotfix: Int { get }
}

public extension AppVersionProtocol {
    var stringValue: String {
        [major, minor, hotfix].map(String.init).joined(separator: ".")
    }
}

public func ==(lhs: AppVersionProtocol, rhs: String) -> Bool {
    return lhs.stringValue == rhs
}
