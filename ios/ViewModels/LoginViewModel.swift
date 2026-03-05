import Foundation
import Combine

@MainActor
class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var username = ""
    @Published var password = ""
    
    @Published var isRegistering = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Age Gate state
    @Published var birthMonth: Int = Calendar.current.component(.month, from: Date())
    @Published var birthYear: Int = Calendar.current.component(.year, from: Date())
    @Published var isAgeGatePassed = false
    @Published var isAgeBlocked = false
    @Published var acceptedTos = false
    
    @Published var acceptedGuestTos = false
    
    // We can publish an auth state to trigger app navigation
    @Published var isAuthenticated = false
    @Published var isCheckingAuth = true
    @Published var currentUser: User?
    @Published var isGuest = false
    
    init() {
        if UserDefaults.standard.bool(forKey: "age_gate_failed") {
            self.isAgeBlocked = true
        }
    }
    
    func checkAgeGate() {
        if isAgeBlocked {
            return
        }
        
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        
        var age = currentYear - birthYear
        if birthMonth > currentMonth {
            age -= 1
        }
        
        if age >= 13 {
            isAgeGatePassed = true
            errorMessage = nil
        } else {
            isAgeBlocked = true
            UserDefaults.standard.set(true, forKey: "age_gate_failed")
            errorMessage = nil
        }
    }
    
    // Validation
    var isEmailValid: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    var passwordValidationMessage: String? {
        if password.isEmpty {
            return nil
        }
        if password.count < 8 {
            return "Password must be at least 8 characters long."
        }
        if password.rangeOfCharacter(from: .uppercaseLetters) == nil {
            return "Password must contain at least one uppercase letter."
        }
        if password.rangeOfCharacter(from: .decimalDigits) == nil {
            return "Password must contain at least one number."
        }
        return nil
    }
    
    var isPasswordValid: Bool {
        return passwordValidationMessage == nil && !password.isEmpty
    }
    
    var isFormValid: Bool {
        if isRegistering {
            return isEmailValid && isPasswordValid && acceptedTos && isAgeGatePassed
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }
    
    func checkAuthStatus() async {
        isCheckingAuth = true
        do {
            let user = try await NetworkManager.shared.fetchCurrentUser()
            self.currentUser = user
            self.isAuthenticated = true
        } catch {
            self.isAuthenticated = false
            self.currentUser = nil
        }
        isCheckingAuth = false
    }
    
    func authenticate() async {
        guard isFormValid else {
            errorMessage = "Please ensure all fields are valid."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            if isRegistering {
                let dobString = String(format: "%04d-%02d-01", birthYear, birthMonth)
                try await NetworkManager.shared.register(email: email, username: username, password: password, dateOfBirth: dobString)
            } else {
                try await NetworkManager.shared.login(email: email, password: password)
            }
            await fetchCurrentUser()
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func fetchCurrentUser() async {
        do {
            let user = try await NetworkManager.shared.fetchCurrentUser()
            self.currentUser = user
        } catch {
            print("Failed to fetch current user: \(error)")
        }
    }
    
    func updateUsername(_ newUsername: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let updatedUser = try await NetworkManager.shared.updateUsername(username: newUsername)
            self.currentUser = updatedUser
            self.errorMessage = "Username updated successfully!"
        } catch let error as NSError {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func logout() {
        NetworkManager.shared.logout()
        isAuthenticated = false
        isGuest = false
        currentUser = nil
        email = ""
        password = ""
        username = ""
    }
    
    func continueAsGuest() {
        if !acceptedGuestTos {
            errorMessage = "You must accept the Terms of Service to continue as a guest."
            return
        }
        isGuest = true
        isAuthenticated = true
        currentUser = nil
        errorMessage = nil
    }
}
