import React, { useState, useEffect } from "react";
import { api } from "../../api";
import { useAuth } from "../../context/AuthContext";
import { Card } from "../../components/Card";
import { Button } from "../../components/Button";
import { Navigate, useNavigate } from "react-router-dom";

interface UserData {
  id: number;
  email: string;
  username: string;
  role: string;
  is_banned: boolean;
}

export const AdminUsers: React.FC = () => {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [users, setUsers] = useState<UserData[]>([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [error, setError] = useState("");

  const fetchUsers = async () => {
    try {
      const data = await api.get<UserData[]>("/admin/users");
      setUsers(data);
    } catch (err) {
      console.error(err);
    }
  };

  useEffect(() => {
    // eslint-disable-next-line
    fetchUsers();
  }, []);

  const handleUpdateUserRole = async (userId: number, role: string) => {
    try {
      await api.patch(`/admin/users/${userId}/role`, { role });
      fetchUsers();
    } catch (err) {
      const e = err as Error;
      setError(e.message);
    }
  };

  const handleToggleBan = async (userId: number, isBanned: boolean) => {
    try {
      await api.patch(`/admin/users/${userId}/ban`, { is_banned: !isBanned });
      fetchUsers();
    } catch (err) {
      const e = err as Error;
      setError(e.message);
    }
  };

  const handleDeleteUser = async (userId: number) => {
    if (!window.confirm("Are you sure you want to delete this user?")) return;
    try {
      await api.delete(`/admin/users/${userId}`);
      fetchUsers();
    } catch (err) {
      const e = err as Error;
      setError(e.message);
    }
  };

  if (!user || (user.role !== "admin" && user.role !== "super_admin")) {
    return <Navigate to="/" replace />;
  }

  const isSuperAdmin = user.role === "super_admin";

  const canModifyUser = (targetUser: UserData) => {
    if (isSuperAdmin) return true;
    if (
      user.role === "admin" &&
      targetUser.role !== "super_admin" &&
      targetUser.role !== "admin"
    )
      return true;
    return false;
  };

  const filteredUsers = users.filter((u) => {
    const query = searchQuery.toLowerCase();
    return (
      u.username.toLowerCase().includes(query) ||
      u.email.toLowerCase().includes(query)
    );
  });

  return (
    <div
      className="admin-dashboard animate-fade-in"
      style={{ padding: "1rem" }}
    >
      <Button
        onClick={() => navigate("/admin")}
        variant="secondary"
        style={{ marginBottom: "1rem", width: "fit-content" }}
      >
        ← Back to Dashboard
      </Button>

      <h1 className="page-title">Manage Users</h1>
      {error && (
        <div
          className="error-banner"
          style={{ color: "var(--error-color)", marginBottom: "1rem" }}
        >
          {error}
        </div>
      )}

      <Card>
        <div style={{ marginBottom: "1.5rem" }}>
          <p
            style={{
              color: "var(--text-secondary)",
              marginBottom: "1rem",
              fontSize: "0.9rem",
            }}
          >
            View and manage user roles and status.
          </p>
          <div className="input-with-icon">
            <input
              type="text"
              placeholder="Search by username or email..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              style={{
                width: "100%",
                padding: "0.75rem 1rem 0.75rem 2.5rem",
                borderRadius: "var(--radius-md)",
                border: "1px solid var(--border-color)",
                background: "var(--bg-color)",
                fontSize: "1rem",
              }}
            />
          </div>
        </div>
        <div className="ios-list-container">
          {filteredUsers.map((u, index) => (
            <div
              key={u.id}
              className={`ios-list-item ${index === filteredUsers.length - 1 ? "last-item" : ""}`}
              style={{ flexWrap: "wrap", gap: "8px" }}
            >
              <div style={{ flex: 1, minWidth: "200px" }}>
                <div
                  className="ios-list-grade"
                  style={{
                    textDecoration: u.is_banned ? "line-through" : "none",
                    color: u.is_banned
                      ? "var(--error-color)"
                      : "var(--text-primary)",
                  }}
                >
                  {u.username}{" "}
                  <span style={{ fontSize: "0.8rem", opacity: 0.7 }}>
                    ({u.email})
                  </span>
                </div>
                <div
                  className="ios-list-count"
                  style={{
                    display: "flex",
                    gap: "8px",
                    alignItems: "center",
                    marginTop: "4px",
                  }}
                >
                  <span
                    style={{
                      padding: "2px 6px",
                      background: "var(--primary-color)",
                      color: "white",
                      borderRadius: "4px",
                      fontSize: "0.75rem",
                    }}
                  >
                    {u.role.toUpperCase()}
                  </span>
                  {u.is_banned && (
                    <span
                      style={{
                        padding: "2px 6px",
                        background: "var(--error-color)",
                        color: "white",
                        borderRadius: "4px",
                        fontSize: "0.75rem",
                      }}
                    >
                      BANNED
                    </span>
                  )}
                </div>
              </div>

              <div style={{ display: "flex", gap: "0.5rem", flexWrap: "wrap" }}>
                {canModifyUser(u) && u.id !== user.id && (
                  <>
                    <select
                      value={u.role}
                      onChange={(e) =>
                        handleUpdateUserRole(u.id, e.target.value)
                      }
                      style={{
                        padding: "0.4rem",
                        borderRadius: "4px",
                        border: "1px solid var(--border-color)",
                        backgroundColor: "var(--card-bg)",
                      }}
                      title="Update role"
                    >
                      <option value="student">Student</option>
                      <option value="setter">Setter</option>
                      {isSuperAdmin && <option value="admin">Admin</option>}
                      {isSuperAdmin && (
                        <option value="super_admin">Super Admin</option>
                      )}
                    </select>
                    <Button
                      variant={u.is_banned ? "primary" : "danger"}
                      style={{
                        padding: "0.4rem 0.8rem",
                        fontSize: "0.8rem",
                        minHeight: "30px",
                      }}
                      onClick={() => handleToggleBan(u.id, u.is_banned)}
                    >
                      {u.is_banned ? "Unban" : "Ban"}
                    </Button>
                    {isSuperAdmin && (
                      <Button
                        variant="danger"
                        style={{
                          padding: "0.4rem 0.8rem",
                          fontSize: "0.8rem",
                          minHeight: "30px",
                        }}
                        onClick={() => handleDeleteUser(u.id)}
                      >
                        Delete
                      </Button>
                    )}
                  </>
                )}
              </div>
            </div>
          ))}
          {filteredUsers.length === 0 && (
            <div className="ios-list-item last-item">
              <span className="ios-list-count">No users found.</span>
            </div>
          )}
        </div>
      </Card>
    </div>
  );
};
