import Foundation

#if os(macOS)
  import AppKit
#elseif os(Windows)
  import WinSDK
#endif

public class Application: @unchecked Sendable {
  private let node: Node
  private let window: Window
  private let control: Control
  private let renderer: Renderer

  private let runLoopType: RunLoopType

  private var invalidatedNodes: [Node] = []
  private var updateScheduled = false
  private let updateQueue = DispatchQueue(label: "SwiftTUI.Application.UpdateQueue", target: .main)

  public init<I: View>(rootView: I, runLoopType: RunLoopType = .dispatch) {
    self.runLoopType = runLoopType

    node = Node(view: VStack(content: rootView).view)
    node.build()

    control = node.control!

    window = Window()
    window.addControl(control)

    window.firstResponder = control.firstSelectableElement
    window.firstResponder?.becomeFirstResponder()

    renderer = Renderer(layer: window.layer)
    window.layer.renderer = renderer

    node.application = self
    renderer.application = self
  }

  var stdInSource: DispatchSourceRead?

  public enum RunLoopType {
    /// The default option, using Dispatch for the main run loop.
    case dispatch

    #if os(macOS)
      /// This creates and runs an NSApplication with an associated run loop. This allows you
      /// e.g. to open NSWindows running simultaneously to the terminal app. This requires macOS
      /// and AppKit.
      case cocoa
    #endif
  }

  public func start() {
    setInputMode()
    updateWindowSize()
    control.layout(size: window.layer.frame.size)
    renderer.draw()

    let stdInSource = DispatchSource.makeReadSource(fileDescriptor: STDIN_FILENO, queue: .main)
    stdInSource.setEventHandler(qos: .default, flags: [], handler: self.handleInput)
    stdInSource.resume()
    self.stdInSource = stdInSource

    #if !os(Windows)
      let sigWinChSource = DispatchSource.makeSignalSource(signal: SIGWINCH, queue: .main)
      sigWinChSource.setEventHandler(qos: .default, flags: [], handler: self.handleWindowSizeChange)
      sigWinChSource.resume()

      signal(SIGINT, SIG_IGN)
      let sigIntSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
      sigIntSource.setEventHandler(qos: .default, flags: [], handler: self.stop)
      sigIntSource.resume()
    #endif

    switch runLoopType {
    case .dispatch:
      dispatchMain()
    #if os(macOS)
      case .cocoa:
        MainActor.assumeIsolated {
          NSApplication.shared.setActivationPolicy(.accessory)
          NSApplication.shared.run()
        }
    #endif
    }
  }

  #if os(Windows)
    private var savedConsoleMode: DWORD = 0
  #endif

  private func setInputMode() {
    #if os(Windows)
      let hStdIn = GetStdHandle(STD_INPUT_HANDLE)
      GetConsoleMode(hStdIn, &savedConsoleMode)
      var mode = savedConsoleMode
      mode &= ~DWORD(ENABLE_ECHO_INPUT | ENABLE_LINE_INPUT)
      SetConsoleMode(hStdIn, mode)
    #else
      var tattr = termios()
      tcgetattr(STDIN_FILENO, &tattr)
      tattr.c_lflag &= ~tcflag_t(ECHO | ICANON)
      tcsetattr(STDIN_FILENO, TCSAFLUSH, &tattr)
    #endif
  }

  private func handleInput() {
    let data = FileHandle.standardInput.availableData

    guard let string = String(data: data, encoding: .utf8) else {
      return
    }

    let characters = Array(string)
    var index = 0

    while index < characters.count {
      let char = characters[index]

      if char == ASCII.ESC {
        if index + 2 < characters.count,
          characters[index + 1] == "[",
          let arrowKey = arrowKey(for: characters[index + 2])
        {
          moveFocus(for: arrowKey)
          index += 3
          continue
        }

        _ = performBackAction()
        index += 1
        continue
      }

      if char == ASCII.EOT {
        stop()
        return
      }

      window.firstResponder?.handleEvent(char)
      index += 1
    }
  }

  private func arrowKey(for character: Character) -> ArrowKeyParser.ArrowKey? {
    switch character {
    case "A": return .up
    case "B": return .down
    case "C": return .right
    case "D": return .left
    default: return nil
    }
  }

  private func moveFocus(for key: ArrowKeyParser.ArrowKey) {
    let nextResponder: Control?
    if let current = window.firstResponder {
      switch key {
      case .down:
        nextResponder = current.selectableElement(below: 0)
      case .up:
        nextResponder = current.selectableElement(above: 0)
      case .right:
        nextResponder = current.selectableElement(rightOf: 0)
      case .left:
        nextResponder = current.selectableElement(leftOf: 0)
      }
    } else {
      nextResponder = control.firstSelectableElement
    }

    guard let nextResponder else { return }

    window.firstResponder?.resignFirstResponder()
    window.firstResponder = nextResponder
    window.firstResponder?.becomeFirstResponder()
  }

  private func performBackAction() -> Bool {
    if window.firstResponder?.performBackAction() == true {
      return true
    }
    // When firstResponder is nil (e.g. text-only detail page), find any
    // selectable element and walk up from there to reach the back handler.
    if window.firstResponder == nil,
      let selectable = control.firstSelectableElement,
      selectable.performBackAction()
    {
      return true
    }
    return control.performBackAction()
  }

  func invalidateNode(_ node: Node) {
    invalidatedNodes.append(node)
    scheduleUpdate()
  }

  func scheduleUpdate() {
    if !updateScheduled {
      updateQueue.async { [weak self] in
        self?.update()
      }
      updateScheduled = true
    }
  }

  private func update() {
    updateScheduled = false

    for node in invalidatedNodes {
      node.update(using: node.view)
    }
    invalidatedNodes = []

    // After tree updates, the firstResponder may point to a control that was
    // removed from the tree (stale). Detect this and pick a new one to avoid
    // crashes when the stale control's closures reference deallocated nodes.
    if let fr = window.firstResponder, fr.root !== control {
      fr.resignFirstResponder()
      window.firstResponder = nil
    }
    if window.firstResponder == nil {
      window.firstResponder = control.firstDefaultFocusElement
      window.firstResponder?.becomeFirstResponder()
    }

    control.layout(size: window.layer.frame.size)
    renderer.update()
  }

  private func handleWindowSizeChange() {
    updateWindowSize()
    control.layer.invalidate()
    update()
  }

  private func updateWindowSize() {
    #if os(Windows)
      var csbi = CONSOLE_SCREEN_BUFFER_INFO()
      let hStdOut = GetStdHandle(STD_OUTPUT_HANDLE)
      guard GetConsoleScreenBufferInfo(hStdOut, &csbi) else {
        assertionFailure("Could not get window size")
        return
      }
      let cols = Int(csbi.srWindow.Right - csbi.srWindow.Left + 1)
      let rows = Int(csbi.srWindow.Bottom - csbi.srWindow.Top + 1)
      guard cols > 0, rows > 0 else {
        assertionFailure("Could not get window size")
        return
      }
      window.layer.frame.size = Size(
        width: Extended(cols), height: Extended(rows))
    #else
      var size = winsize()
      guard ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &size) == 0,
        size.ws_col > 0, size.ws_row > 0
      else {
        assertionFailure("Could not get window size")
        return
      }
      window.layer.frame.size = Size(
        width: Extended(Int(size.ws_col)), height: Extended(Int(size.ws_row)))
    #endif
    renderer.setCache()
  }

  private func stop() {
    renderer.stop()
    resetInputMode()  // Fix for: https://github.com/rensbreur/SwiftTUI/issues/25
    exit(0)
  }

  /// Fix for: https://github.com/rensbreur/SwiftTUI/issues/25
  private func resetInputMode() {
    #if os(Windows)
      let hStdIn = GetStdHandle(STD_INPUT_HANDLE)
      SetConsoleMode(hStdIn, savedConsoleMode)
    #else
      var tattr = termios()
      tcgetattr(STDIN_FILENO, &tattr)
      tattr.c_lflag |= tcflag_t(ECHO | ICANON)
      tcsetattr(STDIN_FILENO, TCSAFLUSH, &tattr)
    #endif
  }

}
