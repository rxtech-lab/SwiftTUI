import Foundation

#if os(macOS)
  import AppKit
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

    let sigWinChSource = DispatchSource.makeSignalSource(signal: SIGWINCH, queue: .main)
    sigWinChSource.setEventHandler(qos: .default, flags: [], handler: self.handleWindowSizeChange)
    sigWinChSource.resume()

    signal(SIGINT, SIG_IGN)
    let sigIntSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    sigIntSource.setEventHandler(qos: .default, flags: [], handler: self.stop)
    sigIntSource.resume()

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

  private func setInputMode() {
    var tattr = termios()
    tcgetattr(STDIN_FILENO, &tattr)
    tattr.c_lflag &= ~tcflag_t(ECHO | ICANON)
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &tattr)
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
    switch key {
    case .down:
      nextResponder = window.firstResponder?.selectableElement(below: 0)
    case .up:
      nextResponder = window.firstResponder?.selectableElement(above: 0)
    case .right:
      nextResponder = window.firstResponder?.selectableElement(rightOf: 0)
    case .left:
      nextResponder = window.firstResponder?.selectableElement(leftOf: 0)
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

    control.layout(size: window.layer.frame.size)
    renderer.update()
  }

  private func handleWindowSizeChange() {
    updateWindowSize()
    control.layer.invalidate()
    update()
  }

  private func updateWindowSize() {
    var size = winsize()
    guard ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &size) == 0,
      size.ws_col > 0, size.ws_row > 0
    else {
      assertionFailure("Could not get window size")
      return
    }
    window.layer.frame.size = Size(
      width: Extended(Int(size.ws_col)), height: Extended(Int(size.ws_row)))
    renderer.setCache()
  }

  private func stop() {
    renderer.stop()
    resetInputMode()  // Fix for: https://github.com/rensbreur/SwiftTUI/issues/25
    exit(0)
  }

  /// Fix for: https://github.com/rensbreur/SwiftTUI/issues/25
  private func resetInputMode() {
    // Reset ECHO and ICANON values:
    var tattr = termios()
    tcgetattr(STDIN_FILENO, &tattr)
    tattr.c_lflag |= tcflag_t(ECHO | ICANON)
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &tattr)
  }

}
