import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { Card } from '../components/Card';
import { Input } from '../components/Input';
import { Button } from '../components/Button';

export const Login: React.FC = () => {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [acceptedTos, setAcceptedTos] = useState(false);
    const [error, setError] = useState('');
    const [isLoading, setIsLoading] = useState(false);

    const { login, loginAsGuest } = useAuth();
    const navigate = useNavigate();

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();

        if (!email || !password) {
            setError('Please fill in all fields');
            return;
        }

        setError('');
        setIsLoading(true);

        try {
            await login(email, password);
            navigate('/');
        } catch (err: any) {
            setError(err.message || 'Failed to login. Please check your credentials.');
        } finally {
            setIsLoading(false);
        }
    };

    const handleGuestLogin = () => {
        if (!acceptedTos) {
            setError('You must accept the Terms of Service to continue as a guest.');
            return;
        }
        loginAsGuest();
        navigate('/');
    };

    return (
        <Card>
            <h2 style={{ marginBottom: '1.5rem', textAlign: 'center' }}>Welcome Back</h2>

            {error && (
                <div style={{
                    color: 'var(--danger-color)',
                    marginBottom: '1rem',
                    fontSize: '0.875rem',
                    textAlign: 'center',
                    background: 'rgba(239, 68, 68, 0.1)',
                    padding: '0.5rem',
                    borderRadius: 'var(--radius-sm)'
                }}>
                    {error}
                </div>
            )}

            <form onSubmit={handleSubmit}>
                <Input
                    label="Email Address"
                    type="email"
                    placeholder="climber@example.com"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    required
                />

                <Input
                    label="Password"
                    type="password"
                    placeholder="••••••••"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    required
                />

                <div style={{ marginTop: '2rem', display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                    <Button type="submit" fullWidth isLoading={isLoading}>
                        Sign In
                    </Button>

                    <div style={{ marginTop: '1rem', borderTop: '1px solid var(--border-color)', paddingTop: '1.5rem', display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                        <div style={{ display: 'flex', alignItems: 'flex-start', gap: '0.5rem' }}>
                            <input
                                type="checkbox"
                                id="tos-guest"
                                checked={acceptedTos}
                                onChange={(e) => setAcceptedTos(e.target.checked)}
                                style={{ marginTop: '0.25rem' }}
                            />
                            <label htmlFor="tos-guest" style={{ fontSize: '0.875rem', color: 'var(--text-secondary)', lineHeight: 1.4 }}>
                                I agree to the <Link to="/terms" target="_blank" rel="noopener noreferrer" style={{ color: 'var(--primary-color)' }}>Terms of Service</Link> and assume all risks of climbing to continue as a guest.
                            </label>
                        </div>
                        <Button type="button" variant="secondary" fullWidth onClick={handleGuestLogin} disabled={!acceptedTos}>
                            Continue as Guest
                        </Button>
                    </div>
                </div>
            </form>

            <div style={{ marginTop: '1.5rem', textAlign: 'center', fontSize: '0.875rem' }}>
                <span style={{ color: 'var(--text-secondary)' }}>Don't have an account? </span>
                <Link to="/register">Create one</Link>
            </div>
        </Card>
    );
};
