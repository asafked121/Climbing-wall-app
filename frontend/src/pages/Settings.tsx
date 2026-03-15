import React, { useState, useEffect } from "react";
import { useAuth } from "../context/AuthContext";
import { useNavigate } from "react-router-dom";
import { Card } from "../components/Card";
import { Button } from "../components/Button";
import { Input } from "../components/Input";
import { api } from "../api";

export const Settings: React.FC = () => {
  const { user, logout, fetchUser } = useAuth();
  const navigate = useNavigate();

  const [isEditing, setIsEditing] = useState(false);
  const [newUsername, setNewUsername] = useState(user?.username || "");
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  const [ascents, setAscents] = useState<{ascent_type: string}[]>([]);

  useEffect(() => {
    if (user && user.id > 0) {
      api
        .get<{ascent_type: string}[]>(`/routes/user/${user.id}/ascents`)
        .then((data) => setAscents(data))
        .catch((err) => console.error("Failed to load ascents", err));
    }
  }, [user]);

  const handleUpdateUsername = async () => {
    if (!newUsername.trim()) {
      setError("Username cannot be empty");
      return;
    }

    if (newUsername.trim() === user?.username) {
      setIsEditing(false);
      return;
    }

    setIsLoading(true);
    setError("");
    try {
      await api.patch("/auth/me/username", { username: newUsername.trim() });
      // Refresh the user context so the new username propagates across the app
      if (fetchUser) await fetchUser();
      setIsEditing(false);
    } catch (err) {
      const e = err as Error;
      setError(e.message || "Failed to update username");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div
      className="settings-page animate-fade-in"
      style={{ display: "flex", flexDirection: "column", gap: "1.5rem" }}
    >
      <h1 className="page-title">Settings</h1>

      <Card>
        {error && (
          <div
            className="error-banner"
            style={{ color: "var(--error-color)", marginBottom: "1rem" }}
          >
            {error}
          </div>
        )}

        <div style={{ marginBottom: "1.5rem" }}>
          {isEditing ? (
            <div
              style={{
                display: "flex",
                gap: "0.5rem",
                alignItems: "center",
                marginBottom: "0.25rem",
              }}
            >
              <Input
                value={newUsername}
                onChange={(e) => setNewUsername(e.target.value)}
                placeholder="New Username"
                style={{ margin: 0, flex: 1 }}
              />
              <Button
                variant="primary"
                onClick={handleUpdateUsername}
                isLoading={isLoading}
              >
                Save
              </Button>
              <Button variant="secondary" onClick={() => setIsEditing(false)}>
                Cancel
              </Button>
            </div>
          ) : (
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "flex-start",
              }}
            >
              <h3 style={{ fontSize: "1.25rem", marginBottom: "0.25rem" }}>
                {user?.username}
              </h3>
              <Button
                variant="secondary"
                style={{ padding: "0.2rem 0.6rem", fontSize: "0.8rem" }}
                onClick={() => {
                  setIsEditing(true);
                  setNewUsername(user?.username || "");
                }}
              >
                Edit
              </Button>
            </div>
          )}
          <p style={{ color: "var(--text-secondary)", fontSize: "0.875rem" }}>
            {user?.email}
          </p>
        </div>

        <div style={{ marginBottom: "2rem" }}>
          <p>
            <strong>Role:</strong>{" "}
            <span style={{ textTransform: "capitalize" }}>{user?.role}</span>
          </p>
        </div>

        <div style={{ marginBottom: "2rem" }}>
          <h3 style={{ fontSize: "1.1rem", marginBottom: "0.5rem" }}>
            Climbing Stats
          </h3>
          <div
            style={{
              display: "grid",
              gridTemplateColumns: "1fr 1fr 1fr",
              gap: "1rem",
              textAlign: "center",
            }}
          >
            <div
              style={{
                padding: "1rem",
                backgroundColor: "var(--card-bg)",
                borderRadius: "8px",
                border: "1px solid var(--border-color)",
              }}
            >
              <div
                style={{
                  fontSize: "1.5rem",
                  fontWeight: "bold",
                  color: "var(--primary-color)",
                }}
              >
                {ascents.filter((a) => a.ascent_type === "boulder").length}
              </div>
              <div
                style={{ fontSize: "0.8rem", color: "var(--text-secondary)" }}
              >
                Boulders
              </div>
            </div>
            <div
              style={{
                padding: "1rem",
                backgroundColor: "var(--card-bg)",
                borderRadius: "8px",
                border: "1px solid var(--border-color)",
              }}
            >
              <div
                style={{
                  fontSize: "1.5rem",
                  fontWeight: "bold",
                  color: "var(--primary-color)",
                }}
              >
                {ascents.filter((a) => a.ascent_type === "top_rope").length}
              </div>
              <div
                style={{ fontSize: "0.8rem", color: "var(--text-secondary)" }}
              >
                Top Ropes
              </div>
            </div>
            <div
              style={{
                padding: "1rem",
                backgroundColor: "var(--card-bg)",
                borderRadius: "8px",
                border: "1px solid var(--border-color)",
              }}
            >
              <div
                style={{
                  fontSize: "1.5rem",
                  fontWeight: "bold",
                  color: "var(--primary-color)",
                }}
              >
                {ascents.filter((a) => a.ascent_type === "lead").length}
              </div>
              <div
                style={{ fontSize: "0.8rem", color: "var(--text-secondary)" }}
              >
                Leads
              </div>
            </div>
          </div>
        </div>

        {(user?.role === "admin" ||
          user?.role === "super_admin" ||
          user?.role === "setter") && (
          <div style={{ marginBottom: "2rem" }}>
            <Button
              variant="primary"
              fullWidth
              onClick={() => navigate("/admin")}
            >
              Admin Dashboard
            </Button>
          </div>
        )}

        <Button variant="danger" fullWidth onClick={() => logout()}>
          Sign Out
        </Button>
      </Card>
    </div>
  );
};
