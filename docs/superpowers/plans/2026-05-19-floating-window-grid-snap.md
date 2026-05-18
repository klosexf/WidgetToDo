# Floating Window Grid Snap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS 12-compatible desktop drag interaction for the floating widget window with local large-slot visual guidance, nearest-slot preview, and animated snap-on-release behavior.

**Architecture:** Keep window movement orchestration in `FloatingWindowManager`, move slot math into a pure `WindowSnapLayoutEngine` under the existing core module so it can be tested, and add a dedicated AppKit overlay controller to render placement slots without intercepting mouse input. Lower deployment targets before implementation so the feature is designed against the actual compatibility floor.

**Tech Stack:** Swift, SwiftUI, AppKit, CoreGraphics, Swift Package Manager, XCTest, `NSPanel`, `NSWindowDelegate`, `NSAnimationContext`

---

### File Map

**Create:**
- `WidgetToDo/Core/Services/WindowSnapLayoutEngine.swift`
- `WidgetToDo/WindowSnapOverlayController.swift`
- `Tests/NotionFloatCoreTests/WindowSnapLayoutEngineTests.swift`

**Modify:**
- `Package.swift`
- `WidgetToDo/FloatingWindowManager.swift`
- `WidgetToDo.xcodeproj/project.pbxproj`

### Task 1: Lower The Real Deployment Floor To macOS 12

**Files:**
- Modify: `Package.swift`
- Modify: `WidgetToDo.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write the failing compatibility assertion as a test-side guard**

Add this test to `Tests/NotionFloatCoreTests/WindowSnapLayoutEngineTests.swift` before any feature logic:

```swift
import XCTest
@testable import NotionFloatCore

final class WindowSnapLayoutEngineTests: XCTestCase {
    func testHorizontalStrideMatchesWindowWidthPlusGap() {
        let config = WindowSnapLayoutEngine.Configuration(
            horizontalGap: 32,
            verticalGap: 32,
            softSnapRadius: 90,
            hardSnapRadius: 160,
            reanchorDistance: 120
        )

        XCTAssertEqual(config.horizontalStride(for: CGSize(width: 330, height: 560)), 362)
        XCTAssertEqual(config.verticalStride(for: CGSize(width: 330, height: 560)), 592)
    }
}
```

This test will fail until the new engine type exists, giving the first red state.

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter WindowSnapLayoutEngineTests/testHorizontalStrideMatchesWindowWidthPlusGap
```

Expected:

- build fails with errors such as `cannot find 'WindowSnapLayoutEngine' in scope`
- this is the correct red state

- [ ] **Step 3: Lower deployment targets before feature code**

Update `Package.swift`:

```swift
let package = Package(
    name: "NotionFloatCore",
    platforms: [
        .macOS(.v12)
    ],
```

Update both `MACOSX_DEPLOYMENT_TARGET` values in `WidgetToDo.xcodeproj/project.pbxproj`:

```pbxproj
MACOSX_DEPLOYMENT_TARGET = 12.0;
```

Do not change anything else in the project file in this step.

- [ ] **Step 4: Add the real XCTest target**

Extend `Package.swift` targets:

```swift
    targets: [
        .target(
            name: "NotionFloatCore",
            path: "WidgetToDo/Core"
        ),
        .testTarget(
            name: "NotionFloatCoreTests",
            dependencies: ["NotionFloatCore"],
            path: "Tests/NotionFloatCoreTests"
        ),
        .executableTarget(
            name: "NotionFloatCoreSmokeTests",
            dependencies: ["NotionFloatCore"],
            path: "Tests/NotionFloatCoreSmokeTests"
        )
    ]
```

- [ ] **Step 5: Run the red test again**

Run:

```bash
swift test --filter WindowSnapLayoutEngineTests/testHorizontalStrideMatchesWindowWidthPlusGap
```

Expected:

- the package resolves the new test target
- the test still fails because `WindowSnapLayoutEngine` is not implemented yet

- [ ] **Step 6: Commit**

```bash
git add Package.swift WidgetToDo.xcodeproj/project.pbxproj Tests/NotionFloatCoreTests/WindowSnapLayoutEngineTests.swift
git commit -m "build: lower deployment target to macos 12"
```

### Task 2: Add Red Tests For Slot Generation And Selection

**Files:**
- Modify: `Tests/NotionFloatCoreTests/WindowSnapLayoutEngineTests.swift`
- Create: `WidgetToDo/Core/Services/WindowSnapLayoutEngine.swift`

- [ ] **Step 1: Expand the failing test file with slot generation cases**

Replace the test file contents with:

```swift
import XCTest
@testable import NotionFloatCore

final class WindowSnapLayoutEngineTests: XCTestCase {
    private let config = WindowSnapLayoutEngine.Configuration(
        horizontalGap: 32,
        verticalGap: 32,
        softSnapRadius: 90,
        hardSnapRadius: 160,
        reanchorDistance: 120
    )

    func testHorizontalStrideMatchesWindowWidthPlusGap() {
        XCTAssertEqual(config.horizontalStride(for: CGSize(width: 330, height: 560)), 362)
        XCTAssertEqual(config.verticalStride(for: CGSize(width: 330, height: 560)), 592)
    }

    func testGenerateSlotsReturnsNineSlotsInOpenSpace() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1600, height: 1200)
        let panelFrame = CGRect(x: 500, y: 300, width: 330, height: 560)

        let result = WindowSnapLayoutEngine.generateSlots(
            around: panelFrame,
            visibleFrame: visibleFrame,
            configuration: config
        )

        XCTAssertEqual(result.slots.count, 9)
        XCTAssertEqual(result.slots.filter(\.isValid).count, 9)
        XCTAssertEqual(result.anchorOrigin, CGPoint(x: 362, y: 592))
    }

    func testGenerateSlotsFiltersInvalidFramesNearTopRightEdge() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let panelFrame = CGRect(x: 850, y: 280, width: 330, height: 560)

        let result = WindowSnapLayoutEngine.generateSlots(
            around: panelFrame,
            visibleFrame: visibleFrame,
            configuration: config
        )

        XCTAssertLessThan(result.slots.filter(\.isValid).count, 9)
        XCTAssertTrue(result.slots.contains(where: { !$0.isValid }))
        XCTAssertTrue(result.slots.filter(\.isValid).allSatisfy { visibleFrame.contains($0.panelFrame) })
    }

    func testNearestSlotUsesPanelCenterDistance() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1600, height: 1200)
        let panelFrame = CGRect(x: 500, y: 300, width: 330, height: 560)

        let result = WindowSnapLayoutEngine.generateSlots(
            around: panelFrame,
            visibleFrame: visibleFrame,
            configuration: config
        )

        let draggedFrame = CGRect(x: 730, y: 310, width: 330, height: 560)
        let selection = WindowSnapLayoutEngine.selectNearestSlot(
            for: draggedFrame,
            from: result.slots,
            configuration: config
        )

        XCTAssertEqual(selection.slot?.offset, CGPoint(x: 1, y: 0))
        XCTAssertTrue(selection.isWithinHardRadius)
    }

    func testClampPanelOriginKeepsWindowInsideVisibleFrame() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let clamped = WindowSnapLayoutEngine.clampPanelOrigin(
            CGPoint(x: 990, y: 500),
            panelSize: CGSize(width: 330, height: 560),
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(clamped, CGPoint(x: 870, y: 340))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter WindowSnapLayoutEngineTests
```

Expected:

- compile errors for missing `WindowSnapLayoutEngine`, `Configuration`, `generateSlots`, `selectNearestSlot`, and `clampPanelOrigin`

- [ ] **Step 3: Add a stub engine file with compiling placeholders**

Create `WidgetToDo/Core/Services/WindowSnapLayoutEngine.swift`:

```swift
import CoreGraphics
import Foundation

public enum WindowSnapLayoutEngine {}
```

This is intentionally insufficient. The next test run should still fail with missing members, not import errors.

- [ ] **Step 4: Run tests to verify they still fail for the right reason**

Run:

```bash
swift test --filter WindowSnapLayoutEngineTests
```

Expected:

- compile errors now reference missing nested types and functions on `WindowSnapLayoutEngine`

- [ ] **Step 5: Commit**

```bash
git add Tests/NotionFloatCoreTests/WindowSnapLayoutEngineTests.swift WidgetToDo/Core/Services/WindowSnapLayoutEngine.swift
git commit -m "test: add red tests for window snap layout"
```

### Task 3: Implement The Pure Layout Engine Until Tests Turn Green

**Files:**
- Modify: `WidgetToDo/Core/Services/WindowSnapLayoutEngine.swift`
- Test: `Tests/NotionFloatCoreTests/WindowSnapLayoutEngineTests.swift`

- [ ] **Step 1: Implement the full engine data model and math**

Replace `WidgetToDo/Core/Services/WindowSnapLayoutEngine.swift` with:

```swift
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
    }

    public struct SlotSelection: Equatable {
        public var slot: Slot?
        public var distance: CGFloat
        public var isWithinSoftRadius: Bool
        public var isWithinHardRadius: Bool
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
        for y in -1...1 {
            for x in -1...1 {
                let origin = CGPoint(
                    x: anchorOrigin.x + CGFloat(x) * xStride,
                    y: anchorOrigin.y + CGFloat(y) * yStride
                )
                let panelFrame = CGRect(origin: origin, size: panelSize)
                let isValid = visibleFrame.contains(panelFrame)
                slots.append(
                    Slot(
                        id: "\(x),\(y)",
                        offset: CGPoint(x: x, y: y),
                        origin: origin,
                        panelFrame: panelFrame,
                        isValid: isValid
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
        let panelCenter = CGPoint(x: panelFrame.midX, y: panelFrame.midY)
        let validSlots = slots.filter(\.isValid)

        guard let nearest = validSlots.min(by: {
            distance(from: panelCenter, to: $0.panelFrame.center) < distance(from: panelCenter, to: $1.panelFrame.center)
        }) else {
            return SlotSelection(slot: nil, distance: .infinity, isWithinSoftRadius: false, isWithinHardRadius: false)
        }

        let distanceToNearest = distance(from: panelCenter, to: nearest.panelFrame.center)
        return SlotSelection(
            slot: nearest,
            distance: distanceToNearest,
            isWithinSoftRadius: distanceToNearest <= configuration.softSnapRadius,
            isWithinHardRadius: distanceToNearest <= configuration.hardSnapRadius
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
```

- [ ] **Step 2: Run tests to verify they pass**

Run:

```bash
swift test --filter WindowSnapLayoutEngineTests
```

Expected:

- all `WindowSnapLayoutEngineTests` pass

- [ ] **Step 3: Run smoke tests to verify core behavior remains intact**

Run:

```bash
swift run NotionFloatCoreSmokeTests
```

Expected:

- output contains `All smoke tests passed.`

- [ ] **Step 4: Commit**

```bash
git add WidgetToDo/Core/Services/WindowSnapLayoutEngine.swift Tests/NotionFloatCoreTests/WindowSnapLayoutEngineTests.swift
git commit -m "feat: add window snap layout engine"
```

### Task 4: Add The Overlay Controller For Local Placement Slots

**Files:**
- Create: `WidgetToDo/WindowSnapOverlayController.swift`

- [ ] **Step 1: Write the new overlay controller file**

Create `WidgetToDo/WindowSnapOverlayController.swift`:

```swift
import AppKit
import NotionFloatCore

@MainActor
final class WindowSnapOverlayController {
    private let window: NSWindow
    private let overlayView: OverlayView

    init(screenFrame: CGRect) {
        overlayView = OverlayView(frame: screenFrame)
        window = NSWindow(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.contentView = overlayView
    }

    func show(on screen: NSScreen) {
        window.setFrame(screen.frame, display: false)
        overlayView.frame = screen.frame
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
    }

    func update(slots: [WindowSnapLayoutEngine.Slot], activeSlotID: String?, previewFrame: CGRect?) {
        overlayView.slots = slots
        overlayView.activeSlotID = activeSlotID
        overlayView.previewFrame = previewFrame
        overlayView.needsDisplay = true
    }
}

private final class OverlayView: NSView {
    var slots: [WindowSnapLayoutEngine.Slot] = []
    var activeSlotID: String?
    var previewFrame: CGRect?

    override var isFlipped: Bool {
        false
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        for slot in slots where slot.isValid {
            let isActive = slot.id == activeSlotID
            let path = NSBezierPath(roundedRect: slot.panelFrame, xRadius: 36, yRadius: 36)
            (isActive ? NSColor.white.withAlphaComponent(0.18) : NSColor.white.withAlphaComponent(0.08)).setFill()
            path.fill()
            path.lineWidth = isActive ? 3 : 1.5
            (isActive ? NSColor.white.withAlphaComponent(0.58) : NSColor.white.withAlphaComponent(0.28)).setStroke()
            path.stroke()
        }

        if let previewFrame {
            let previewPath = NSBezierPath(roundedRect: previewFrame, xRadius: 36, yRadius: 36)
            previewPath.setLineDash([10, 8], count: 2, phase: 0)
            previewPath.lineWidth = 2
            NSColor.white.withAlphaComponent(0.72).setStroke()
            previewPath.stroke()
        }
    }
}
```

- [ ] **Step 2: Build the app target to verify the new file compiles**

Run:

```bash
xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -sdk macosx build
```

Expected:

- build succeeds
- no missing import or symbol errors for `NotionFloatCore`

- [ ] **Step 3: Commit**

```bash
git add WidgetToDo/WindowSnapOverlayController.swift
git commit -m "feat: add window snap overlay controller"
```

### Task 5: Integrate Drag Lifecycle, Local Slot Updates, And Snap-On-Release

**Files:**
- Modify: `WidgetToDo/FloatingWindowManager.swift`
- Create: `WidgetToDo/WindowSnapOverlayController.swift`
- Modify: `WidgetToDo/Core/Services/WindowSnapLayoutEngine.swift`

- [ ] **Step 1: Replace the current fixed micro-grid manager with slot-based state**

Update `WidgetToDo/FloatingWindowManager.swift` to:

```swift
import AppKit
import NotionFloatCore
import SwiftUI

@MainActor
final class FloatingWindowManager: NSObject {
    private let panel: NSPanel
    private var isDragging = false
    private var dragMonitor: Any?
    private var overlayController: WindowSnapOverlayController?
    private var activeScreen: NSScreen?
    private var slotLayout: WindowSnapLayoutEngine.SlotLayout?
    private var activeSlotID: String?
    private let snapConfiguration = WindowSnapLayoutEngine.Configuration(
        horizontalGap: 32,
        verticalGap: 32,
        softSnapRadius: 90,
        hardSnapRadius: 160,
        reanchorDistance: 120
    )

    init(rootView: ContentView) {
        let panel = NSPanel(
            contentRect: NSRect(x: 240, y: 240, width: 330, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopIconWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.hasShadow = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.contentViewController = NSHostingController(rootView: rootView)
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        self.panel = panel
        super.init()
        panel.delegate = self

        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            Task { @MainActor in
                self?.finishDragging()
            }
        }
    }

    deinit {
        if let dragMonitor {
            NSEvent.removeMonitor(dragMonitor)
        }
    }

    func show() {
        panel.center()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    private func beginDragging() {
        guard !isDragging else { return }
        isDragging = true
        activeScreen = screenForCurrentPanelFrame()
        refreshSlotLayout(force: true)
    }

    private func updateDragging() {
        guard isDragging else { return }
        refreshSlotLayout(force: false)
        updateOverlaySelection()
    }

    private func finishDragging() {
        guard isDragging else { return }
        defer {
            isDragging = false
            activeSlotID = nil
            slotLayout = nil
            overlayController?.hide()
        }

        guard
            let screen = activeScreen ?? screenForCurrentPanelFrame(),
            let slotLayout
        else { return }

        let selection = WindowSnapLayoutEngine.selectNearestSlot(
            for: panel.frame,
            from: slotLayout.slots,
            configuration: snapConfiguration
        )

        let targetOrigin: CGPoint
        if let slot = selection.slot, selection.isWithinHardRadius {
            targetOrigin = WindowSnapLayoutEngine.clampPanelOrigin(
                slot.origin,
                panelSize: panel.frame.size,
                visibleFrame: screen.visibleFrame
            )
        } else {
            targetOrigin = WindowSnapLayoutEngine.clampPanelOrigin(
                panel.frame.origin,
                panelSize: panel.frame.size,
                visibleFrame: screen.visibleFrame
            )
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrameOrigin(targetOrigin)
        }
    }

    private func refreshSlotLayout(force: Bool) {
        guard let screen = screenForCurrentPanelFrame() else { return }
        activeScreen = screen

        if overlayController == nil {
            overlayController = WindowSnapOverlayController(screenFrame: screen.frame)
        }

        if force || shouldReanchorLayout(for: panel.frame) {
            slotLayout = WindowSnapLayoutEngine.generateSlots(
                around: panel.frame,
                visibleFrame: screen.visibleFrame,
                configuration: snapConfiguration
            )
        }

        overlayController?.show(on: screen)
    }

    private func shouldReanchorLayout(for frame: CGRect) -> Bool {
        guard let slotLayout else { return true }
        return WindowSnapLayoutEngine.shouldReanchor(
            from: slotLayout.anchorOrigin,
            to: frame,
            configuration: snapConfiguration
        )
    }

    private func updateOverlaySelection() {
        guard let slotLayout else { return }
        let selection = WindowSnapLayoutEngine.selectNearestSlot(
            for: panel.frame,
            from: slotLayout.slots,
            configuration: snapConfiguration
        )
        activeSlotID = selection.slot?.id
        let previewFrame = selection.isWithinSoftRadius ? selection.slot?.panelFrame : nil
        overlayController?.update(
            slots: slotLayout.slots,
            activeSlotID: activeSlotID,
            previewFrame: previewFrame
        )
    }

    private func screenForCurrentPanelFrame() -> NSScreen? {
        panel.screen
            ?? NSScreen.screens.max(by: { lhs, rhs in
                lhs.frame.intersection(panel.frame).area < rhs.frame.intersection(panel.frame).area
            })
            ?? NSScreen.main
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull else { return 0 }
        return width * height
    }
}

extension FloatingWindowManager: NSWindowDelegate {
    func windowWillMove(_ notification: Notification) {
        beginDragging()
    }

    func windowDidMove(_ notification: Notification) {
        updateDragging()
    }
}
```

- [ ] **Step 2: If the pure engine needs visibility changes, make them now**

If the app target cannot access engine members because of visibility, keep this exact access level pattern in `WidgetToDo/Core/Services/WindowSnapLayoutEngine.swift`:

```swift
public enum WindowSnapLayoutEngine {
    public struct Configuration: Equatable { ... }
    public struct Slot: Equatable { ... }
    public struct SlotLayout: Equatable { ... }
    public struct SlotSelection: Equatable { ... }
    public static func generateSlots(...) -> SlotLayout { ... }
    public static func selectNearestSlot(...) -> SlotSelection { ... }
    public static func shouldReanchor(...) -> Bool { ... }
    public static func clampPanelOrigin(...) -> CGPoint { ... }
}
```

- [ ] **Step 3: Build the app to verify drag integration compiles**

Run:

```bash
xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -sdk macosx build
```

Expected:

- build succeeds
- no duplicate symbol or visibility errors

- [ ] **Step 4: Run the engine tests again to catch math regressions**

Run:

```bash
swift test --filter WindowSnapLayoutEngineTests
```

Expected:

- all layout-engine tests still pass

- [ ] **Step 5: Commit**

```bash
git add WidgetToDo/FloatingWindowManager.swift WidgetToDo/WindowSnapOverlayController.swift WidgetToDo/Core/Services/WindowSnapLayoutEngine.swift
git commit -m "feat: add floating window slot snapping"
```

### Task 6: Verify Behavior On Real macOS Drag Sessions

**Files:**
- No code changes required unless a verification failure is found

- [ ] **Step 1: Run the full package tests**

Run:

```bash
swift test
```

Expected:

- `WindowSnapLayoutEngineTests` pass
- package exits with code 0

- [ ] **Step 2: Run the smoke executable**

Run:

```bash
swift run NotionFloatCoreSmokeTests
```

Expected:

- output contains `All smoke tests passed.`

- [ ] **Step 3: Build the app target**

Run:

```bash
xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -sdk macosx build
```

Expected:

- build succeeds with deployment target set to macOS 12.0

- [ ] **Step 4: Manually verify the drag interaction**

Verify this checklist in the running app:

```text
1. Start dragging the floating panel and confirm a local cluster of large rounded slots appears near the panel.
2. Move across candidate slots and confirm the nearest slot highlight updates without flicker.
3. Move near a slot edge and confirm the preview outline appears before release.
4. Release near a slot and confirm the panel animates into the nearest valid slot.
5. Drag near the top, right, and bottom screen edges and confirm invalid off-screen slots are not shown as active targets.
6. Drag across displays if a second monitor is connected and confirm snapping stays on the screen containing most of the panel.
```

- [ ] **Step 5: Commit the final verified state**

```bash
git add Package.swift WidgetToDo.xcodeproj/project.pbxproj WidgetToDo/Core/Services/WindowSnapLayoutEngine.swift WidgetToDo/FloatingWindowManager.swift WidgetToDo/WindowSnapOverlayController.swift Tests/NotionFloatCoreTests/WindowSnapLayoutEngineTests.swift
git commit -m "feat: add macos 12 window grid snap interaction"
```

## Self-Review

### Spec coverage

- local large-slot overlay: covered by Task 4 and Task 5
- slot-only placement and nearest-slot snap: covered by Task 3 and Task 5
- clear preview feedback: covered by Task 4 and Task 5
- macOS 12 compatibility: covered by Task 1 and Task 6
- edge handling and multi-display behavior: covered by Task 3, Task 5, and Task 6

### Placeholder scan

- no `TBD`
- no `TODO`
- no unspecified “write tests later” steps
- each code-bearing step includes concrete code

### Type consistency

- engine naming is consistently `WindowSnapLayoutEngine`
- slot type is consistently `WindowSnapLayoutEngine.Slot`
- overlay update method expects `activeSlotID` and `previewFrame`
- manager uses the same configuration and selection API names defined in the engine
