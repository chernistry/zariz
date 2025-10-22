import SwiftUI

struct StoreTabView: View {
    var body: some View {
        TabView {
            NavigationStack { StoreHomeView() }
                .globalNavToolbar()
                .tabItem { Label("store_tab_home", systemImage: "square.and.pencil") }

            NavigationStack { StoreOrdersListView() }
                .globalNavToolbar()
                .tabItem { Label("store_tab_orders", systemImage: "tray.full") }

            NavigationStack { ProfileView() }
                .globalNavToolbar()
                .tabItem { Label("profile", systemImage: "person.crop.circle") }
        }
    }
}
