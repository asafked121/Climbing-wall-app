import React from 'react';
import { Outlet, NavLink } from 'react-router-dom';
import './MainLayout.css';
import { useAuth } from '../context/AuthContext';

export const MainLayout: React.FC = () => {
    const { user } = useAuth();

    return (
        <div className="main-layout">
            <aside className="desktop-sidebar glass">
                <div className="sidebar-header">
                    <div className="sidebar-logo">🧗 ClimbApp</div>
                    {user && <div className="sidebar-user">{user.username}</div>}
                </div>
                <nav className="sidebar-nav">
                    <NavLink to="/" className={({ isActive }) => `sidebar-nav-item ${isActive ? 'active' : ''}`}>
                        <span className="nav-icon">🏠</span>
                        <span className="nav-text">Home</span>
                    </NavLink>
                    <NavLink to="/community" className={({ isActive }) => `sidebar-nav-item ${isActive ? 'active' : ''}`}>
                        <span className="nav-icon">🌍</span>
                        <span className="nav-text">Community</span>
                    </NavLink>
                    {user && (user.role === 'admin' || user.role === 'setter' || user.role === 'super_admin') && (
                        <NavLink to="/add-route" className={({ isActive }) => `sidebar-nav-item ${isActive ? 'active' : ''}`}>
                            <span className="nav-icon">➕</span>
                            <span className="nav-text">Add Route</span>
                        </NavLink>
                    )}
                    <NavLink to="/settings" className={({ isActive }) => `sidebar-nav-item ${isActive ? 'active' : ''}`}>
                        <span className="nav-icon">⚙️</span>
                        <span className="nav-text">Settings</span>
                    </NavLink>
                    {user && (user.role === 'admin' || user.role === 'super_admin') && (
                        <NavLink to="/admin/analytics" className={({ isActive }) => `sidebar-nav-item ${isActive ? 'active' : ''}`}>
                            <span className="nav-icon">📊</span>
                            <span className="nav-text">Wall Analytics</span>
                        </NavLink>
                    )}
                </nav>
            </aside>

            <header className="mobile-header glass">
                <div className="header-logo">🧗 ClimbApp</div>
                {user && <div className="header-user">{user.username}</div>}
            </header>

            <main className="main-content">
                <Outlet />
            </main>

            <nav className="bottom-nav glass">
                <NavLink to="/" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
                    <span className="nav-icon">🏠</span>
                    <span className="nav-text">Home</span>
                </NavLink>
                <NavLink to="/community" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
                    <span className="nav-icon">🌍</span>
                    <span className="nav-text">Community</span>
                </NavLink>
                {user && (user.role === 'admin' || user.role === 'setter') && (
                    <NavLink to="/add-route" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
                        <span className="nav-icon">➕</span>
                        <span className="nav-text">Add Route</span>
                    </NavLink>
                )}
                <NavLink to="/settings" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
                    <span className="nav-icon">⚙️</span>
                    <span className="nav-text">Settings</span>
                </NavLink>
                {user && (user.role === 'admin' || user.role === 'super_admin') && (
                    <NavLink to="/admin/analytics" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
                        <span className="nav-icon">📊</span>
                        <span className="nav-text">Analytics</span>
                    </NavLink>
                )}
            </nav>
        </div>
    );
};
