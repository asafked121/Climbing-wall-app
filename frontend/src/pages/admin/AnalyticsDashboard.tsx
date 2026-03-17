import React, { useCallback, useEffect, useState } from "react";
import { Navigate } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";
import { api } from "../../api";
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  LineElement,
  PointElement,
  Tooltip,
  Legend,
  Filler,
} from "chart.js";
import { Bar, Line } from "react-chartjs-2";
import "./AnalyticsDashboard.css";

ChartJS.register(
  CategoryScale,
  LinearScale,
  BarElement,
  LineElement,
  PointElement,
  Tooltip,
  Legend,
  Filler,
);

/* ---------- Type definitions ---------- */

interface GradeCount {
  grade: string;
  count: number;
}

interface RouteStatusCount {
  active: number;
  archived: number;
}

interface ZoneCount {
  zone: string;
  count: number;
}

interface DayCount {
  date: string;
  count: number;
}

interface RatingCount {
  rating: number;
  count: number;
}

interface TopRatedRoute {
  route_id: number;
  grade: string;
  color: string;
  avg_rating: number;
  rating_count: number;
}

interface AnalyticsData {
  grade_distribution: GradeCount[];
  ascents_by_grade: GradeCount[];
  route_status: RouteStatusCount;
  zone_utilization: ZoneCount[];
  activity_trend: DayCount[];
  rating_distribution: RatingCount[];
  top_rated_routes: TopRatedRoute[];
}

/* ---------- Chart color palette ---------- */

const CHART_COLORS = [
  "rgba(59, 130, 246, 0.85)", // blue
  "rgba(139, 92, 246, 0.85)", // violet
  "rgba(16, 185, 129, 0.85)", // emerald
  "rgba(245, 158, 11, 0.85)", // amber
  "rgba(239, 68, 68, 0.85)", // red
  "rgba(236, 72, 153, 0.85)", // pink
  "rgba(6, 182, 212, 0.85)", // cyan
  "rgba(132, 204, 22, 0.85)", // lime
  "rgba(168, 85, 247, 0.85)", // purple
  "rgba(251, 146, 60, 0.85)", // orange
  "rgba(20, 184, 166, 0.85)", // teal
  "rgba(244, 63, 94, 0.85)", // rose
  "rgba(99, 102, 241, 0.85)", // indigo
];

/* ---------- Shared chart options ---------- */

const isDarkMode = () =>
  window.matchMedia &&
  window.matchMedia("(prefers-color-scheme: dark)").matches;

function getGridColor(): string {
  return isDarkMode() ? "rgba(148, 163, 184, 0.15)" : "rgba(0, 0, 0, 0.06)";
}

function getTextColor(): string {
  return isDarkMode() ? "#cbd5e1" : "#64748b";
}

function baseBarOptions(horizontal = false): object {
  return {
    responsive: true,
    maintainAspectRatio: false,
    indexAxis: horizontal ? ("y" as const) : ("x" as const),
    plugins: {
      legend: { display: false },
      tooltip: {
        backgroundColor: isDarkMode() ? "#1e293b" : "#fff",
        titleColor: isDarkMode() ? "#f8fafc" : "#0f172a",
        bodyColor: isDarkMode() ? "#cbd5e1" : "#334155",
        borderColor: isDarkMode() ? "#334155" : "#e2e8f0",
        borderWidth: 1,
        cornerRadius: 8,
        padding: 10,
      },
    },
    scales: {
      x: {
        grid: { color: getGridColor(), drawBorder: false },
        ticks: { color: getTextColor(), font: { family: "Outfit" } },
      },
      y: {
        grid: { color: getGridColor(), drawBorder: false },
        ticks: {
          color: getTextColor(),
          font: { family: "Outfit" },
          precision: 0,
        },
        beginAtZero: true,
      },
    },
  };
}

/* ---------- Rank badge helper ---------- */

function rankClass(index: number): string {
  if (index === 0) return "gold";
  if (index === 1) return "silver";
  if (index === 2) return "bronze";
  return "default";
}

/* ---------- Filter type ---------- */
type StatusFilter = "" | "active" | "archived";
type RouteTypeFilter = "" | "boulder" | "top_rope";

/* ---------- Component ---------- */

export const AnalyticsDashboard: React.FC = () => {
  const { user } = useAuth();
  const [data, setData] = useState<AnalyticsData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  /* Filter state */
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("active");
  const [routeTypeFilter, setRouteTypeFilter] = useState<RouteTypeFilter>("");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");

  const fetchAnalytics = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const params = new URLSearchParams();
      if (statusFilter) params.set("status", statusFilter);
      if (routeTypeFilter) params.set("route_type", routeTypeFilter);
      if (dateFrom) params.set("date_from", dateFrom);
      if (dateTo) params.set("date_to", dateTo);
      const qs = params.toString();
      const url = `/admin/analytics${qs ? `?${qs}` : ""}`;
      const result = await api.get<AnalyticsData>(url);
      setData(result);
    } catch (err: unknown) {
      const message =
        err instanceof Error ? err.message : "Failed to load analytics";
      setError(message);
    } finally {
      setLoading(false);
    }
  }, [statusFilter, routeTypeFilter, dateFrom, dateTo]);

  useEffect(() => {
    fetchAnalytics();
  }, [fetchAnalytics]);

  if (!user || user.role !== "super_admin") {
    return <Navigate to="/" replace />;
  }

  if (loading) {
    return (
      <div className="analytics-loading animate-fade-in">
        <span
          className="loader"
          style={{
            borderColor: "var(--text-secondary)",
            borderTopColor: "var(--primary-color)",
          }}
        />
        <span style={{ color: "var(--text-secondary)" }}>
          Loading analytics…
        </span>
      </div>
    );
  }

  if (error || !data) {
    return (
      <div className="analytics-error animate-fade-in">
        <span style={{ fontSize: "2rem" }}>⚠️</span>
        <span>{error || "Something went wrong"}</span>
      </div>
    );
  }

  const totalActiveRoutes = data.route_status.active;
  const totalArchivedRoutes = data.route_status.archived;
  const totalAscents = data.ascents_by_grade.reduce(
    (sum, g) => sum + g.count,
    0,
  );
  const totalRatings = data.rating_distribution.reduce(
    (sum, r) => sum + r.count,
    0,
  );

  /* ---------- Grade sorting helper ---------- */

  const compareGrades = (a: string, b: string) => {
    // Helper to get numeric value from V-scale or YDS
    const getVal = (s: string) => {
      if (s.startsWith("V")) {
        return parseInt(s.substring(1)) || 0;
      }
      if (s.startsWith("5.")) {
        const parts = s.split(".");
        const major = parseInt(parts[1]) || 0;
        const sub = parts[1].match(/[a-d]/)?.[0] || "";
        const subVal = sub ? sub.charCodeAt(0) - 96 : 0;
        return major * 10 + subVal;
      }
      return 0;
    };

    const valA = getVal(a);
    const valB = getVal(b);

    if (valA !== valB) return valA - valB;
    return a.localeCompare(b);
  };

  /* ---------- Chart data builders ---------- */

  const sortedGradeDist = [...data.grade_distribution].sort((a, b) =>
    compareGrades(a.grade, b.grade),
  );

  const gradeDistChartData = {
    labels: sortedGradeDist.map((g) => g.grade),
    datasets: [
      {
        label: "Active Routes",
        data: sortedGradeDist.map((g) => g.count),
        backgroundColor: CHART_COLORS.slice(0, sortedGradeDist.length),
        borderRadius: 6,
        borderSkipped: false,
      },
    ],
  };

  const sortedAscents = [...data.ascents_by_grade].sort((a, b) =>
    compareGrades(a.grade, b.grade),
  );

  const ascentsByGradeData = {
    labels: sortedAscents.map((g) => g.grade),
    datasets: [
      {
        label: "Ascents",
        data: sortedAscents.map((g) => g.count),
        backgroundColor: "rgba(139, 92, 246, 0.8)",
        borderRadius: 6,
        borderSkipped: false,
      },
    ],
  };

  const zoneUtilData = {
    labels: data.zone_utilization.map((z) => z.zone),
    datasets: [
      {
        label: "Active Routes",
        data: data.zone_utilization.map((z) => z.count),
        backgroundColor: CHART_COLORS.slice(0, data.zone_utilization.length),
        borderRadius: 6,
        borderSkipped: false,
      },
    ],
  };

  const trendLabels = data.activity_trend.map((d) => {
    const parts = d.date.split("-");
    return `${parts[1]}/${parts[2]}`;
  });

  const activityTrendData = {
    labels: trendLabels,
    datasets: [
      {
        label: "Ascents",
        data: data.activity_trend.map((d) => d.count),
        borderColor: "rgba(59, 130, 246, 1)",
        backgroundColor: (ctx: {
          chart: {
            ctx: CanvasRenderingContext2D;
            chartArea: { top: number; bottom: number };
          };
        }) => {
          const chart = ctx.chart;
          if (!chart.chartArea) return "rgba(59, 130, 246, 0.1)";
          const gradient = chart.ctx.createLinearGradient(
            0,
            chart.chartArea.top,
            0,
            chart.chartArea.bottom,
          );
          gradient.addColorStop(0, "rgba(59, 130, 246, 0.35)");
          gradient.addColorStop(1, "rgba(59, 130, 246, 0.02)");
          return gradient;
        },
        fill: true,
        tension: 0.4,
        pointRadius: 2,
        pointHoverRadius: 6,
        pointBackgroundColor: "rgba(59, 130, 246, 1)",
        borderWidth: 2.5,
      },
    ],
  };

  const ratingDistData = {
    labels: data.rating_distribution.map((r) => `${r.rating} ★`),
    datasets: [
      {
        label: "Ratings",
        data: data.rating_distribution.map((r) => r.count),
        backgroundColor: [
          "rgba(239, 68, 68, 0.75)",
          "rgba(251, 146, 60, 0.75)",
          "rgba(245, 158, 11, 0.75)",
          "rgba(132, 204, 22, 0.75)",
          "rgba(16, 185, 129, 0.75)",
        ],
        borderRadius: 6,
        borderSkipped: false,
      },
    ],
  };

  return (
    <div className="analytics-dashboard animate-fade-in">
      <h1 className="page-title">Wall Analytics</h1>
      <p className="analytics-subtitle">
        Performance insights &amp; climbing data
      </p>

      {/* Filter Bar */}
      <div className="analytics-filter-bar">
        <div className="analytics-filter-group">
          <label className="analytics-filter-label">Status</label>
          <div className="analytics-segmented">
            {(
              [
                ["", "All"],
                ["active", "Active"],
                ["archived", "Archived"],
              ] as const
            ).map(([val, label]) => (
              <button
                key={val}
                className={`analytics-seg-btn${statusFilter === val ? " active" : ""}`}
                onClick={() => setStatusFilter(val as StatusFilter)}
              >
                {label}
              </button>
            ))}
          </div>
        </div>

        <div className="analytics-filter-group">
          <label className="analytics-filter-label">Type</label>
          <div className="analytics-segmented">
            {(
              [
                ["", "All"],
                ["boulder", "Boulder"],
                ["top_rope", "Top Rope"],
              ] as const
            ).map(([val, label]) => (
              <button
                key={val}
                className={`analytics-seg-btn${routeTypeFilter === val ? " active" : ""}`}
                onClick={() => setRouteTypeFilter(val as RouteTypeFilter)}
              >
                {label}
              </button>
            ))}
          </div>
        </div>

        <div className="analytics-filter-group">
          <label className="analytics-filter-label">From</label>
          <input
            type="date"
            className="analytics-date-input"
            value={dateFrom}
            onChange={(e) => setDateFrom(e.target.value)}
          />
        </div>

        <div className="analytics-filter-group">
          <label className="analytics-filter-label">To</label>
          <input
            type="date"
            className="analytics-date-input"
            value={dateTo}
            onChange={(e) => setDateTo(e.target.value)}
          />
        </div>

        {(statusFilter !== "active" ||
          routeTypeFilter ||
          dateFrom ||
          dateTo) && (
          <button
            className="analytics-clear-btn"
            onClick={() => {
              setStatusFilter("active");
              setRouteTypeFilter("");
              setDateFrom("");
              setDateTo("");
            }}
          >
            Reset
          </button>
        )}
      </div>

      {/* Summary Stats */}
      <div className="analytics-summary-row">
        <div className="analytics-stat-card">
          <div className="analytics-stat-value">{totalActiveRoutes}</div>
          <div className="analytics-stat-label">Active Routes</div>
        </div>
        <div className="analytics-stat-card">
          <div className="analytics-stat-value">{totalArchivedRoutes}</div>
          <div className="analytics-stat-label">Archived</div>
        </div>
        <div className="analytics-stat-card">
          <div className="analytics-stat-value">{totalAscents}</div>
          <div className="analytics-stat-label">Total Ascents</div>
        </div>
        <div className="analytics-stat-card">
          <div className="analytics-stat-value">{totalRatings}</div>
          <div className="analytics-stat-label">Total Ratings</div>
        </div>
      </div>

      {/* Charts Grid */}
      <div className="analytics-grid">
        {/* Activity Trend — full width */}
        <div className="analytics-chart-card full-width">
          <div className="analytics-chart-title">
            <span className="chart-icon">📈</span> Activity Trend (Last 30 Days)
          </div>
          <div className="analytics-chart-container">
            <Line
              data={activityTrendData}
              options={{
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                  legend: { display: false },
                  tooltip: {
                    backgroundColor: isDarkMode() ? "#1e293b" : "#fff",
                    titleColor: isDarkMode() ? "#f8fafc" : "#0f172a",
                    bodyColor: isDarkMode() ? "#cbd5e1" : "#334155",
                    borderColor: isDarkMode() ? "#334155" : "#e2e8f0",
                    borderWidth: 1,
                    cornerRadius: 8,
                    padding: 10,
                  },
                },
                scales: {
                  x: {
                    grid: { display: false },
                    ticks: {
                      color: getTextColor(),
                      font: { family: "Outfit" },
                      maxTicksLimit: 10,
                    },
                  },
                  y: {
                    grid: { color: getGridColor() },
                    ticks: {
                      color: getTextColor(),
                      font: { family: "Outfit" },
                      precision: 0,
                    },
                    beginAtZero: true,
                  },
                },
              }}
            />
          </div>
        </div>

        {/* Grade Distribution */}
        <div className="analytics-chart-card">
          <div className="analytics-chart-title">
            <span className="chart-icon">🧱</span> Grade Distribution
          </div>
          <div className="analytics-chart-container">
            <Bar
              data={gradeDistChartData}
              options={baseBarOptions(true) as object}
            />
          </div>
        </div>

        {/* Ascents by Grade */}
        <div className="analytics-chart-card">
          <div className="analytics-chart-title">
            <span className="chart-icon">🧗</span> Ascents by Grade
          </div>
          <div className="analytics-chart-container">
            <Bar
              data={ascentsByGradeData}
              options={baseBarOptions() as object}
            />
          </div>
        </div>

        {/* Zone Utilization */}
        <div className="analytics-chart-card">
          <div className="analytics-chart-title">
            <span className="chart-icon">📍</span> Zone Utilization
          </div>
          <div className="analytics-chart-container">
            <Bar data={zoneUtilData} options={baseBarOptions(true) as object} />
          </div>
        </div>

        {/* Rating Distribution */}
        <div className="analytics-chart-card">
          <div className="analytics-chart-title">
            <span className="chart-icon">⭐</span> Rating Distribution
          </div>
          <div className="analytics-chart-container">
            <Bar data={ratingDistData} options={baseBarOptions() as object} />
          </div>
        </div>

        {/* Top Rated Routes */}
        <div className="analytics-chart-card">
          <div className="analytics-chart-title">
            <span className="chart-icon">🏆</span> Top Rated Routes
          </div>
          {data.top_rated_routes.length === 0 ? (
            <p
              style={{
                color: "var(--text-secondary)",
                fontSize: "0.9rem",
                textAlign: "center",
                marginTop: "2rem",
              }}
            >
              No rated routes yet
            </p>
          ) : (
            <table className="analytics-top-routes-table">
              <thead>
                <tr>
                  <th>#</th>
                  <th>Grade</th>
                  <th>Color</th>
                  <th>Rating</th>
                </tr>
              </thead>
              <tbody>
                {data.top_rated_routes.map((route, idx) => (
                  <tr key={route.route_id}>
                    <td>
                      <span className={`rank-badge ${rankClass(idx)}`}>
                        {idx + 1}
                      </span>
                    </td>
                    <td style={{ fontWeight: 600 }}>{route.grade}</td>
                    <td>{route.color}</td>
                    <td>
                      <span className="stars-display">
                        {route.avg_rating.toFixed(1)} ★
                      </span>
                      <span className="rating-count-badge">
                        ({route.rating_count})
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
};
