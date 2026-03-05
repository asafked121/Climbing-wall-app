import React, { useState, useEffect } from 'react';
import { api } from '../../api';
import { useAuth } from '../../context/AuthContext';
import { Card } from '../../components/Card';
import { Button } from '../../components/Button';
import { Input } from '../../components/Input';
import { Navigate, useNavigate } from 'react-router-dom';

interface Color { id: number; name: string; hex_value: string; }

export const AdminColors: React.FC = () => {
    const { user } = useAuth();
    const navigate = useNavigate();
    const [colors, setColors] = useState<Color[]>([]);
    const [newColorName, setNewColorName] = useState('');
    const [newColorHex, setNewColorHex] = useState('#000000');
    const [isLoadingColors, setIsLoadingColors] = useState(false);
    const [error, setError] = useState('');

    const fetchColors = async () => {
        try { const data = await api.get<Color[]>('/routes/colors'); setColors(data); } catch (err) { console.error(err); }
    };

    useEffect(() => {
        fetchColors();
    }, []);

    const handleAddColor = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!newColorName.trim()) { setError('Color name is required'); return; }
        setIsLoadingColors(true); setError('');
        try {
            await api.post('/admin/colors', { name: newColorName.trim(), hex_value: newColorHex });
            setNewColorName(''); fetchColors();
        } catch (err: any) { setError(err.message || 'Failed to add color'); } finally { setIsLoadingColors(false); }
    };

    const handleDeleteColor = async (colorId: number) => {
        if (!window.confirm('Are you sure you want to delete this color?')) return;
        try { await api.delete(`/admin/colors/${colorId}`); fetchColors(); } catch (err: any) { setError(err.message || 'Failed to delete color'); }
    };

    if (!user || (user.role !== 'admin' && user.role !== 'super_admin')) {
        return <Navigate to="/" replace />;
    }

    return (
        <div className="admin-dashboard animate-fade-in" style={{ padding: '1rem' }}>
            <Button onClick={() => navigate('/admin')} variant="secondary" style={{ marginBottom: '1rem', width: 'fit-content' }}>
                ← Back to Dashboard
            </Button>

            <h1 className="page-title">Manage Hold Colors</h1>
            {error && <div className="error-banner" style={{ color: 'var(--error-color)', marginBottom: '1rem' }}>{error}</div>}

            <Card>
                <p style={{ color: 'var(--text-secondary)', marginBottom: '1.5rem', fontSize: '0.9rem' }}>
                    Add or remove colors available to setters when creating new routes.
                </p>
                <form onSubmit={handleAddColor} style={{ display: 'flex', gap: '1rem', alignItems: 'flex-end', marginBottom: '2rem', flexWrap: 'wrap' }}>
                    <div style={{ flex: 1, minWidth: '150px' }}>
                        <label className="input-label">Color Name</label>
                        <Input
                            placeholder="e.g. Neon Green"
                            value={newColorName}
                            onChange={(e) => setNewColorName(e.target.value)}
                            style={{ margin: 0 }}
                        />
                    </div>
                    <div style={{ width: '100px' }}>
                        <label className="input-label">Hex Value</label>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                            <input
                                type="color"
                                value={newColorHex}
                                onChange={(e) => setNewColorHex(e.target.value)}
                                style={{ width: '40px', height: '40px', border: 'none', borderRadius: '50%', cursor: 'pointer', backgroundColor: 'transparent' }}
                            />
                        </div>
                    </div>
                    <Button type="submit" isLoading={isLoadingColors} style={{ marginBottom: '2px' }}>
                        Add Color
                    </Button>
                </form>

                <div className="ios-list-container">
                    {colors.map((color, index) => (
                        <div key={color.id} className={`ios-list-item ${index === colors.length - 1 ? 'last-item' : ''}`}>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                                <div
                                    style={{
                                        width: '24px',
                                        height: '24px',
                                        borderRadius: '50%',
                                        backgroundColor: color.hex_value,
                                        border: '1px solid var(--border-color)',
                                        flexShrink: 0
                                    }}
                                />
                                <div>
                                    <div className="ios-list-grade" style={{ color: 'var(--text-primary)' }}>{color.name}</div>
                                    <div className="ios-list-count">{color.hex_value}</div>
                                </div>
                            </div>
                            <Button
                                variant="danger"
                                style={{ padding: '0.4rem 0.8rem', fontSize: '0.8rem' }}
                                onClick={() => handleDeleteColor(color.id)}
                            >
                                Remove
                            </Button>
                        </div>
                    ))}
                    {colors.length === 0 && (
                        <div className="ios-list-item last-item">
                            <span className="ios-list-count">No colors configured.</span>
                        </div>
                    )}
                </div>
            </Card>
        </div>
    );
};
