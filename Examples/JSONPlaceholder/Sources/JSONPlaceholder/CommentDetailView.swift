import SwiftTUI

struct CommentDetailView: View {
  let comment: Comment

  var body: some View {
    VStack(alignment: .leading) {
      Text(comment.name).bold()
      Text("")
      Text("From: \(comment.email)").foregroundColor(.cyan)
      Divider()
      Text(comment.body)
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Text("Comment #\(comment.id)")
      }
    }
  }
}
