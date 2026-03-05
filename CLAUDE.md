# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

```bash
swift build          # Build the library
swift test           # Run all tests
swift test --filter SwiftTUITests.ViewBuildTests  # Run a single test class
```

Swift tools version 6.2, minimum macOS 11. Also supports Linux.

## Architecture

SwiftTUI is a terminal UI framework that mirrors SwiftUI's architecture. It renders text-based interfaces using ANSI escape sequences.

### Three-Layer Architecture

1. **View Graph** (`Sources/SwiftTUI/ViewGraph/`) - Runtime representation of view hierarchy
   - `View` protocol - user-facing, matches SwiftUI's API (`body`, `@ViewBuilder`)
   - `GenericView` protocol - internal interface for the view graph; either a `PrimitiveView` or `ComposedView`
   - `PrimitiveView` - views with `Body = Never` that have custom node build/update logic (Text, Button, stacks, etc.)
   - `ComposedView` - wraps user-defined views, wiring up state/environment and delegating to `body`
   - `ModifierView` - protocol for views that transform controls as they pass through (padding, color, border)
   - `LayoutRootView` - protocol for container views (stacks, scroll views) that manage child controls lazily
   - `Node` - view graph node; manages state, environment, children, and maps to controls

2. **Controls** (`Sources/SwiftTUI/Controls/`) - Layout and event handling layer
   - `Control` - base class for layout objects; handles sizing, layout, drawing cells, focus/selection, scrolling
   - `Window` - root control that manages first responder chain

3. **Rendering** (`Sources/SwiftTUI/Drawing/Rendering/`) - Terminal output
   - `Renderer` - diff-based drawing using a cell cache; only redraws invalidated regions
   - `Layer` - compositing layer with frame, sublayers, and invalidation tracking
   - `EscapeSequence` - ANSI escape code generation

### Data Flow

`Application` owns the root `Node`, `Control`, `Window`, and `Renderer`. State changes invalidate nodes, which are batched and updated on the next main queue cycle (`invalidateNode` → `scheduleUpdate` → `update`).

### Key Directories

- `Views/Controls/` - Primitive UI components (Text, Button, TextField, ScrollView, Spacer, Divider, GeometryReader)
- `Views/Stacks/` - HStack, VStack, ZStack with alignment
- `Views/Modifiers/` - View modifiers (padding, frame, border, foreground/background color, bold, italic, etc.)
- `PropertyWrappers/` - @State, @Binding, @Environment, @ObservedObject (macOS-only Combine dependency)
- `RunLoop/` - Application entry point, input handling, arrow key parsing
- `Drawing/` - Color (ANSI/xterm/TrueColor), Cell, Position, Size, Rect, Extended (infinity-capable numeric type)

### Platform Differences

`@ObservedObject` and Combine-based subscriptions are macOS-only (`#if os(macOS)`). On Linux, only `@State`, `@Binding`, and `@Environment` are available.

## Examples

Four example apps in `Examples/` (ToDoList, Flags, Colors, Numbers) — each is a standalone Swift package that depends on SwiftTUI.
