import React, { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../api";
import { useAuth } from "../context/AuthContext";
import { Card } from "../components/Card";
import { Button } from "../components/Button";
import "./AddRoute.css";

interface Zone {
  id: number;
  name: string;
  route_type: string;
}
interface Setter {
  id: number;
  name: string;
}
interface Color {
  id: number;
  name: string;
  hex_value: string;
}

export const AddRoute: React.FC = () => {
  const [zones, setZones] = useState<Zone[]>([]);
  const [setters, setSetters] = useState<Setter[]>([]);
  const [colors, setColors] = useState<Color[]>([]);
  const [grades, setGrades] = useState<string[]>([]);

  const [zoneId, setZoneId] = useState<number | "">("");
  const [setterId, setSetterId] = useState<number | "">("");
  const [intendedGrade, setIntendedGrade] = useState("");
  const [color, setColor] = useState("#3b82f6");
  const [selectedPhoto, setSelectedPhoto] = useState<File | null>(null);

  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState("");

  const { user } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [zonesData, settersData, colorsData] = await Promise.all([
          api.get<Zone[]>("/routes/zones"),
          api.get<Setter[]>("/admin/setters"),
          api.get<Color[]>("/routes/colors"),
        ]);
        setZones(zonesData);
        setSetters(settersData);
        setColors(colorsData);
        if (colorsData.length > 0) {
          setColor(colorsData[0].hex_value);
        }
      } catch (err) {
        console.error("Failed to fetch form data", err);
      }
    };
    fetchData();
  }, []);

  useEffect(() => {
    if (zoneId !== "") {
      const fetchGrades = async () => {
        try {
          const gradesData = await api.get<string[]>(
            `/routes/grades?zone_id=${zoneId}`,
          );
          setGrades(gradesData);
          if (gradesData.length > 0) setIntendedGrade(gradesData[0]);
        } catch (err) {
          console.error("Failed to fetch grades", err);
        }
      };
      fetchGrades();
    } else {
      setGrades([]);
      setIntendedGrade("");
    }
  }, [zoneId]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (zoneId === "" || setterId === "" || !intendedGrade) {
      setError("Please fill in all required fields.");
      return;
    }
    setError("");
    setIsLoading(true);

    try {
      const newRoute = await api.post<{ id: number }>("/admin/routes", {
        zone_id: zoneId,
        setter_id: setterId,
        color,
        intended_grade: intendedGrade,
        status: "active",
      });

      if (selectedPhoto) {
        const formData = new FormData();
        formData.append("file", selectedPhoto);
        await api.postFormData(`/routes/${newRoute.id}/photo`, formData);
      }

      navigate("/");
    } catch (err) {
      const e = err as { message?: string };
      setError(e.message || "Failed to add route.");
    } finally {
      setIsLoading(false);
    }
  };

  if (
    !user ||
    (user.role !== "admin" &&
      user.role !== "super_admin" &&
      user.role !== "setter")
  ) {
    return (
      <Card>
        <h2>Access Denied</h2>
        <p>You must be a Setter or Admin to view this page.</p>
      </Card>
    );
  }

  return (
    <div className="add-route">
      <h1 className="page-title animate-fade-in">Add New Route</h1>
      <Card className="animate-fade-in">
        {error && <div className="error-banner">{error}</div>}

        <form onSubmit={handleSubmit} className="add-route-form">
          <div className="input-group">
            <label className="input-label">Zone *</label>
            <select
              className="input-field"
              value={zoneId}
              onChange={(e) => setZoneId(Number(e.target.value) || "")}
              required
            >
              <option value="">Select a Zone</option>
              {zones.map((z) => (
                <option key={z.id} value={z.id}>
                  {z.name} ({z.route_type})
                </option>
              ))}
            </select>
          </div>

          <div className="input-group">
            <label className="input-label">Grade *</label>
            <select
              className="input-field"
              value={intendedGrade}
              onChange={(e) => setIntendedGrade(e.target.value)}
              required
              disabled={!zoneId || grades.length === 0}
            >
              {grades.map((g) => (
                <option key={g} value={g}>
                  {g}
                </option>
              ))}
            </select>
          </div>

          <div className="input-group">
            <label className="input-label">Setter *</label>
            <select
              className="input-field"
              value={setterId}
              onChange={(e) => setSetterId(Number(e.target.value) || "")}
              required
            >
              <option value="">Select Setter</option>
              {setters.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </select>
          </div>

          <div className="input-group">
            <label className="input-label">Hold Color *</label>
            <div style={{ display: "flex", alignItems: "center", gap: "1rem" }}>
              <select
                className="input-field"
                value={color}
                onChange={(e) => setColor(e.target.value)}
                style={{ flex: 1, margin: 0 }}
                required
              >
                {colors.length === 0 && <option value="">Loading...</option>}
                {colors.map((c) => (
                  <option key={c.id} value={c.hex_value}>
                    {c.name}
                  </option>
                ))}
              </select>
              <div
                style={{
                  width: "32px",
                  height: "32px",
                  borderRadius: "50%",
                  backgroundColor: color,
                  border: "1px solid var(--border-color)",
                  flexShrink: 0,
                }}
              />
            </div>
          </div>

          <div className="input-group">
            <label className="input-label">Route Photo (Optional)</label>
            <input
              type="file"
              accept="image/*"
              onChange={(e) => setSelectedPhoto(e.target.files?.[0] || null)}
              className="input-field"
              style={{ padding: "0.4rem" }}
            />
          </div>

          <Button
            type="submit"
            fullWidth
            isLoading={isLoading}
            style={{ marginTop: "1rem" }}
          >
            Publish Route
          </Button>
        </form>
      </Card>
    </div>
  );
};
