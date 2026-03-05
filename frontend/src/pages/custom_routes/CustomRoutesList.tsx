import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Card } from '../../components/Card';
import { Button } from '../../components/Button';
import './CustomRoutes.css';

interface CustomRoute {
    id: number;
    name: string;
    intended_grade: string;
    photo_url: string;
    author: { username: string } | null;
}

export const CustomRoutesList: React.FC = () => {
    const [routes, setRoutes] = useState<CustomRoute[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const navigate = useNavigate();

    useEffect(() => {
        fetchRoutes();
    }, []);

    const fetchRoutes = async () => {
        try {
            const token = localStorage.getItem('token');
            const response = await fetch(`${import.meta.env.VITE_API_URL || '/api'}/custom-routes/`, {
                headers: {
                    ...(token ? { 'Authorization': `Bearer ${token}` } : {})
                }
            });
            if (!response.ok) throw new Error('Failed to fetch routes');
            const data = await response.json();
            setRoutes(data);
        } catch (err: any) {
            setError(err.message);
        } finally {
            setLoading(false);
        }
    };

    if (loading) return <div className="loader-container"><span className="loader"></span></div>;

    return (
        <div className="custom-routes-container fade-in">
            <div className="page-header">
                <h2>Community Routes</h2>
                <Button onClick={() => navigate('/community/add')}>Post Route</Button>
            </div>

            {error && <div className="error-message">{error}</div>}

            <div className="community-routes-grid">
                {routes.map(route => (
                    <Card key={route.id} className="community-route-card" onClick={() => navigate(`/community/${route.id}`)}>
                        <div className="community-route-image-container">
                            <img src={`${import.meta.env.VITE_API_URL || '/api'}${route.photo_url}`} alt={route.name} className="community-route-thumbnail" />
                        </div>
                        <div className="community-route-info">
                            <h3 className="community-route-name">{route.name}</h3>
                            <div className="community-route-tags">
                                <span className="community-grade-tag">{route.intended_grade}</span>
                            </div>
                            <p className="community-author-text">By {route.author?.username || 'Unknown'}</p>
                        </div>
                    </Card>
                ))}
            </div>
            {routes.length === 0 && !error && (
                <div className="empty-state">
                    <p>No community routes yet. Be the first to post one!</p>
                </div>
            )}
        </div>
    );
};
