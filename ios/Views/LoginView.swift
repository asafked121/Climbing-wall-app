import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @State private var showingToS = false
    
    var body: some View {
        if viewModel.isCheckingAuth {
            ProgressView()
                .task {
                    await viewModel.checkAuthStatus()
                }
        } else if viewModel.isAuthenticated {
            MainTabView()
                .environmentObject(viewModel)
        } else {
            VStack(spacing: 20) {
                Text(viewModel.isRegistering ? "Create Account" : "Welcome Back")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if viewModel.isRegistering {
                    if viewModel.isAgeBlocked {
                        VStack(spacing: 16) {
                            Text("Registration Unavailable")
                                .font(.title3)
                                .foregroundColor(.red)
                                .fontWeight(.bold)
                            
                            Text("To protect your privacy, you cannot create an account at this time. Please ask your parent or legal guardian to create an account for you.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .font(.body)
                                .padding(.horizontal)
                        }
                        .padding(.vertical, 40)
                    } else if !viewModel.isAgeGatePassed {
                        VStack(spacing: 16) {
                            Text("When were you born?")
                                .font(.headline)
                            
                            HStack {
                                Picker("Month", selection: $viewModel.birthMonth) {
                                    ForEach(1...12, id: \.self) { month in
                                        Text(DateFormatter().monthSymbols[month - 1]).tag(month)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                                
                                let currentYear = Calendar.current.component(.year, from: Date())
                                Picker("Year", selection: $viewModel.birthYear) {
                                    ForEach((currentYear - 100)...currentYear, id: \.self) { year in
                                        Text(String(year)).tag(year)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                            }
                            
                            Button(action: {
                                viewModel.checkAgeGate()
                            }) {
                                Text("Continue")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                    } else {
                        // Registration Fields
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Username (Optional)", text: $viewModel.username)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .textContentType(.username)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Email", text: $viewModel.email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .textContentType(.username)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.red, lineWidth: (!viewModel.email.isEmpty && !viewModel.isEmailValid) ? 1 : 0)
                                )
                            
                            if !viewModel.email.isEmpty && !viewModel.isEmailValid {
                                Text("Please enter a valid email address.")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            SecureField("Password", text: $viewModel.password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .textContentType(.newPassword)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.red, lineWidth: (!viewModel.password.isEmpty && !viewModel.isPasswordValid) ? 1 : 0)
                                )
                            
                            if let message = viewModel.passwordValidationMessage {
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle(isOn: $viewModel.acceptedTos) {
                                Text("I agree to the Terms of Service and Privacy Policy. I assume all risks of climbing.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            
                            Button(action: { showingToS = true }) {
                                Text("Read Terms of Service")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .underline()
                            }
                            .padding(.leading, 4)
                        }
                        
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        Button(action: {
                            Task {
                                await viewModel.authenticate()
                            }
                        }) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Sign Up")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isLoading || !viewModel.isFormValid ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(viewModel.isLoading || !viewModel.isFormValid)
                    }
                } else {
                    // Login Fields
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Email", text: $viewModel.email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .textContentType(.username)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        SecureField("Password", text: $viewModel.password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.password)
                    }
                    
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button(action: {
                        Task {
                            await viewModel.authenticate()
                        }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Log In")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isLoading || !viewModel.isFormValid ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(viewModel.isLoading || !viewModel.isFormValid)
                }
                
                Button(action: {
                    withAnimation {
                        viewModel.isRegistering.toggle()
                        viewModel.errorMessage = nil
                    }
                }) {
                    Text(viewModel.isRegistering ? "Already have an account? Log In" : "Don't have an account? Sign Up")
                        .font(.footnote)
                        .foregroundColor(.blue)
                }
                
                VStack(spacing: 8) {
                    Divider()
                        .padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: $viewModel.acceptedGuestTos) {
                            Text("I agree to the Terms of Service and assume all risks to continue as a guest.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        
                        Button(action: { showingToS = true }) {
                            Text("Read Terms of Service")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .underline()
                        }
                        .padding(.leading, 4)
                    }
                    
                    Button(action: {
                        viewModel.continueAsGuest()
                    }) {
                        Text("Continue as Guest")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.acceptedGuestTos ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                            .foregroundColor(viewModel.acceptedGuestTos ? .blue : .gray)
                            .cornerRadius(10)
                    }
                    .disabled(!viewModel.acceptedGuestTos)
                }
                .padding(.top, 10)
            }
            .padding()
            .sheet(isPresented: $showingToS) {
                TermsOfServiceView()
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
