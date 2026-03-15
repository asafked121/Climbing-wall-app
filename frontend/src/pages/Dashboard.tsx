import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { api } from "../api";
import { useAuth } from "../context/AuthContext";
import { Card } from "../components/Card";
import "./Dashboard.css";

interface RouteItem {
  id: number;
  color: string;
  color_name: string | null;
  intended_grade: string;
  status: string;
  setter: {
    id: number;
    name: string;
  } | null;
  zone: {
    id: number;
    name: string;
    route_type: string;
  } | null;
  set_date: string | null;
}

export const Dashboard: React.FC = () => {
  const { user } = useAuth();
  const canManageRoutes =
    user?.role === "admin" ||
    user?.role === "super_admin" ||
    user?.role === "setter";

  const [routes, setRoutes] = useState<RouteItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [filterType, setFilterType] = useState<string>("boulder");
  const [statusFilter, setStatusFilter] = useState<string>("active");
  const [zoneFilter, setZoneFilter] = useState<string>("");
  const [zones, setZones] = useState<{id: number, route_type: string, name: string}[]>([]);

  useEffect(() => {
    const fetchFilters = async () => {
      try {
        const zonesData = await api.get<{id: number, route_type: string, name: string}[]>("/routes/zones");
        setZones(zonesData);
      } catch (err) {
        console.error("Failed to load zones", err);
      }
    };
    fetchFilters();
  }, []);

  useEffect(() => {
    if (zoneFilter) {
      const isValid = zones.some(
        (z) => z.route_type === filterType && z.id.toString() === zoneFilter,
      );
      if (!isValid) setZoneFilter("");
    }
  }, [filterType, zones, zoneFilter]);

  useEffect(() => {
    const fetchRoutes = async () => {
      try {
        setIsLoading(true);
        const params = new URLSearchParams();
        if (filterType) params.append("route_type", filterType);
        if (zoneFilter) params.append("zone_id", zoneFilter);
        if (canManageRoutes && statusFilter)
          params.append("status", statusFilter);

        const query = params.toString() ? `?${params.toString()}` : "";
        const data = await api.get<RouteItem[]>(`/routes${query}`);
        setRoutes(data);
      } catch (err) {
        console.error("Failed to fetch routes", err);
      } finally {
        setIsLoading(false);
      }
    };
    fetchRoutes();
  }, [filterType, zoneFilter, statusFilter, canManageRoutes]);

  return (
    <div className="dashboard">
      <div className="dashboard-header animate-fade-in">
        <h1>Climbing Routes</h1>
        <div
          className="filter-group"
          style={{ display: "flex", gap: "0.5rem", flexWrap: "wrap" }}
        >
          <select
            value={zoneFilter}
            onChange={(e) => setZoneFilter(e.target.value)}
            className="input-field"
            style={{ width: "auto", padding: "0.5rem", margin: 0 }}
          >
            <option value="">All Zones</option>
            {zones
              .filter((z) => z.route_type === filterType)
              .map((z) => (
                <option key={z.id} value={z.id}>
                  {z.name}
                </option>
              ))}
          </select>

          <div className="type-toggle">
            <button
              className={`toggle-btn ${filterType === "boulder" ? "active" : ""}`}
              onClick={() => setFilterType("boulder")}
            >
              Bouldering
            </button>
            <button
              className={`toggle-btn ${filterType === "top_rope" ? "active" : ""}`}
              onClick={() => setFilterType("top_rope")}
            >
              Top Rope
            </button>
          </div>

          {canManageRoutes && (
            <div className="type-toggle">
              <button
                className={`toggle-btn ${statusFilter === "active" ? "active" : ""}`}
                onClick={() => setStatusFilter("active")}
              >
                Active
              </button>
              <button
                className={`toggle-btn ${statusFilter === "archived" ? "active" : ""}`}
                onClick={() => setStatusFilter("archived")}
              >
                Archived
              </button>
            </div>
          )}
        </div>
      </div>

      {isLoading ? (
        <div
          style={{ display: "flex", justifyContent: "center", padding: "3rem" }}
        >
          <span
            className="loader"
            style={{
              borderColor: "var(--border-color)",
              borderTopColor: "var(--primary-color)",
            }}
          ></span>
        </div>
      ) : routes.length === 0 ? (
        <div
          style={{
            textAlign: "center",
            padding: "3rem",
            color: "var(--text-secondary)",
          }}
        >
          No routes found.
        </div>
      ) : (
        <div className="route-grid">
          {routes.map((route) => (
            <Link
              to={`/routes/${route.id}`}
              key={route.id}
              style={{ textDecoration: "none", color: "inherit" }}
            >
              <Card className="route-card" noPadding>
                <div
                  className="route-color-bar"
                  style={{
                    backgroundColor: route.color || "var(--primary-color)",
                  }}
                />
                <div className="route-content">
                  <div className="route-main">
                    <h3 className="route-name">
                      {(route.color_name || route.color)
                        .charAt(0)
                        .toUpperCase() +
                        (route.color_name || route.color).slice(1)}{" "}
                      Route
                    </h3>
                    <span className="route-grade">{route.intended_grade}</span>
                  </div>
                  <div className="route-meta">
                    <span>Zone: {route.zone?.name || "Unknown"}</span>
                    <span>Setter: {route.setter?.name || "Unknown"}</span>
                  </div>
                </div>
              </Card>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
};
