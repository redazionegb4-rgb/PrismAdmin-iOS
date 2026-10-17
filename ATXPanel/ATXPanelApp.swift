import SwiftUI

@main struct ATXPanelApp: App {
    @StateObject private var api = ATXAPI()
    var body: some Scene { WindowGroup { RootView().environmentObject(api).tint(.cyan) } }
}
