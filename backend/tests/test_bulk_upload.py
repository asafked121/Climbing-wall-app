import pytest
import io
import openpyxl
from fastapi.testclient import TestClient

from app import security, models

from app import models

@pytest.fixture
def prepared_db(client, super_admin_cookies):
    # Create Zone
    zone_res = client.post("/admin/zones", json={"name": "Wall A", "description": "Slab", "route_type": "boulder"}, cookies=super_admin_cookies)
    assert zone_res.status_code == 201
    zone_id = zone_res.json()["id"]
    
    # Create colors
    client.post("/admin/colors", json={"name": "Red", "hex_value": "#FF0000"}, cookies=super_admin_cookies)
    client.post("/admin/colors", json={"name": "Blue", "hex_value": "#0000FF"}, cookies=super_admin_cookies)
    
    # Create setter
    client.post("/admin/setters", json={"name": "Alice", "is_active": True}, cookies=super_admin_cookies)
    
    return {"zone_id": zone_id}

def create_in_memory_excel(rows):
    wb = openpyxl.Workbook()
    ws = wb.active
    for row in rows:
        ws.append(row)
    stream = io.BytesIO()
    wb.save(stream)
    stream.seek(0)
    return stream.read()

def test_bulkTemplate_superAdmin_downloadsXlsx(client, super_admin_cookies):
    res = client.get("/admin/routes/bulk-template", cookies=super_admin_cookies)
    assert res.status_code == 200
    assert res.headers["content-type"] == "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    assert "attachment; filename=" in res.headers["content-disposition"]
    
def test_bulkUpload_nonSuperAdmin_returns403(client, admin_cookies):
    file_bytes = b"dummy"
    res = client.post("/admin/routes/bulk-upload", files={"file": ("test.xlsx", file_bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")}, cookies=admin_cookies)
    assert res.status_code == 403

def test_bulkUpload_wrongFileType_returns400(client, super_admin_cookies):
    res = client.post("/admin/routes/bulk-upload", files={"file": ("test.csv", b"dummy", "text/csv")}, cookies=super_admin_cookies)
    assert res.status_code == 400
    assert "Only .xlsx files are supported" in res.json()["detail"]

def test_bulkUpload_validFile_createsRoutes(client, super_admin_cookies, prepared_db):
    rows = [
        ["zone_name", "setter_name", "color_name", "intended_grade", "set_date"],
        ["Wall A", "Alice", "Red", "V4", "2026-03-01"],
        ["Wall A", "None", "Blue", "V5", "2026-03-02"],
    ]
    file_bytes = create_in_memory_excel(rows)
    
    res = client.post(
        "/admin/routes/bulk-upload",
        files={"file": ("upload.xlsx", file_bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
        cookies=super_admin_cookies
    )
    
    assert res.status_code == 200
    data = res.json()
    assert data["total_rows"] == 2
    assert data["created_count"] == 2
    assert data["error_count"] == 0
    assert len(data["errors"]) == 0

def test_bulkUpload_invalidZoneName_returnsRowErrors(client, super_admin_cookies, prepared_db):
    rows = [
        ["zone_name", "setter_name", "color_name", "intended_grade", "set_date"],
        ["Unknown Wall", "Alice", "Red", "V4", "2026-03-01"],
    ]
    file_bytes = create_in_memory_excel(rows)
    
    res = client.post(
        "/admin/routes/bulk-upload",
        files={"file": ("upload.xlsx", file_bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
        cookies=super_admin_cookies
    )
    
    assert res.status_code == 200
    data = res.json()
    assert data["total_rows"] == 1
    assert data["created_count"] == 0
    assert data["error_count"] == 1
    assert data["errors"][0]["field"] == "zone_name"

def test_bulkUpload_invalidGradeForZone_returnsRowErrors(client, super_admin_cookies, prepared_db):
    rows = [
        ["zone_name", "setter_name", "color_name", "intended_grade", "set_date"],
        ["Wall A", "Alice", "Red", "5.10a", "2026-03-01"], # Boulder zone, Top Rope grade
    ]
    file_bytes = create_in_memory_excel(rows)
    
    res = client.post(
        "/admin/routes/bulk-upload",
        files={"file": ("upload.xlsx", file_bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
        cookies=super_admin_cookies
    )
    
    assert res.status_code == 200
    data = res.json()
    assert data["error_count"] == 1
    assert data["errors"][0]["field"] == "intended_grade"

def test_bulkUpload_emptyFile_returnsError(client, super_admin_cookies):
    rows = [
        ["zone_name", "setter_name", "color_name", "intended_grade", "set_date"]
    ]
    file_bytes = create_in_memory_excel(rows)
    res = client.post(
        "/admin/routes/bulk-upload",
        files={"file": ("upload.xlsx", file_bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
        cookies=super_admin_cookies
    )
    assert res.status_code == 400
    assert "File is empty" in res.json()["detail"]

def test_bulkUpload_invalidHeaders_returns400(client, super_admin_cookies):
    rows = [
        ["zone_name", "WRONG_HEADER", "color_name", "intended_grade", "set_date"],
        ["Wall A", "Alice", "Red", "V4", "2026-03-01"]
    ]
    file_bytes = create_in_memory_excel(rows)
    res = client.post(
        "/admin/routes/bulk-upload",
        files={"file": ("upload.xlsx", file_bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
        cookies=super_admin_cookies
    )
    assert res.status_code == 400
    assert "Missing required columns: setter_name" in res.json()["detail"]

def test_bulkUpload_tooManyRows_returns400(client, super_admin_cookies):
    rows = [["zone_name", "setter_name", "color_name", "intended_grade", "set_date"]]
    for _ in range(501):
        rows.append(["Wall A", "Alice", "Red", "V4", "2026-03-01"])
    file_bytes = create_in_memory_excel(rows)
    res = client.post(
        "/admin/routes/bulk-upload",
        files={"file": ("upload.xlsx", file_bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
        cookies=super_admin_cookies
    )
    assert res.status_code == 400
    assert "Maximum 500 rows allowed per upload" in res.json()["detail"]
