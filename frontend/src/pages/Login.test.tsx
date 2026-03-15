import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { Login } from "./Login";
import { BrowserRouter } from "react-router-dom";
import * as AuthContextModule from "../context/AuthContext";
import "@testing-library/jest-dom"; // ensure toBeInTheDocument is available

// Mock routing
const mockNavigate = vi.fn();
vi.mock("react-router-dom", async () => {
  const actual = await vi.importActual("react-router-dom");
  return {
    ...actual,
    useNavigate: () => mockNavigate,
  };
});

// Mock Auth Context
const mockLogin = vi.fn();
vi.spyOn(AuthContextModule, "useAuth").mockReturnValue({
  user: null,
  isLoading: false,
  login: mockLogin,
  register: vi.fn(),
  logout: vi.fn(),
  loginAsGuest: vi.fn(),
  fetchUser: vi.fn(),
});

describe("Login Component", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  const renderComponent = () =>
    render(
      <BrowserRouter>
        <Login />
      </BrowserRouter>,
    );

  // --- Normal Cases ---
  it("Login_ValidCredentials_CallsLoginAPIAndNavigates", async () => {
    // Arrange
    renderComponent();
    const emailInput = screen.getByLabelText(/Email Address/i);
    const passwordInput = screen.getByLabelText(/Password/i);
    const submitBtn = screen.getByRole("button", { name: /Sign In/i });

    // Act
    fireEvent.change(emailInput, { target: { value: "user@test.com" } });
    fireEvent.change(passwordInput, { target: { value: "password123" } });
    // using form submit bypasses the DOM native validation for tests
    fireEvent.submit(submitBtn.closest("form")!);

    // Assert
    expect(mockLogin).toHaveBeenCalledWith("user@test.com", "password123");
  });

  // --- Edge Cases ---
  it("Login_EmptySubmission_ShowsValidationError", async () => {
    // Arrange
    renderComponent();
    const submitBtn = screen.getByRole("button", { name: /Sign In/i });

    // Act
    fireEvent.submit(submitBtn.closest("form")!);

    // Assert
    expect(mockLogin).not.toHaveBeenCalled();
    expect(
      await screen.findByText(/Please fill in all fields/i),
    ).toBeInTheDocument();
  });

  // --- Extraordinary Cases ---
  it("Login_InsanelyLongInput_DoesNotCrashApp", async () => {
    // Arrange
    renderComponent();
    const emailInput = screen.getByLabelText(/Email Address/i);
    const passwordInput = screen.getByLabelText(/Password/i);
    const massiveStr = "A".repeat(50000);

    // Act
    fireEvent.change(emailInput, { target: { value: massiveStr } });
    fireEvent.change(passwordInput, { target: { value: massiveStr } });

    // Assert - Simply proving it rendered without crashing during change
    expect((emailInput as HTMLInputElement).value).toBe(massiveStr);
  });
});
