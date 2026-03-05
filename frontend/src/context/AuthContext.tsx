import React, { createContext, useContext, useState, useEffect, type ReactNode } from 'react';
import { api } from '../api';

export interface User {
    id: number;
    email: string;
    username: string;
    role: 'admin' | 'super_admin' | 'setter' | 'student' | 'guest';
}

interface AuthContextType {
    user: User | null;
    isLoading: boolean;
    login: (email: string, password: string) => Promise<void>;
    register: (email: string, password: string, username?: string, date_of_birth?: string) => Promise<void>;
    loginAsGuest: () => void;
    logout: () => Promise<void>;
    fetchUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
    const [user, setUser] = useState<User | null>(null);
    const [isLoading, setIsLoading] = useState(true);

    const fetchUser = async () => {
        try {
            const userData = await api.get<User>('/auth/me');
            setUser(userData);
        } catch (error) {
            setUser(null);
        } finally {
            setIsLoading(false);
        }
    };

    // Check auth on mount
    useEffect(() => {
        fetchUser();
    }, []);

    const login = async (email: string, password: string) => {
        await api.post('/auth/login', { email, password });
        const userData = await api.get<User>('/auth/me');
        setUser(userData);
    };

    const register = async (email: string, password: string, username?: string, date_of_birth?: string) => {
        await api.post('/auth/register', { email, password, username, role: 'student', date_of_birth });
        await login(email, password);
    };

    const loginAsGuest = () => {
        setUser({
            id: 0,
            email: 'guest@climbapp.local',
            username: 'Guest',
            role: 'guest'
        });
    };

    const logout = async () => {
        try {
            await api.post('/auth/logout');
        } catch (e) {
            // Ignore errors on logout network failures, simply clear local state
        } finally {
            setUser(null);
        }
    };

    return (
        <AuthContext.Provider value={{ user, isLoading, login, register, loginAsGuest, logout, fetchUser }}>
            {children}
        </AuthContext.Provider>
    );
};

export const useAuth = () => {
    const context = useContext(AuthContext);
    if (context === undefined) {
        throw new Error('useAuth must be used within an AuthProvider');
    }
    return context;
};
