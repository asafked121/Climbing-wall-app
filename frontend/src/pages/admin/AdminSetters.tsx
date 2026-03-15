import React, { useState, useEffect } from "react";
import { api } from "../../api";
import { useAuth } from "../../context/AuthContext";
import { Card } from "../../components/Card";
import { Button } from "../../components/Button";
import { Input } from "../../components/Input";
import { Navigate, useNavigate } from "react-router-dom";

interface Setter {
  id: number;
  name: string;
  is_active: boolean;
}

export const AdminSetters: React.FC = () => {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [setters, setSetters] = useState<Setter[]>([]);
  const [newSetterName, setNewSetterName] = useState("");
  const [isLoadingSetters, setIsLoadingSetters] = useState(false);
  const [error, setError] = useState("");

  const fetchSetters = async () => {
    try {
      const data = await api.get<Setter[]>("/admin/setters");
      setSetters(data);
    } catch (err) {
      console.error(err);
    }
  };

  useEffect(() => {
    fetchSetters();
  }, []);

  const handleAddSetter = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newSetterName.trim()) {
      setError("Setter name required");
      return;
    }
    setIsLoadingSetters(true);
    setError("");
    try {
      await api.post("/admin/setters", {
        name: newSetterName.trim(),
        is_active: true,
      });
      setNewSetterName("");
      fetchSetters();
    } catch (err) {
      const e = err as Error;
      setError(e.message || "Failed to add setter");
    } finally {
      setIsLoadingSetters(false);
    }
  };

  const handleDeleteSetter = async (setterId: number) => {
    if (!window.confirm("Are you sure you want to delete this setter?")) return;
    try {
      await api.delete(`/admin/setters/${setterId}`);
      fetchSetters();
    } catch (err) {
      const e = err as Error;
      setError(e.message);
    }
  };

  if (!user || (user.role !== "admin" && user.role !== "super_admin")) {
    return <Navigate to="/" replace />;
  }

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

      <h1 className="page-title">Manage Setters</h1>
      {error && (
        <div
          className="error-banner"
          style={{ color: "var(--error-color)", marginBottom: "1rem" }}
        >
          {error}
        </div>
      )}

      <Card>
        <p
          style={{
            color: "var(--text-secondary)",
            marginBottom: "1.5rem",
            fontSize: "0.9rem",
          }}
        >
          Add or remove setters from the climb listing.
        </p>
        <form
          onSubmit={handleAddSetter}
          style={{
            display: "flex",
            gap: "1rem",
            alignItems: "flex-end",
            marginBottom: "2rem",
            flexWrap: "wrap",
          }}
        >
          <div style={{ flex: 1, minWidth: "150px" }}>
            <label className="input-label">Setter Name</label>
            <Input
              placeholder="e.g. Alex Honnold"
              value={newSetterName}
              onChange={(e) => setNewSetterName(e.target.value)}
              style={{ margin: 0 }}
            />
          </div>
          <Button
            type="submit"
            isLoading={isLoadingSetters}
            style={{ marginBottom: "2px" }}
          >
            Add Setter
          </Button>
        </form>

        <div className="ios-list-container">
          {setters.map((setter, index) => (
            <div
              key={setter.id}
              className={`ios-list-item ${index === setters.length - 1 ? "last-item" : ""}`}
            >
              <div
                style={{ display: "flex", alignItems: "center", gap: "1rem" }}
              >
                <div>
                  <div
                    className="ios-list-grade"
                    style={{ color: "var(--text-primary)" }}
                  >
                    {setter.name}
                  </div>
                </div>
              </div>
              <Button
                variant="danger"
                style={{ padding: "0.4rem 0.8rem", fontSize: "0.8rem" }}
                onClick={() => handleDeleteSetter(setter.id)}
              >
                Delete
              </Button>
            </div>
          ))}
          {setters.length === 0 && (
            <div className="ios-list-item last-item">
              <span className="ios-list-count">No setters configured.</span>
            </div>
          )}
        </div>
      </Card>
    </div>
  );
};
