import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import { MainLayout } from './layouts/MainLayout';
import { AuthLayout } from './layouts/AuthLayout';
import { Login } from './pages/Login';
import { Register } from './pages/Register';
import { Dashboard } from './pages/Dashboard';
import { AddRoute } from './pages/AddRoute';
import { Settings } from './pages/Settings';
import { RouteDetail } from './pages/RouteDetail';
import { AdminDashboard } from './pages/AdminDashboard';
import { AdminUsers } from './pages/admin/AdminUsers';
import { AdminSetters } from './pages/admin/AdminSetters';
import { AdminColors } from './pages/admin/AdminColors';
import { AnalyticsDashboard } from './pages/admin/AnalyticsDashboard';
import { BulkUploadRoutes } from './pages/admin/BulkUploadRoutes';
import { TermsOfService } from './pages/TermsOfService';

const ProtectedRoute = ({ children }: { children: React.ReactNode }) => {
  const { user, isLoading } = useAuth();
  if (isLoading) return <div style={{ display: 'flex', justifyContent: 'center', marginTop: '3rem' }}><span className="loader" style={{ borderColor: 'var(--text-secondary)', borderTopColor: 'var(--primary-color)' }}></span></div>;
  if (!user) return <Navigate to="/login" replace />;
  return <>{children}</>;
};

const PublicRoute = ({ children }: { children: React.ReactNode }) => {
  const { user, isLoading } = useAuth();
  if (isLoading) return <div style={{ display: 'flex', justifyContent: 'center', marginTop: '3rem' }}><span className="loader" style={{ borderColor: 'var(--text-secondary)', borderTopColor: 'var(--primary-color)' }}></span></div>;
  if (user) return <Navigate to="/" replace />;
  return <>{children}</>;
};

export const App = () => {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          {/* Public Auth Routes */}
          <Route element={<PublicRoute><AuthLayout /></PublicRoute>}>
            <Route path="/login" element={<Login />} />
            <Route path="/register" element={<Register />} />
          </Route>

          {/* Public Universal Routes */}
          <Route path="/terms" element={<TermsOfService />} />

          {/* Protected Main Routes */}
          <Route element={<ProtectedRoute><MainLayout /></ProtectedRoute>}>
            <Route path="/" element={<Dashboard />} />
            <Route path="/routes/:id" element={<RouteDetail />} />
            <Route path="/add-route" element={<AddRoute />} />
            <Route path="/settings" element={<Settings />} />
            <Route path="/admin" element={<AdminDashboard />} />
            <Route path="/admin/users" element={<AdminUsers />} />
            <Route path="/admin/setters" element={<AdminSetters />} />
            <Route path="/admin/colors" element={<AdminColors />} />
            <Route path="/admin/analytics" element={<AnalyticsDashboard />} />
            <Route path="/admin/bulk-upload" element={<BulkUploadRoutes />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
};

export default App;
