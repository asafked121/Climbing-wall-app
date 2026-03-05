import React, { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Card } from '../../components/Card';
import { Button } from '../../components/Button';
import './CustomRoutes.css';

interface Hold {
    id: string;
    x: number;
    y: number;
    radius: number;
}

interface CustomRouteDetail {
    id: number;
    name: string;
    intended_grade: string;
    photo_url: string;
    holds: string;
    author: { username: string } | null;
    custom_grade_votes: any[];
    custom_comments: { id: number, content: string, user: { username: string }, created_at: string }[];
}

export const CustomRouteDetail: React.FC = () => {
    const { id } = useParams<{ id: string }>();
    const [route, setRoute] = useState<CustomRouteDetail | null>(null);
    const [holds, setHolds] = useState<Hold[]>([]);

    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    const [commentText, setCommentText] = useState('');
    const [votedGrade, setVotedGrade] = useState('');

    const navigate = useNavigate();

    const canvasRef = useRef<HTMLCanvasElement>(null);
    const imageRef = useRef<HTMLImageElement>(null);

    useEffect(() => {
        fetchRoute();
    }, [id]);

    const fetchRoute = async () => {
        try {
            const token = localStorage.getItem('token');
            const response = await fetch(`${import.meta.env.VITE_API_URL || '/api'}/custom-routes/${id}`, {
                headers: {
                    ...(token ? { 'Authorization': `Bearer ${token}` } : {})
                }
            });
            if (!response.ok) {
                if (response.status === 404) {
                    navigate('/community');
                    return;
                }
                throw new Error('Failed to fetch custom route');
            }
            const data = await response.json();
            setRoute(data);
            setHolds(JSON.parse(data.holds || '[]'));
        } catch (err: any) {
            setError(err.message);
        } finally {
            setLoading(false);
        }
    };

    const drawCanvas = () => {
        const canvas = canvasRef.current;
        const img = imageRef.current;
        if (!canvas || !img || !holds.length) return;

        const ctx = canvas.getContext('2d');
        if (!ctx) return;

        canvas.width = img.clientWidth;
        canvas.height = img.clientHeight;
        ctx.clearRect(0, 0, canvas.width, canvas.height);

        const scaleX = canvas.width / img.naturalWidth;
        const scaleY = canvas.height / img.naturalHeight;

        holds.forEach(hold => {
            const cx = hold.x * scaleX;
            const cy = hold.y * scaleY;
            const radius = Math.max(hold.radius * Math.max(scaleX, Math.min(scaleX, scaleY)), 10);

            ctx.beginPath();
            ctx.arc(cx, cy, radius, 0, 2 * Math.PI);
            ctx.lineWidth = 3;
            // Draw all holds with strong visual style since they are part of the route
            ctx.strokeStyle = '#34c759';
            ctx.fillStyle = 'rgba(52, 199, 89, 0.4)';
            ctx.fill();
            ctx.stroke();
        });
    };

    useEffect(() => {
        if (!loading && route) {
            setTimeout(drawCanvas, 100);
        }
    }, [loading, route, holds]);

    useEffect(() => {
        window.addEventListener('resize', drawCanvas);
        return () => window.removeEventListener('resize', drawCanvas);
    }, [holds]);

    const handleVote = async () => {
        if (!votedGrade) return;
        try {
            const token = localStorage.getItem('token');
            await fetch(`${import.meta.env.VITE_API_URL || '/api'}/custom-routes/${id}/vote`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    ...(token ? { 'Authorization': `Bearer ${token}` } : {})
                },
                body: JSON.stringify({ voted_grade: votedGrade })
            });
            fetchRoute();
        } catch (err) {
            console.error('Failed to vote', err);
        }
    };

    const handleComment = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!commentText.trim()) return;

        try {
            const token = localStorage.getItem('token');
            await fetch(`${import.meta.env.VITE_API_URL || '/api'}/custom-routes/${id}/comment`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    ...(token ? { 'Authorization': `Bearer ${token}` } : {})
                },
                body: JSON.stringify({ content: commentText.trim() })
            });
            setCommentText('');
            fetchRoute();
        } catch (err) {
            console.error('Failed to post comment', err);
        }
    };

    if (loading) return <div className="loader-container"><span className="loader"></span></div>;
    if (error || !route) return <div className="error-message">{error || 'Route not found'}</div>;

    // Calculate consensus grade based on votes
    const votes = route.custom_grade_votes;
    const gradeCounts = votes.reduce((acc: Record<string, number>, vote: any) => {
        acc[vote.voted_grade] = (acc[vote.voted_grade] || 0) + 1;
        return acc;
    }, {});
    const consensusGrade = Object.keys(gradeCounts).reduce((a, b) => gradeCounts[a] > gradeCounts[b] ? a : b, route.intended_grade);


    return (
        <div className="custom-route-detail-container fade-in">
            <div className="detail-header">
                <h2>{route.name}</h2>
                <span className="community-grade-tag large">{consensusGrade}</span>
            </div>

            <p className="community-author-text">Posted by {route.author?.username || 'Unknown'} • Intended: {route.intended_grade}</p>

            <Card className="photo-card">
                <div className="canvas-container">
                    <img
                        ref={imageRef}
                        src={`${import.meta.env.VITE_API_URL || '/api'}${route.photo_url}`}
                        alt={route.name}
                        className="wall-image"
                        onLoad={drawCanvas}
                    />
                    <canvas ref={canvasRef} className="holds-canvas" />
                </div>
            </Card>

            <div className="interaction-section">
                <Card className="voting-card">
                    <h3>Community Grade</h3>
                    <div className="voting-controls">
                        <select
                            className="input-field"
                            style={{ width: 'auto' }}
                            value={votedGrade}
                            onChange={(e) => setVotedGrade(e.target.value)}
                        >
                            <option value="">Select Grade</option>
                            {['V0', 'V1', 'V2', 'V3', 'V4', 'V5', 'V6', 'V7', 'V8', 'V9', 'V10'].map(grade => (
                                <option key={grade} value={grade}>{grade}</option>
                            ))}
                        </select>
                        <Button onClick={handleVote} disabled={!votedGrade}>Vote</Button>
                    </div>
                </Card>

                <Card className="comments-card">
                    <h3>Comments</h3>
                    <div className="comments-list">
                        {route.custom_comments.length === 0 ? (
                            <p className="empty-state">No comments yet.</p>
                        ) : (
                            route.custom_comments.map(c => (
                                <div key={c.id} className="comment-item">
                                    <strong>{c.user?.username}</strong>
                                    <p>{c.content}</p>
                                </div>
                            ))
                        )}
                    </div>

                    <form onSubmit={handleComment} className="comment-form">
                        <input
                            type="text"
                            className="input-field"
                            placeholder="Add a comment..."
                            value={commentText}
                            onChange={(e) => setCommentText(e.target.value)}
                        />
                        <Button type="submit" disabled={!commentText.trim()}>Post</Button>
                    </form>
                </Card>
            </div>
        </div>
    );
};
