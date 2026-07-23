import CoreGraphics
import Foundation

public enum MiniActiveTab: String, Codable, Sendable, CaseIterable {
    case todo
    case journal
}

public struct CodableRect: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public init(_ rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }

    public var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

public struct MiniModeState: Codable, Equatable, Sendable {
    public var isMiniMode: Bool
    public var activeTab: MiniActiveTab
    public var normalFrame: CodableRect?

    public static let `default` = MiniModeState(
        isMiniMode: false,
        activeTab: .todo,
        normalFrame: nil
    )

    public init(
        isMiniMode: Bool,
        activeTab: MiniActiveTab,
        normalFrame: CodableRect?
    ) {
        self.isMiniMode = isMiniMode
        self.activeTab = activeTab
        self.normalFrame = normalFrame
    }
}
