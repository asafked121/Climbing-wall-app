import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case routes = "Routes"
    case community = "Community"
    case settings = "Settings"
    case analytics = "Analytics"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .routes:
            return "map.fill" // Map or list icon
        case .community:
            return "globe.americas.fill"
        case .settings:
            return "gearshape.fill"
        case .analytics:
            return "chart.bar.fill"
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .routes
    @EnvironmentObject var loginViewModel: LoginViewModel
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ActiveRoutesFeedView()
                .tabItem {
                    Label(AppTab.routes.rawValue, systemImage: AppTab.routes.iconName)
                }
                .tag(AppTab.routes)
                
            NavigationView {
                CustomRouteListView()
            }
            .tabItem {
                Label(AppTab.community.rawValue, systemImage: AppTab.community.iconName)
            }
            .tag(AppTab.community)
                
            if loginViewModel.currentUser?.role == "admin" || loginViewModel.currentUser?.role == "super_admin" {
                NavigationView {
                    AnalyticsView()
                }
                .tabItem {
                    Label(AppTab.analytics.rawValue, systemImage: AppTab.analytics.iconName)
                }
                .tag(AppTab.analytics)
            }
            
            SettingsView()
                .tabItem {
                    Label(AppTab.settings.rawValue, systemImage: AppTab.settings.iconName)
                }
                .tag(AppTab.settings)
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(LoginViewModel())
    }
}
