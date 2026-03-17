import React from "react";
import { useAuth } from "../context/AuthContext";
import { Card } from "../components/Card";
import { Button } from "../components/Button";
import { Navigate, useNavigate } from "react-router-dom";

export const AdminDashboard: React.FC = () => {
  const { user } = useAuth();
  const navigate = useNavigate();

  if (!user || (user.role !== "admin" && user.role !== "super_admin")) {
    return <Navigate to="/" replace />;
  }

  return (
    <div
      className="admin-dashboard animate-fade-in"
      style={{ padding: "1rem" }}
    >
      <h1 className="page-title">Admin Dashboard</h1>

      <div
        style={{
          display: "flex",
          flexDirection: "column",
          gap: "1rem",
          marginTop: "2rem",
        }}
      >
        <Card>
          <div
            style={{
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
            }}
          >
            <div>
              <h3 className="section-title" style={{ margin: 0 }}>
                Manage Users
              </h3>
              <p
                style={{
                  color: "var(--text-secondary)",
                  fontSize: "0.9rem",
                  margin: "4px 0 0 0",
                }}
              >
                Search and modify user roles and bans
              </p>
            </div>
            <Button onClick={() => navigate("/admin/users")}>Go</Button>
          </div>
        </Card>

        <Card>
          <div
            style={{
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
            }}
          >
            <div>
              <h3 className="section-title" style={{ margin: 0 }}>
                Manage Setters
              </h3>
              <p
                style={{
                  color: "var(--text-secondary)",
                  fontSize: "0.9rem",
                  margin: "4px 0 0 0",
                }}
              >
                Add or remove setters
              </p>
            </div>
            <Button onClick={() => navigate("/admin/setters")}>Go</Button>
          </div>
        </Card>

        <Card>
          <div
            style={{
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
            }}
          >
            <div>
              <h3 className="section-title" style={{ margin: 0 }}>
                Manage Colors
              </h3>
              <p
                style={{
                  color: "var(--text-secondary)",
                  fontSize: "0.9rem",
                  margin: "4px 0 0 0",
                }}
              >
                Configure route hold colors
              </p>
            </div>
            <Button onClick={() => navigate("/admin/colors")}>Go</Button>
          </div>
        </Card>

        {user?.role === "super_admin" && (
          <>
            <Card>
              <div
                style={{
                  display: "flex",
                  justifyContent: "space-between",
                  alignItems: "center",
                }}
              >
                <div>
                  <h3 className="section-title" style={{ margin: 0 }}>
                    Manage Zones
                  </h3>
                  <p
                    style={{
                      color: "var(--text-secondary)",
                      fontSize: "0.9rem",
                      margin: "4px 0 0 0",
                    }}
                  >
                    Add, delete, or rename wall zones
                  </p>
                </div>
                <Button onClick={() => navigate("/admin/zones")}>Go</Button>
              </div>
            </Card>

            <Card>
              <div
                style={{
                  display: "flex",
                  justifyContent: "space-between",
                  alignItems: "center",
                }}
              >
                <div>
                  <h3 className="section-title" style={{ margin: 0 }}>
                    Bulk Import Routes
                  </h3>
                  <p
                    style={{
                      color: "var(--text-secondary)",
                      fontSize: "0.9rem",
                      margin: "4px 0 0 0",
                    }}
                  >
                    Upload multiple routes via Excel (.xlsx)
                  </p>
                </div>
                <Button onClick={() => navigate("/admin/bulk-upload")}>Go</Button>
              </div>
            </Card>
          </>
        )}
      </div>
    </div>
  );
};
