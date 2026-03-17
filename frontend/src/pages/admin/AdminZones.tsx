import React, { useState, useEffect } from "react";
import { api } from "../../api";
import { useAuth } from "../../context/AuthContext";
import { Card } from "../../components/Card";
import { Button } from "../../components/Button";
import { Input } from "../../components/Input";
import { Navigate, useNavigate } from "react-router-dom";

interface Zone {
  id: number;
  name: string;
  description: string;
  route_type: string;
  allows_lead: boolean;
}

export const AdminZones: React.FC = () => {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [zones, setZones] = useState<Zone[]>([]);
  const [newZone, setNewZone] = useState({
    name: "",
    description: "",
    route_type: "boulder",
    allows_lead: false,
  });
  const [editingZone, setEditingZone] = useState<Zone | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState("");

  const fetchZones = async () => {
    try {
      const data = await api.get<Zone[]>("/routes/zones");
      setZones(data);
    } catch (err) {
      console.error(err);
    }
  };

  useEffect(() => {
    fetchZones();
  }, []);

  const handleAddZone = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newZone.name.trim()) {
      setError("Zone name is required");
      return;
    }
    setIsLoading(true);
    setError("");
    try {
      await api.post("/admin/zones", newZone);
      setNewZone({
        name: "",
        description: "",
        route_type: "boulder",
        allows_lead: false,
      });
      fetchZones();
    } catch (err) {
      const e = err as Error;
      setError(e.message || "Failed to add zone");
    } finally {
      setIsLoading(false);
    }
  };

  const handleUpdateZone = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingZone || !editingZone.name.trim()) return;
    setIsLoading(true);
    setError("");
    try {
      await api.patch(`/admin/zones/${editingZone.id}`, {
        name: editingZone.name,
        description: editingZone.description,
        route_type: editingZone.route_type,
        allows_lead: editingZone.allows_lead,
      });
      setEditingZone(null);
      fetchZones();
    } catch (err) {
      const e = err as Error;
      setError(e.message || "Failed to update zone");
    } finally {
      setIsLoading(false);
    }
  };

  const handleDeleteZone = async (zoneId: number) => {
    if (!window.confirm("Are you sure you want to delete this zone? This will fail if there are any routes in it.")) return;
    try {
      await api.delete(`/admin/zones/${zoneId}`);
      fetchZones();
    } catch (err) {
      const e = err as Error;
      setError(e.message || "Failed to delete zone");
    }
  };

  if (!user || user.role !== "super_admin") {
    return <Navigate to="/admin" replace />;
  }

  return (
    <div className="admin-dashboard animate-fade-in" style={{ padding: "1rem" }}>
      <Button
        onClick={() => navigate("/admin")}
        variant="secondary"
        style={{ marginBottom: "1rem" }}
      >
        ← Back to Dashboard
      </Button>

      <h1 className="page-title">Manage Wall Zones</h1>

      {error && (
        <div className="error-banner" style={{ color: "var(--error-color)", marginBottom: "1rem" }}>
          {error}
        </div>
      )}

      {/* Add New Zone */}
      {!editingZone && (
        <div style={{ marginBottom: "2rem" }}>
          <Card>
            <h3 className="section-title">Add New Zone</h3>
            <form onSubmit={handleAddZone} style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
            <div style={{ display: "flex", gap: "1rem", flexWrap: "wrap" }}>
              <div style={{ flex: 1, minWidth: "200px" }}>
                <label className="input-label">Zone Name</label>
                <Input
                  placeholder="e.g. West Wall"
                  value={newZone.name}
                  onChange={(e) => setNewZone({ ...newZone, name: e.target.value })}
                />
              </div>
              <div style={{ flex: 1, minWidth: "200px" }}>
                <label className="input-label">Type</label>
                <select
                  className="ios-input"
                  style={{ width: "100%", height: "48px", borderRadius: "12px", border: "1px solid var(--border-color)", padding: "0 1rem" }}
                  value={newZone.route_type}
                  onChange={(e) => {
                    const type = e.target.value;
                    setNewZone({ 
                      ...newZone, 
                      route_type: type,
                      allows_lead: type === "boulder" ? false : newZone.allows_lead 
                    });
                  }}
                >
                  <option value="boulder">Boulder</option>
                  <option value="top_rope">Top Rope</option>
                </select>
              </div>
            </div>
            <div>
              <label className="input-label">Description</label>
              <Input
                placeholder="Brief description of the area"
                value={newZone.description}
                onChange={(e) => setNewZone({ ...newZone, description: e.target.value })}
              />
            </div>
            <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
              <input
                type="checkbox"
                id="allows_lead"
                checked={newZone.allows_lead}
                disabled={newZone.route_type === "boulder"}
                onChange={(e) => setNewZone({ ...newZone, allows_lead: e.target.checked })}
              />
              <label htmlFor="allows_lead" style={{ fontSize: "0.9rem", color: newZone.route_type === "boulder" ? "var(--text-secondary)" : "inherit" }}>
                Allows Lead Climbing {newZone.route_type === "boulder" && "(Only for Top Rope)"}
              </label>
            </div>
            <Button type="submit" isLoading={isLoading}>Add Zone</Button>
          </form>
        </Card>
      </div>
      )}

      {/* Edit Existing Zone */}
      {editingZone && (
        <div style={{ marginBottom: "2rem", border: "2px solid var(--accent-color)", borderRadius: "16px" }}>
          <Card className="edit-zone-card">
            <h3 className="section-title">Edit Zone: {editingZone.name}</h3>
            <form onSubmit={handleUpdateZone} style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
            <div style={{ display: "flex", gap: "1rem", flexWrap: "wrap" }}>
              <div style={{ flex: 1, minWidth: "200px" }}>
                <label className="input-label">Zone Name</label>
                <Input
                  value={editingZone.name}
                  onChange={(e) => setEditingZone({ ...editingZone, name: e.target.value })}
                />
              </div>
              <div style={{ flex: 1, minWidth: "200px" }}>
                <label className="input-label">Type</label>
                <select
                  className="ios-input"
                  style={{ width: "100%", height: "48px", borderRadius: "12px", border: "1px solid var(--border-color)", padding: "0 1rem" }}
                  value={editingZone.route_type}
                  onChange={(e) => {
                    const type = e.target.value;
                    setEditingZone({ 
                      ...editingZone, 
                      route_type: type,
                      allows_lead: type === "boulder" ? false : editingZone.allows_lead
                    });
                  }}
                >
                  <option value="boulder">Boulder</option>
                  <option value="top_rope">Top Rope</option>
                </select>
              </div>
            </div>
            <div>
              <label className="input-label">Description</label>
              <Input
                value={editingZone.description}
                onChange={(e) => setEditingZone({ ...editingZone, description: e.target.value })}
              />
            </div>
            <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
              <input
                type="checkbox"
                id="edit_allows_lead"
                checked={editingZone.allows_lead}
                disabled={editingZone.route_type === "boulder"}
                onChange={(e) => setEditingZone({ ...editingZone, allows_lead: e.target.checked })}
              />
              <label htmlFor="edit_allows_lead" style={{ fontSize: "0.9rem", color: editingZone.route_type === "boulder" ? "var(--text-secondary)" : "inherit" }}>
                Allows Lead Climbing {editingZone.route_type === "boulder" && "(Only for Top Rope)"}
              </label>
            </div>
            <div style={{ display: "flex", gap: "1rem" }}>
              <Button type="submit" isLoading={isLoading} style={{ flex: 1 }}>Save Changes</Button>
              <Button type="button" variant="secondary" onClick={() => setEditingZone(null)} style={{ flex: 1 }}>Cancel</Button>
            </div>
          </form>
        </Card>
      </div>
      )}

      {/* Zone List */}
      <Card>
        <h3 className="section-title">Existing Zones</h3>
        <div className="ios-list-container">
          {zones.map((zone, index) => (
            <div key={zone.id} className={`ios-list-item ${index === zones.length - 1 ? "last-item" : ""}`}>
              <div style={{ flex: 1 }}>
                <div className="ios-list-grade" style={{ color: "var(--text-primary)" }}>
                  {zone.name} <span style={{ fontSize: "0.75rem", background: "var(--bg-secondary)", padding: "2px 6px", borderRadius: "4px", marginLeft: "8px" }}>{zone.route_type}</span>
                  {zone.allows_lead && <span style={{ fontSize: "0.75rem", background: "#E8F5E9", color: "#2E7D32", padding: "2px 6px", borderRadius: "4px", marginLeft: "4px" }}>Lead</span>}
                </div>
                <div className="ios-list-count">{zone.description || "No description"}</div>
              </div>
              <div style={{ display: "flex", gap: "0.5rem" }}>
                <Button
                  variant="secondary"
                  style={{ padding: "0.4rem 0.8rem", fontSize: "0.8rem" }}
                  onClick={() => setEditingZone(zone)}
                >
                  Edit
                </Button>
                <Button
                  variant="danger"
                  style={{ padding: "0.4rem 0.8rem", fontSize: "0.8rem" }}
                  onClick={() => handleDeleteZone(zone.id)}
                >
                  Delete
                </Button>
              </div>
            </div>
          ))}
          {zones.length === 0 && (
            <div className="ios-list-item last-item">
              <span className="ios-list-count">No zones configured.</span>
            </div>
          )}
        </div>
      </Card>
    </div>
  );
};
