import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem { Label("خانه", systemImage: "house.fill") }
                .tag(0)

            ChatView()
                .tabItem { Label("گفت‌وگو", systemImage: "bubble.left.and.bubble.right") }
                .tag(1)

            NotesView()
                .tabItem { Label("یادداشت‌ها", systemImage: "square.and.pencil") }
                .tag(2)

            RemindersView()
                .tabItem { Label("یادآورها", systemImage: "calendar") }
                .tag(3)

            SettingsView()
                .tabItem { Label("تنظیمات", systemImage: "gearshape") }
                .tag(4)
        }
        .tint(NAVATheme.orange)
        .toolbarBackground(NAVATheme.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
