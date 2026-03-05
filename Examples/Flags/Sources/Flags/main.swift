import SwiftTUI

await MainActor.run {
    Application(rootView: ContentView()).start()
}
