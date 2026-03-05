import SwiftUI

struct AdminDashboardView: View {
    @EnvironmentObject var loginViewModel: LoginViewModel
    
    var body: some View {
        List {
            Section(header: Text("Management")) {
                NavigationLink {
                    UserListView()
                        .environmentObject(loginViewModel)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Manage Users")
                                .font(.body)
                            Text("Search, filter by role & status")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "person.3.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                NavigationLink {
                    SetterListView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Manage Setters")
                                .font(.body)
                            Text("Search, filter by active status")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundColor(.orange)
                    }
                }
                
                NavigationLink {
                    ColorListView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Manage Colors")
                                .font(.body)
                            Text("Add or remove hold colors")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "paintpalette.fill")
                            .foregroundColor(.purple)
                    }
                }
            }

            if loginViewModel.currentUser?.role == "super_admin" {
                Section(header: Text("Insights")) {
                    NavigationLink {
                        AnalyticsView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Wall Analytics")
                                    .font(.body)
                                Text("Charts, trends & climbing insights")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "chart.bar.xaxis.ascending")
                                .foregroundColor(.indigo)
                        }
                    }
                    
                    NavigationLink {
                        BulkUploadRoutesView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Bulk Import Routes")
                                    .font(.body)
                                Text("Upload multiple routes via Excel (.xlsx)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "arrow.up.doc.fill")
                                .foregroundColor(.teal)
                        }
                    }
                }
            }
        }
        .navigationTitle("Admin Dashboard")
    }
}

struct AdminDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AdminDashboardView()
                .environmentObject(LoginViewModel())
        }
    }
}
