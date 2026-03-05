import Foundation

extension View {
  public func task(
    priority: TaskPriority = .userInitiated, _ action: @escaping @Sendable () async -> Void
  ) -> some View {
    TaskModifier(content: self, priority: priority, action: action)
  }

  public func task<T: Equatable>(
    id value: T, priority: TaskPriority = .userInitiated,
    _ action: @escaping @Sendable () async -> Void
  ) -> some View {
    TaskIDModifier(content: self, id: value, priority: priority, action: action)
  }
}

private struct TaskModifier<Content: View>: View, PrimitiveView, ModifierView {
  let content: Content
  let priority: TaskPriority
  let action: @Sendable () async -> Void

  static var size: Int? { Content.size }

  func buildNode(_ node: Node) {
    node.controls = WeakSet<Control>()
    node.addNode(at: 0, Node(view: content.view))
  }

  func updateNode(_ node: Node) {
    node.view = self
    node.children[0].update(using: content.view)
    for control in node.controls?.values ?? [] {
      let control = control as! TaskControl
      control.priority = priority
      control.action = action
    }
  }

  func passControl(_ control: Control, node: Node) -> Control {
    if let taskControl = control.parent { return taskControl }
    let taskControl = TaskControl(priority: priority, action: action)
    taskControl.addSubview(control, at: 0)
    node.controls?.add(taskControl)
    return taskControl
  }
}

private struct TaskIDModifier<Content: View, ID: Equatable>: View, PrimitiveView, ModifierView {
  let content: Content
  let id: ID
  let priority: TaskPriority
  let action: @Sendable () async -> Void

  static var size: Int? { Content.size }

  func buildNode(_ node: Node) {
    node.controls = WeakSet<Control>()
    node.addNode(at: 0, Node(view: content.view))
  }

  func updateNode(_ node: Node) {
    node.view = self
    node.children[0].update(using: content.view)
    for control in node.controls?.values ?? [] {
      let control = control as! TaskIDControl<ID>
      control.priority = priority
      control.action = action
      control.updateID(id)
    }
  }

  func passControl(_ control: Control, node: Node) -> Control {
    if let taskControl = control.parent { return taskControl }
    let taskControl = TaskIDControl(id: id, priority: priority, action: action)
    taskControl.addSubview(control, at: 0)
    node.controls?.add(taskControl)
    return taskControl
  }
}

private class TaskControl: Control {
  var priority: TaskPriority
  var action: @Sendable () async -> Void

  fileprivate var didAppear = false
  private var runningTask: Task<Void, Never>?

  init(priority: TaskPriority, action: @escaping @Sendable () async -> Void) {
    self.priority = priority
    self.action = action
  }

  deinit {
    runningTask?.cancel()
  }

  override func size(proposedSize: Size) -> Size {
    children[0].size(proposedSize: proposedSize)
  }

  override func layout(size: Size) {
    super.layout(size: size)
    children[0].layout(size: size)
    if !didAppear {
      didAppear = true
      startTask()
    }
  }

  override func didRemoveFromHierarchy() {
    runningTask?.cancel()
    super.didRemoveFromHierarchy()
  }

  fileprivate func restartTask() {
    guard didAppear else { return }
    runningTask?.cancel()
    startTask()
  }

  private func startTask() {
    runningTask = Task(priority: priority) { [action] in
      await action()
    }
  }
}

private final class TaskIDControl<ID: Equatable>: TaskControl {
  private var id: ID

  init(id: ID, priority: TaskPriority, action: @escaping @Sendable () async -> Void) {
    self.id = id
    super.init(priority: priority, action: action)
  }

  func updateID(_ id: ID) {
    guard self.id != id else { return }
    self.id = id
    restartTask()
  }
}
