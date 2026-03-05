import React from 'react';
import { Outlet } from 'react-router-dom';
import './AuthLayout.css';

export const AuthLayout: React.FC = () => {
    return (
        <div className="auth-layout">
            <main className="auth-content animate-fade-in">
                <div className="auth-logo">🧗 ClimbApp</div>
                <Outlet />
            </main>
        </div>
    );
};
