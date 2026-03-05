import Foundation

public struct NavigationPath {
  var elements: [AnyHashable] = []

  public init() {}

  public init(_ elements: some Sequence<some Hashable>) {
    self.elements = elements.map { AnyHashable($0) }
  }

  public var count: Int { elements.count }
  public var isEmpty: Bool { elements.isEmpty }

  public mutating func append(_ value: some Hashable) {
    elements.append(AnyHashable(value))
  }

  public mutating func removeLast(_ k: Int = 1) {
    guard k <= elements.count else { return }
    elements.removeLast(k)
  }
}
