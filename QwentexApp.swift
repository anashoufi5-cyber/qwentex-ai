import SwiftUI

@main
struct QwentexApp: App {
    @StateObject private var chat = ChatStore()
    var body: some Scene {
        WindowGroup { ChatView().environmentObject(chat).preferredColorScheme(.dark) }
    }
}
