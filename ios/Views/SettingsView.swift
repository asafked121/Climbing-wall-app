import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var loginViewModel: LoginViewModel
    @State private var editedUsername: String = ""
    @State private var showAlert = false
    
    @State private var userAscents: [Ascent] = []
    @State private var isLoadingAscents = false
    
    var body: some View {
        NavigationView {
            List {
                if !loginViewModel.isGuest {
                    Section(header: Text("Account")) {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(loginViewModel.currentUser?.email ?? "Unknown")
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Username")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                TextField("Username", text: $editedUsername)
                                    .textFieldStyle(.roundedBorder)
                                    .autocapitalization(.none)
                                    .textContentType(.username)
                                
                                if editedUsername != loginViewModel.currentUser?.username && !editedUsername.isEmpty {
                                    Button("Save") {
                                        Task {
                                            await loginViewModel.updateUsername(editedUsername)
                                            showAlert = true
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(loginViewModel.isLoading)
                                }
                            }
                        }
                    }
                    
                    Section(header: Text("Climbing Stats")) {
                        if isLoadingAscents {
                            ProgressView("Loading stats...")
                        } else {
                            HStack {
                                VStack {
                                    Text("\(userAscents.filter({ $0.ascentType == "boulder" }).count)")
                                        .font(.title2).bold().foregroundColor(.blue)
                                    Text("Boulders").font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                VStack {
                                    Text("\(userAscents.filter({ $0.ascentType == "top_rope" }).count)")
                                        .font(.title2).bold().foregroundColor(.blue)
                                    Text("Top Ropes").font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                VStack {
                                    Text("\(userAscents.filter({ $0.ascentType == "lead" }).count)")
                                        .font(.title2).bold().foregroundColor(.blue)
                                    Text("Leads").font(.caption).foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                Section(header: Text("App Information")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
                
                if loginViewModel.currentUser?.role == "admin" || loginViewModel.currentUser?.role == "super_admin" {
                    Section(header: Text("Administration")) {
                        NavigationLink(destination: AdminDashboardView().environmentObject(loginViewModel)) {
                            Label("Admin Dashboard", systemImage: "gearshape.2.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Section {
                    if loginViewModel.isGuest {
                        Button(action: {
                            loginViewModel.logout() // effectively resets the guest state
                        }) {
                            Text("Log In or Sign Up")
                                .foregroundColor(.blue)
                        }
                    } else {
                        Button(action: {
                            loginViewModel.logout()
                        }) {
                            Text("Log Out")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                if let user = loginViewModel.currentUser {
                    editedUsername = user.username
                }
            }
            .task {
                if let user = loginViewModel.currentUser, !loginViewModel.isGuest {
                    isLoadingAscents = true
                    do {
                        userAscents = try await NetworkManager.shared.fetchUserAscents(userId: user.id)
                    } catch {
                        print("Failed to fetch ascents: \(error)")
                    }
                    isLoadingAscents = false
                }
            }
            .onChange(of: loginViewModel.currentUser?.username) { newUsername in
                if let newName = newUsername {
                    editedUsername = newName
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Settings Update"),
                    message: Text(loginViewModel.errorMessage ?? "An error occurred."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(LoginViewModel())
    }
}
