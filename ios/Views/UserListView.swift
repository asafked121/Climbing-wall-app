import SwiftUI

struct UserListView: View {
    @EnvironmentObject var loginViewModel: LoginViewModel
    @StateObject private var adminViewModel = AdminViewModel()
    
    @State private var searchText = ""
    @State private var selectedRole: String? = nil
    @State private var selectedBanFilter: BanFilter = .all
    
    enum BanFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case banned = "Banned"
    }
    
    struct RoleFilter: Identifiable {
        let label: String
        let value: String?
        var id: String { label }
    }
    
    private let roleFilters: [RoleFilter] = [
        RoleFilter(label: "All", value: nil),
        RoleFilter(label: "Student", value: "student"),
        RoleFilter(label: "Setter", value: "setter"),
        RoleFilter(label: "Admin", value: "admin"),
    ]
    
    private var filteredUsers: [User] {
        adminViewModel.users.filter { user in
            let matchesSearch = searchText.isEmpty
                || user.username.localizedCaseInsensitiveContains(searchText)
                || user.email.localizedCaseInsensitiveContains(searchText)
            
            let matchesRole: Bool = {
                guard let role = selectedRole else { return true }
                return user.role == role
            }()
            
            let matchesBan: Bool = {
                switch selectedBanFilter {
                case .all: return true
                case .active: return !user.isBanned
                case .banned: return user.isBanned
                }
            }()
            
            return matchesSearch && matchesRole && matchesBan
        }
    }
    
    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search users...", text: $searchText)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            
            filterSection
            
            Section(header: Text("\(filteredUsers.count) Users")) {
                ForEach(filteredUsers) { user in
                    UserRowView(
                        user: user,
                        currentUser: loginViewModel.currentUser,
                        onRoleChange: { newRole in
                            updateRole(user, newRole)
                        },
                        onToggleBan: {
                            Task {
                                await adminViewModel.toggleBanStatus(for: user)
                            }
                        },
                        onDelete: {
                            Task {
                                await adminViewModel.deleteUser(userId: user.id)
                            }
                        }
                    )
                }
            }
        }
        .navigationTitle("Users")
        .refreshable {
            await adminViewModel.fetchUsers()
        }
        .onAppear {
            Task {
                await adminViewModel.fetchUsers()
            }
        }
        .overlay {
            if adminViewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.1)
                    ProgressView()
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 4)
                }
                .ignoresSafeArea()
            }
        }
        .alert("Error", isPresented: Binding(
            get: { adminViewModel.errorMessage != nil },
            set: { _ in adminViewModel.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = adminViewModel.errorMessage {
                Text(error)
            }
        }
    }
    
    private var filterSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Role")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(roleFilters, id: \.label) { filter in
                            FilterChip(
                                label: filter.label,
                                isSelected: selectedRole == filter.value,
                                action: { selectedRole = filter.value }
                            )
                        }
                    }
                }
                
                Text("Status")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(BanFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                label: filter.rawValue,
                                isSelected: selectedBanFilter == filter,
                                action: { selectedBanFilter = filter }
                            )
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private func updateRole(_ user: User, _ role: String) {
        guard user.role != role else { return }
        Task {
            await adminViewModel.updateUserRole(userId: user.id, newRole: role)
        }
    }
}

// MARK: - User Row Subview

struct UserRowView: View {
    let user: User
    let currentUser: User?
    let onRoleChange: (String) -> Void
    let onToggleBan: () -> Void
    let onDelete: () -> Void
    @State private var showConfirmation = false
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(user.username)
                    .font(.headline)
                    .strikethrough(user.isBanned, color: .red)
                
                Spacer()
                
                Text(user.role.capitalized)
                    .font(.caption2)
                    .padding(3)
                    .background(roleColor(user.role))
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            
            Text(user.email)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                if canChangeRole {
                    Menu {
                        Button("Student") { onRoleChange("student") }
                        Button("Setter") { onRoleChange("setter") }
                        if currentUser?.role == "super_admin" {
                            Button("Admin") { onRoleChange("admin") }
                        }
                    } label: {
                        Text("Change Role")
                            .font(.system(size: 10))
                            .padding(4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.borderless)
                }
                
                Spacer()
                
                if canBan {
                    Button(action: {
                        if !user.isBanned {
                            showConfirmation = true
                        } else {
                            onToggleBan()
                        }
                    }) {
                        Text(user.isBanned ? "Unban" : "Ban")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(user.isBanned ? .green : .red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((user.isBanned ? Color.green : Color.red).opacity(0.1))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.borderless)
                }
                
                if canDelete {
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Text("Delete")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.vertical, 4)
        .alert("Ban User?", isPresented: $showConfirmation) {
            Button("Ban \(user.username)", role: .destructive) {
                onToggleBan()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to ban this user? They will no longer be able to log in.")
        }
        .alert("Delete User?", isPresented: $showDeleteConfirmation) {
            Button("Delete \(user.username)", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to completely delete this user? This action cannot be undone.")
        }
    }
    
    private var canChangeRole: Bool {
        currentUser?.role == "super_admin"
            || (currentUser?.role == "admin" && user.role != "super_admin" && user.role != "admin")
    }
    
    private var canBan: Bool {
        guard user.role != "super_admin", user.id != currentUser?.id else { return false }
        if currentUser?.role == "admin" && user.role == "admin" { return false }
        return true
    }
    
    private var canDelete: Bool {
        guard user.id != currentUser?.id else { return false }
        return currentUser?.role == "super_admin"
    }
    
    private func roleColor(_ role: String) -> Color {
        switch role {
        case "super_admin": return .purple
        case "admin": return .red
        case "setter": return .blue
        default: return .gray
        }
    }
}

