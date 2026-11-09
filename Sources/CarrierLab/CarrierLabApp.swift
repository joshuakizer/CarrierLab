import SwiftUI

@main
public struct CarrierLabApp: App {
    public init() {}
    
    public var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
        }
    }
}
