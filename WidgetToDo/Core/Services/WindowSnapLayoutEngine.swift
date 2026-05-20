import CoreGraphics
import Foundation

public enum WindowSnapLayoutEngine {
    public struct Configuration: Equatable {
        public var horizontalGap: CGFloat
        public var verticalGap: CGFloat
        public var softSnapRadius: CGFloat
        public var hardSnapRadius: CGFloat
        public var reanchorDistance: CGFloat

        public init(
            horizontalGap: CGFloat,
            verticalGap: CGFloat,
            softSnapRadius: CGFloat,
            hardSnapRadius: CGFloat,
            reanchorDistance: CGFloat
        ) {
            self.horizontalGap = horizontalGap
            self.verticalGap = verticalGap
            self.softSnapRadius = softSnapRadius
            self.hardSnapRadius = hardSnapRadius
            self.reanchorDistance = reanchorDistance
        }

        public func horizontalStride(for panelSize: CGSize) -> CGFloat {
            panelSize.width + horizontalGap
        }

        public func verticalStride(for panelSize: CGSize) -> CGFloat {
            panelSize.height + verticalGap
        }
    }

    public struct Slot: Equatable {
        public var id: String
        public var offset: CGPoint
        public var origin: CGPoint
        public var panelFrame: CGRect
        public var isValid: Bool

        public init(id: String, offset: CGPoint, origin: CGPoint, panelFrame: CGRect, isValid: Bool) {
            self.id = id
            self.offset = offset
            self.origin = origin
            self.panelFrame = panelFrame
            self.isValid = isValid
        }
    }

    public struct SlotLayout: Equatable {
        public var anchorOrigin: CGPoint
        public var slots: [Slot]

        public init(anchorOrigin: CGPoint, slots: [Slot]) {
            self.anchorOrigin = anchorOrigin
            self.slots = slots
        }
    }

    public struct SlotSelection: Equatable {
        public var slot: Slot?
        public var distance: CGFloat
        public var isWithinSoftRadius: Bool
        public var isWithinHardRadius: Bool

        public init(slot: Slot?, distance: CGFloat, isWithinSoftRadius: Bool, isWithinHardRadius: Bool) {
            self.slot = slot
            self.distance = distance
            self.isWithinSoftRadius = isWithinSoftRadius
            self.isWithinHardRadius = isWithinHardRadius
        }
    }

    public static func generateSlots(
        around panelFrame: CGRect,
        visibleFrame: CGRect,
        configuration: Configuration
    ) -> SlotLayout {
        let panelSize = panelFrame.size
        let xStride = configuration.horizontalStride(for: panelSize)
        let yStride = configuration.verticalStride(for: panelSize)

        let anchorOrigin = CGPoint(
            x: round(panelFrame.origin.x / xStride) * xStride,
            y: round(panelFrame.origin.y / yStride) * yStride
        )

        var slots: [Slot] = []
        for yOffset in -1...1 {
            for xOffset in -1...1 {
                let origin = CGPoint(
                    x: anchorOrigin.x + CGFloat(xOffset) * xStride,
                    y: anchorOrigin.y + CGFloat(yOffset) * yStride
                )
                let frame = CGRect(origin: origin, size: panelSize)
                slots.append(
                    Slot(
                        id: "\(xOffset),\(yOffset)",
                        offset: CGPoint(x: CGFloat(xOffset), y: CGFloat(yOffset)),
                        origin: origin,
                        panelFrame: frame,
                        isValid: visibleFrame.contains(frame)
                    )
                )
            }
        }

        return SlotLayout(anchorOrigin: anchorOrigin, slots: slots)
    }

    public static func selectNearestSlot(
        for panelFrame: CGRect,
        from slots: [Slot],
        configuration: Configuration
    ) -> SlotSelection {
        let panelCenter = panelFrame.center
        let validSlots = slots.filter(\.isValid)

        guard let nearestSlot = validSlots.min(by: {
            distance(from: panelCenter, to: $0.panelFrame.center) < distance(from: panelCenter, to: $1.panelFrame.center)
        }) else {
            return SlotSelection(
                slot: nil,
                distance: .infinity,
                isWithinSoftRadius: false,
                isWithinHardRadius: false
            )
        }

        let nearestDistance = distance(from: panelCenter, to: nearestSlot.panelFrame.center)
        return SlotSelection(
            slot: nearestSlot,
            distance: nearestDistance,
            isWithinSoftRadius: nearestDistance <= configuration.softSnapRadius,
            isWithinHardRadius: nearestDistance <= configuration.hardSnapRadius
        )
    }

    public static func shouldReanchor(
        from anchorOrigin: CGPoint,
        to panelFrame: CGRect,
        configuration: Configuration
    ) -> Bool {
        distance(from: anchorOrigin, to: panelFrame.origin) >= configuration.reanchorDistance
    }

    public static func clampPanelOrigin(
        _ origin: CGPoint,
        panelSize: CGSize,
        visibleFrame: CGRect
    ) -> CGPoint {
        CGPoint(
            x: min(max(origin.x, visibleFrame.minX), visibleFrame.maxX - panelSize.width),
            y: min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - panelSize.height)
        )
    }

    private static func distance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return sqrt(dx * dx + dy * dy)
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
