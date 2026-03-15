import React, { useState, useEffect } from "react";
import { useNavigate, Link } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { Card } from "../components/Card";
import { Input } from "../components/Input";
import { Button } from "../components/Button";
import { isOldEnough } from "../utils/ageValidation";

export const Register: React.FC = () => {
  // Step state
  const [step, setStep] = useState<1 | 2>(1);
  const [isAgeBlocked, setIsAgeBlocked] = useState(false);

  // Form inputs
  const [birthMonth, setBirthMonth] = useState("");
  const [birthYear, setBirthYear] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [username, setUsername] = useState("");
  const [acceptedTos, setAcceptedTos] = useState(false);

  // Status
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  const { register } = useAuth();
  const navigate = useNavigate();

  // Check if previously blocked
  useEffect(() => {
    if (localStorage.getItem("age_gate_failed") === "true") {
      setIsAgeBlocked(true);
    }
  }, []);

  const handleAgeSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setError("");

    if (!birthMonth || !birthYear) {
      setError("Please select your birth month and year");
      return;
    }

    const validAge = isOldEnough(parseInt(birthMonth), parseInt(birthYear));

    if (!validAge) {
      localStorage.setItem("age_gate_failed", "true");
      setIsAgeBlocked(true);
      return;
    }

    setStep(2);
  };

  const handleFinalSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!email || !password) {
      setError("Please fill in all required fields");
      return;
    }

    if (!acceptedTos) {
      setError(
        "You must accept the Terms of Service and Assumption of Risk to register.",
      );
      return;
    }

    setError("");
    setIsLoading(true);

    try {
      const dobString = `${birthYear}-${birthMonth.padStart(2, "0")}-01`;
      await register(email, password, username || undefined, dobString);
      navigate("/");
    } catch (err) {
      // Check if it's the backend 422 error for underage (should not hit this unless bypassing frontend)
      const errorObj = err as {
        message?: string;
        response?: { data?: { detail?: { msg?: string }[] }; status?: number };
      };
      if (
        errorObj.response?.status === 422 &&
        errorObj.response?.data?.detail?.[0]?.msg?.includes("13 years old")
      ) {
        setIsAgeBlocked(true);
        localStorage.setItem("age_gate_failed", "true");
      } else {
        setError(errorObj.message || "Failed to create account.");
      }
    } finally {
      setIsLoading(false);
    }
  };

  // Render Blocks
  if (isAgeBlocked) {
    return (
      <Card>
        <div style={{ textAlign: "center", padding: "2rem 1rem" }}>
          <h2 style={{ marginBottom: "1rem", color: "var(--danger-color)" }}>
            Registration Unavailable
          </h2>
          <p style={{ color: "var(--text-secondary)" }}>
            To protect your privacy, you cannot create an account at this time.
            Please ask your parent or legal guardian to create an account for
            you.
          </p>
          <div style={{ marginTop: "2rem" }}>
            <Link
              to="/"
              style={{
                color: "var(--primary-color)",
                textDecoration: "none",
                fontWeight: "bold",
              }}
            >
              Return to Home
            </Link>
          </div>
        </div>
      </Card>
    );
  }

  return (
    <Card>
      <h2 style={{ marginBottom: "1.5rem", textAlign: "center" }}>
        Create Account
      </h2>

      {error && (
        <div
          style={{
            color: "var(--danger-color)",
            marginBottom: "1rem",
            fontSize: "0.875rem",
            textAlign: "center",
            background: "rgba(239, 68, 68, 0.1)",
            padding: "0.5rem",
            borderRadius: "var(--radius-sm)",
          }}
        >
          {error}
        </div>
      )}

      {step === 1 ? (
        <form onSubmit={handleAgeSubmit}>
          <div style={{ marginBottom: "1rem" }}>
            <label
              style={{
                display: "block",
                marginBottom: "0.5rem",
                fontSize: "0.875rem",
                fontWeight: 500,
                color: "var(--text-primary)",
              }}
            >
              Date of Birth *
            </label>
            <div style={{ display: "flex", gap: "1rem" }}>
              <select
                value={birthMonth}
                onChange={(e) => setBirthMonth(e.target.value)}
                required
                style={{
                  flex: 1,
                  width: "100%",
                  padding: "0.75rem",
                  borderRadius: "var(--radius-md)",
                  border: "1px solid var(--border-color)",
                  background: "var(--bg-primary)",
                  color: "var(--text-primary)",
                  fontSize: "1rem",
                }}
              >
                <option value="" disabled>
                  Month
                </option>
                {Array.from({ length: 12 }, (_, i) => i + 1).map((month) => (
                  <option key={month} value={month}>
                    {new Date(2000, month - 1, 1).toLocaleString("default", {
                      month: "long",
                    })}
                  </option>
                ))}
              </select>

              <select
                value={birthYear}
                onChange={(e) => setBirthYear(e.target.value)}
                required
                style={{
                  flex: 1,
                  width: "100%",
                  padding: "0.75rem",
                  borderRadius: "var(--radius-md)",
                  border: "1px solid var(--border-color)",
                  background: "var(--bg-primary)",
                  color: "var(--text-primary)",
                  fontSize: "1rem",
                }}
              >
                <option value="" disabled>
                  Year
                </option>
                {Array.from(
                  { length: 100 },
                  (_, i) => new Date().getFullYear() - i,
                ).map((year) => (
                  <option key={year} value={year}>
                    {year}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <div style={{ marginTop: "2rem" }}>
            <Button type="submit" fullWidth>
              Continue
            </Button>
          </div>
        </form>
      ) : (
        <form onSubmit={handleFinalSubmit}>
          <Input
            label="Email Address *"
            type="email"
            placeholder="climber@example.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />

          <Input
            label="Username (optional)"
            type="text"
            placeholder="climber123"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
          />

          <Input
            label="Password *"
            type="password"
            placeholder="••••••••"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />

          <div
            style={{
              marginTop: "1.5rem",
              display: "flex",
              alignItems: "flex-start",
              gap: "0.5rem",
            }}
          >
            <input
              type="checkbox"
              id="tos"
              checked={acceptedTos}
              onChange={(e) => setAcceptedTos(e.target.checked)}
              style={{ marginTop: "0.25rem" }}
            />
            <label
              htmlFor="tos"
              style={{
                fontSize: "0.875rem",
                color: "var(--text-secondary)",
                lineHeight: 1.4,
              }}
            >
              I agree to the{" "}
              <Link
                to="/terms"
                target="_blank"
                rel="noopener noreferrer"
                style={{ color: "var(--primary-color)" }}
              >
                Terms of Service
              </Link>{" "}
              and Privacy Policy. I acknowledge that climbing is an inherently
              dangerous sport and assume all risks associated.
            </label>
          </div>

          <div style={{ marginTop: "2rem" }}>
            <Button type="submit" fullWidth isLoading={isLoading}>
              Sign Up
            </Button>
          </div>

          <div style={{ marginTop: "1rem", textAlign: "center" }}>
            <button
              type="button"
              onClick={() => setStep(1)}
              style={{
                background: "none",
                border: "none",
                color: "var(--text-secondary)",
                cursor: "pointer",
                fontSize: "0.875rem",
                textDecoration: "underline",
              }}
            >
              Back
            </button>
          </div>
        </form>
      )}

      <div
        style={{
          marginTop: "1.5rem",
          textAlign: "center",
          fontSize: "0.875rem",
        }}
      >
        <span style={{ color: "var(--text-secondary)" }}>
          Already have an account?{" "}
        </span>
        <Link to="/login">Sign in here</Link>
      </div>
    </Card>
  );
};
