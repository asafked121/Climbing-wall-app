import XCTest
@testable import ClimbingWallApp

@MainActor
final class LoginViewModelTests: XCTestCase {
    
    var viewModel: LoginViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = LoginViewModel()
        viewModel.isRegistering = true
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Email Validation Tests
    
    func testEmailValidation_withValidEmail_returnsTrue() {
        // Arrange
        viewModel.email = "test@example.com"
        
        // Act
        let isValid = viewModel.isEmailValid
        
        // Assert
        XCTAssertTrue(isValid, "Normal case: Valid email should return true")
    }
    
    func testEmailValidation_withShortestValidEmail_returnsTrue() {
        // Arrange
        viewModel.email = "a@b.co"
        
        // Act
        let isValid = viewModel.isEmailValid
        
        // Assert
        XCTAssertTrue(isValid, "Edge case: Exceedingly short valid email should return true")
    }
    
    func testEmailValidation_withEmptyEmail_returnsFalse() {
        // Arrange
        viewModel.email = ""
        
        // Act
        let isValid = viewModel.isEmailValid
        
        // Assert
        XCTAssertFalse(isValid, "Edge case: Empty string should fail email validation")
    }
    
    func testEmailValidation_withInvalidFormatEmails_returnsFalse() {
        let invalidEmails = [
            "testexample.com", // Missing @
            "test@.com", // Missing domain name
            "@example.com", // Missing local part
            "test@example", // Missing TLD
            "test@ex ample.com" // Contains space
        ]
        
        for email in invalidEmails {
            // Arrange
            viewModel.email = email
            
            // Act
            let isValid = viewModel.isEmailValid
            
            // Assert
            XCTAssertFalse(isValid, "Extraordinary case: Invalid email format \(email) should return false")
        }
    }
    
    // MARK: - Password Validation Tests
    
    func testPasswordValidation_withValidStrongPassword_returnsNilMessageAndTrueValid() {
        // Arrange
        viewModel.password = "StrongPass1"
        
        // Act
        let message = viewModel.passwordValidationMessage
        let isValid = viewModel.isPasswordValid
        
        // Assert
        XCTAssertNil(message, "Normal case: Strong password should not produce a validation message")
        XCTAssertTrue(isValid, "Normal case: Strong password should be valid")
    }
    
    func testPasswordValidation_withEmptyPassword_returnsNilMessageButFalseValid() {
        // Arrange
        viewModel.password = ""
        
        // Act
        let message = viewModel.passwordValidationMessage
        let isValid = viewModel.isPasswordValid
        
        // Assert
        XCTAssertNil(message, "Edge case: Empty password should not produce a message immediately (to avoid initial error state)")
        XCTAssertFalse(isValid, "Edge case: Empty password should be invalid")
    }
    
    func testPasswordValidation_withLessThen8Characters_returnsError() {
        // Arrange
        viewModel.password = "Srt1"
        
        // Act
        let message = viewModel.passwordValidationMessage
        let isValid = viewModel.isPasswordValid
        
        // Assert
        XCTAssertEqual(message, "Password must be at least 8 characters long.")
        XCTAssertFalse(isValid)
    }
    
    func testPasswordValidation_withExact8Characters_returnsNilMessageAndTrueValid() {
        // Arrange
        viewModel.password = "SrtPass1" // 8 chars exactly, 1 num, 1 uppercase
        
        // Act
        let message = viewModel.passwordValidationMessage
        let isValid = viewModel.isPasswordValid
        
        // Assert
        XCTAssertNil(message, "Edge case: Exact 8 character password should be valid")
        XCTAssertTrue(isValid)
    }
    
    func testPasswordValidation_withoutUppercase_returnsError() {
        // Arrange
        viewModel.password = "lowercase1"
        
        // Act
        let message = viewModel.passwordValidationMessage
        let isValid = viewModel.isPasswordValid
        
        // Assert
        XCTAssertEqual(message, "Password must contain at least one uppercase letter.")
        XCTAssertFalse(isValid)
    }
    
    func testPasswordValidation_withoutNumber_returnsError() {
        // Arrange
        viewModel.password = "NoNumbersHere"
        
        // Act
        let message = viewModel.passwordValidationMessage
        let isValid = viewModel.isPasswordValid
        
        // Assert
        XCTAssertEqual(message, "Password must contain at least one number.")
        XCTAssertFalse(isValid)
    }
    
    func testPasswordValidation_withMassiveAnomalousString_returnsValid() {
        // Arrange
        // Generating a 10,000 character long string
        let base = "ValidPass1"
        viewModel.password = String(repeating: base, count: 1000)
        
        // Act
        let message = viewModel.passwordValidationMessage
        let isValid = viewModel.isPasswordValid
        
        // Assert
        XCTAssertNil(message, "Extraordinary case: Massive valid password should not crash and return valid")
        XCTAssertTrue(isValid)
    }
    
    // MARK: - Age Gate Tests
    
    func testAgeGate_Normal_Over13_Passes() {
        // Arrange
        let currentYear = Calendar.current.component(.year, from: Date())
        viewModel.birthYear = currentYear - 20
        viewModel.birthMonth = 1
        
        // Act
        viewModel.checkAgeGate()
        
        // Assert
        XCTAssertTrue(viewModel.isAgeGatePassed)
        XCTAssertFalse(viewModel.isAgeBlocked)
    }
    
    func testAgeGate_Normal_Under13_Blocks() {
        // Arrange
        let currentYear = Calendar.current.component(.year, from: Date())
        viewModel.birthYear = currentYear - 10
        viewModel.birthMonth = 1
        
        // Act
        viewModel.checkAgeGate()
        
        // Assert
        XCTAssertFalse(viewModel.isAgeGatePassed)
        XCTAssertTrue(viewModel.isAgeBlocked)
    }
    
    func testAgeGate_Edge_Exactly13Today_Passes() {
        // Arrange
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        
        viewModel.birthYear = currentYear - 13
        viewModel.birthMonth = currentMonth
        
        // Act
        viewModel.checkAgeGate()
        
        // Assert
        XCTAssertTrue(viewModel.isAgeGatePassed)
        XCTAssertFalse(viewModel.isAgeBlocked)
    }
    
    func testAgeGate_Edge_Almost13NextMonth_Blocks() {
        // Arrange
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        
        // If they are born 13 years ago, but NEXT month, they are technically only 12.
        // E.g., Today is March 2026. They were born April 2013. They are 12.
        
        if currentMonth < 12 {
            viewModel.birthYear = currentYear - 13
            viewModel.birthMonth = currentMonth + 1
            
            // Act
            viewModel.checkAgeGate()
            
            // Assert
            XCTAssertFalse(viewModel.isAgeGatePassed)
            XCTAssertTrue(viewModel.isAgeBlocked)
        }
    }
    
    func testAgeGate_Extraordinary_FutureDate_Blocks() {
        // Arrange
        let currentYear = Calendar.current.component(.year, from: Date())
        viewModel.birthYear = currentYear + 10
        viewModel.birthMonth = 1
        
        // Act
        viewModel.checkAgeGate()
        
        // Assert
        XCTAssertFalse(viewModel.isAgeGatePassed)
        XCTAssertTrue(viewModel.isAgeBlocked)
    }
}
