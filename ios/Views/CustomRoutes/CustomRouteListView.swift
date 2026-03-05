import SwiftUI

struct CustomRouteListView: View {
    @StateObject private var viewModel = CustomRouteListViewModel()
    @EnvironmentObject var loginViewModel: LoginViewModel
    @State private var showingAddRoute = false
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.routes.isEmpty {
                ProgressView("Loading community routes...")
            } else if let error = viewModel.errorMessage {
                VStack {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                    Button("Retry") {
                        viewModel.fetchRoutes()
                    }
                    .padding()
                }
            } else if viewModel.routes.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "globe.americas")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No community routes yet.")
                        .font(.headline)
                    Text("Be the first to post one!")
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.routes) { route in
                            NavigationLink(destination: CustomRouteDetailView(routeId: route.id)) {
                                CustomRouteRowView(route: route)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Community")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if loginViewModel.currentUser != nil {
                    Button(action: {
                        showingAddRoute = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddRoute) {
            NavigationView {
                CreateCustomRouteView()
            }
        }
        .onAppear {
            viewModel.fetchRoutes()
        }
    }
}

struct CustomRouteRowView: View {
    let route: CustomRoute
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AsyncImage(url: URL(string: "\(Config.apiBaseURL)\(route.photoUrl)")) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(4/3, contentMode: .fit)
                        .overlay(ProgressView())
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(4/3, contentMode: .fill)
                        .clipped()
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(4/3, contentMode: .fit)
                        .overlay(Image(systemName: "photo").foregroundColor(.gray))
                @unknown default:
                    EmptyView()
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(route.name)
                        .font(.headline)
                    Spacer()
                    Text(route.intendedGrade)
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
                
                Text("By \(route.author?.username ?? "Unknown")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
