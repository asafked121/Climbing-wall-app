import Foundation
import Combine
import SwiftUI

@MainActor
class AdminViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var setters: [Setter] = []
    @Published var colors: [RouteColor] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchQuery: String = ""
    
    // Computed property for filtered users based on search query
    var filteredUsers: [User] {
        if searchQuery.isEmpty {
            return users
        } else {
            let lowercasedQuery = searchQuery.lowercased()
            return users.filter { 
                $0.username.lowercased().contains(lowercasedQuery) || 
                $0.email.lowercased().contains(lowercasedQuery) 
            }
        }
    }
    
    // MARK: - Users
    
    func fetchUsers() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetchedUsers = try await NetworkManager.shared.fetchUsers(role: nil)
            self.users = fetchedUsers.sorted { $0.username < $1.username }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func updateUserRole(userId: Int, newRole: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let updatedUser = try await NetworkManager.shared.updateUserRole(userId: userId, role: newRole)
            if let index = users.firstIndex(where: { $0.id == updatedUser.id }) {
                users[index] = updatedUser
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func toggleBanStatus(for user: User) async {
        isLoading = true
        errorMessage = nil
        do {
            let updatedUser = try await NetworkManager.shared.updateUserBanStatus(userId: user.id, isBanned: !user.isBanned)
            if let index = users.firstIndex(where: { $0.id == updatedUser.id }) {
                users[index] = updatedUser
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteUser(userId: Int) async {
        isLoading = true
        errorMessage = nil
        do {
            try await NetworkManager.shared.deleteUser(userId: userId)
            users.removeAll { $0.id == userId }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    // MARK: - Setters
    
    func fetchSetters() async {
        isLoading = true
        errorMessage = nil
        do {
            self.setters = try await NetworkManager.shared.fetchSetters()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addSetter(name: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let newSetter = try await NetworkManager.shared.createSetter(name: name)
            self.setters.append(newSetter)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func toggleSetterActiveStatus(for setter: Setter) async {
        isLoading = true
        errorMessage = nil
        do {
            let updatedSetter = try await NetworkManager.shared.updateSetterStatus(
                setterId: setter.id,
                isActive: !setter.isActive
            )
            if let index = setters.firstIndex(where: { $0.id == updatedSetter.id }) {
                setters[index] = updatedSetter
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteSetter(setterId: Int) async {
        isLoading = true
        errorMessage = nil
        do {
            try await NetworkManager.shared.deleteSetter(setterId: setterId)
            setters.removeAll { $0.id == setterId }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    // MARK: - Colors
    
    func fetchColors() async {
        isLoading = true
        errorMessage = nil
        do {
            self.colors = try await NetworkManager.shared.fetchColors()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addColor(name: String, hexValue: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let newColor = try await NetworkManager.shared.createColor(name: name, hexValue: hexValue)
            self.colors.append(newColor)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteColor(colorId: Int) async {
        isLoading = true
        errorMessage = nil
        do {
            try await NetworkManager.shared.deleteColor(colorId: colorId)
            colors.removeAll { $0.id == colorId }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
