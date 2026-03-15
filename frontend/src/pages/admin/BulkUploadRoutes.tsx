import React, { useState } from "react";
import { useAuth } from "../../context/AuthContext";
import { Navigate, useNavigate } from "react-router-dom";
import { Card } from "../../components/Card";
import { Button } from "../../components/Button";
import { api } from "../../api";
import "./BulkUploadRoutes.css";

interface RowError {
  row: number;
  field?: string;
  message: string;
}

interface UploadResponse {
  total_rows: number;
  created_count: number;
  error_count: number;
  errors: RowError[];
}

export const BulkUploadRoutes: React.FC = () => {
  const { user } = useAuth();
  const navigate = useNavigate();

  const [file, setFile] = useState<File | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  const [uploadResult, setUploadResult] = useState<UploadResponse | null>(null);
  const [globalError, setGlobalError] = useState<string | null>(null);

  // Only super_admin can access
  if (!user || user.role !== "super_admin") {
    return <Navigate to="/admin" replace />;
  }

  const handleDownloadTemplate = async () => {
    try {
      // Using fetch directly because we need to handle the blob response
      // The api utility is currently tuned for JSON

      const response = await fetch(
        `${import.meta.env.VITE_API_URL || "/api"}/admin/routes/bulk-template`,
        {
          headers: {
            // Include credentials via cookies but also the token if needed
          },
          credentials: "include",
        },
      );

      if (!response.ok) {
        throw new Error("Failed to download template");
      }

      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = "route_import_template.xlsx";
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    } catch (err) {
      const e = err as Error;
      setGlobalError(e.message || "Failed to download template");
    }
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files.length > 0) {
      setFile(e.target.files[0]);
      setGlobalError(null);
      setUploadResult(null);
    }
  };

  const handleUpload = async () => {
    if (!file) return;

    setIsUploading(true);
    setGlobalError(null);
    setUploadResult(null);

    try {
      const formData = new FormData();
      formData.append("file", file);

      const result = await api.postFormData<UploadResponse>(
        "/admin/routes/bulk-upload",
        formData,
      );
      setUploadResult(result);
    } catch (err) {
      const errorObj = err as {
        message?: string;
        data?: UploadResponse;
      };
      if (errorObj.data && errorObj.data.errors) {
        // If the API returns 400 with our structured error response
        setUploadResult(errorObj.data);
      } else {
        setGlobalError(errorObj.message || "An error occurred during upload");
      }
    } finally {
      setIsUploading(false);
    }
  };

  return (
    <div
      className="admin-bulk-upload animate-fade-in"
      style={{ padding: "1rem", maxWidth: "800px", margin: "0 auto" }}
    >
      <div
        style={{
          display: "flex",
          alignItems: "center",
          marginBottom: "2rem",
          gap: "1rem",
        }}
      >
        <Button
          variant="secondary"
          onClick={() => navigate("/admin")}
          style={{ padding: "0.5rem 1rem" }}
        >
          &larr; Back
        </Button>
        <h1 className="page-title" style={{ margin: 0 }}>
          Bulk Import Routes
        </h1>
      </div>

      <div style={{ marginBottom: "2rem" }}>
        <Card className="upload-instructions">
          <h3 className="section-title">Instructions</h3>
          <p>
            Upload a .xlsx file to bulk create routes. If there are any
            validation errors, the entire upload will be aborted to prevent
            partial imports.
          </p>
          <ul
            style={{
              color: "var(--text-secondary)",
              marginBottom: "1.5rem",
              lineHeight: "1.5",
            }}
          >
            <li>
              <strong>zone_name</strong>: Must perfectly match an existing zone.
            </li>
            <li>
              <strong>setter_name</strong>: Must perfectly match an active
              setter (optional).
            </li>
            <li>
              <strong>color_name</strong>: Must perfectly match an existing
              color.
            </li>
            <li>
              <strong>intended_grade</strong>: Must be valid for the zone's
              route type.
            </li>
            <li>
              <strong>set_date</strong>: YYYY-MM-DD format (optional).
            </li>
          </ul>
          <Button variant="secondary" onClick={handleDownloadTemplate}>
            Download .xlsx Template
          </Button>
        </Card>
      </div>

      <Card>
        <h3 className="section-title">Upload File</h3>
        {globalError && <div className="error-banner">{globalError}</div>}

        <div className="file-upload-container">
          <input
            type="file"
            accept=".xlsx"
            onChange={handleFileChange}
            disabled={isUploading}
            className="file-input"
          />
          <Button
            onClick={handleUpload}
            disabled={!file || isUploading}
            isLoading={isUploading}
            style={{ marginTop: "1rem" }}
            fullWidth
          >
            Upload and Process
          </Button>
        </div>
      </Card>

      {uploadResult && (
        <div style={{ marginTop: "2rem" }}>
          {uploadResult.error_count === 0 ? (
            <div className="success-card-wrapper">
              <Card>
                <h3
                  style={{
                    color: "var(--success-color)",
                    margin: "0 0 1rem 0",
                  }}
                >
                  Success!
                </h3>
                <p>Successfully processed {uploadResult.total_rows} rows.</p>
                <p>Created {uploadResult.created_count} new routes.</p>
                <Button
                  onClick={() => navigate("/")}
                  style={{ marginTop: "1rem" }}
                >
                  Go to Dashboard
                </Button>
              </Card>
            </div>
          ) : (
            <div className="error-card-wrapper">
              <Card>
                <h3
                  style={{ color: "var(--danger-color)", margin: "0 0 1rem 0" }}
                >
                  Validation Errors ({uploadResult.error_count})
                </h3>
                <p style={{ marginBottom: "1rem" }}>
                  No routes were created. Please fix the errors below and try
                  again.
                </p>

                <div className="error-table-container">
                  <table className="error-table">
                    <thead>
                      <tr>
                        <th>Row</th>
                        <th>Column</th>
                        <th>Error Message</th>
                      </tr>
                    </thead>
                    <tbody>
                      {uploadResult.errors.map((error, idx) => (
                        <tr key={idx}>
                          <td>{error.row}</td>
                          <td>
                            <code>{error.field || "-"}</code>
                          </td>
                          <td>{error.message}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </Card>
            </div>
          )}
        </div>
      )}
    </div>
  );
};
