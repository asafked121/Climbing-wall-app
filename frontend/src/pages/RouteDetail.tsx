import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { api } from '../api';
import { useAuth } from '../context/AuthContext';
import { Card } from '../components/Card';
import { Button } from '../components/Button';
import { Input } from '../components/Input';
import { sanitizeHtml } from '../utils/sanitize'; // We'll create this to satisfy security rules
import './RouteDetail.css';

interface UserResponse {
    id: number;
    email: string;
    username: string;
    role: string;
}

interface GradeVote {
    id: number;
    user_id: number;
    route_id: number;
    voted_grade: string;
}

interface Comment {
    id: number;
    user_id: number;
    route_id: number;
    content: string;
    created_at: string;
    user?: UserResponse;
}

interface RouteRating {
    id: number;
    user_id: number;
    route_id: number;
    rating: number;
}

interface Ascent {
    id: number;
    user_id: number;
    route_id: number;
    ascent_type: string;
    date: string;
}

interface RouteDetail {
    id: number;
    zone_id: number;
    color: string;
    color_name: string | null;
    intended_grade: string;
    status: string;
    set_date: string;
    photo_url: string | null;
    setter: {
        id: number;
        name: string;
        is_active: boolean;
    } | null;
    zone: {
        id: number;
        name: string;
        route_type: string;
    } | null;
    grade_votes: GradeVote[];
    comments: Comment[];
    route_ratings: RouteRating[];
    ascents: Ascent[];
}

interface Zone { id: number; name: string; route_type: string; }
interface Setter { id: number; name: string; }
interface Color { id: number; name: string; hex_value: string; }

export const RouteDetail: React.FC = () => {
    const { id } = useParams<{ id: string }>();
    const navigate = useNavigate();
    const { user } = useAuth();

    const [route, setRoute] = useState<RouteDetail | null>(null);
    const [isLoading, setIsLoading] = useState(true);
    const [error, setError] = useState('');

    // Interaction forms
    const [newComment, setNewComment] = useState('');
    const [votedGrade, setVotedGrade] = useState('');
    const [grades, setGrades] = useState<string[]>([]);
    const [rating, setRating] = useState<number>(0);
    const [isSubmitting, setIsSubmitting] = useState(false);

    const isGuest = user?.role === 'guest';
    const canManageRoutes = user?.role === 'admin' || user?.role === 'super_admin' || user?.role === 'setter';

    // Edit mode state
    const [isEditing, setIsEditing] = useState(false);
    const [editZoneId, setEditZoneId] = useState<number | ''>('');
    const [editColor, setEditColor] = useState('');
    const [editGrade, setEditGrade] = useState('');
    const [editSetterId, setEditSetterId] = useState<number | ''>('');
    const [editSetDate, setEditSetDate] = useState('');
    const [editStatus, setEditStatus] = useState('');
    const [editPhotoFile, setEditPhotoFile] = useState<File | null>(null);
    const [editGrades, setEditGrades] = useState<string[]>([]);
    const [editError, setEditError] = useState('');

    // Edit form options
    const [zones, setZones] = useState<Zone[]>([]);
    const [setters, setSetters] = useState<Setter[]>([]);
    const [colors, setColors] = useState<Color[]>([]);

    const fetchRouteDetail = async (showLoader = true) => {
        try {
            if (showLoader) setIsLoading(true);
            const data = await api.get<RouteDetail>(`/routes/${id}`);
            setRoute(data);
        } catch (err: any) {
            setError('Failed to load route details.');
        } finally {
            if (showLoader) setIsLoading(false);
        }
    };

    useEffect(() => {
        fetchRouteDetail();
    }, [id]);

    useEffect(() => {
        if (route?.zone_id) {
            const fetchGrades = async () => {
                try {
                    const gradesData = await api.get<string[]>(`/routes/grades?zone_id=${route.zone_id}`);
                    setGrades(gradesData);
                } catch (err) {
                    console.error('Failed to fetch grades for zone', err);
                }
            };
            fetchGrades();
        }
    }, [route?.zone_id]);

    // Fetch edit form options when edit mode is entered
    useEffect(() => {
        if (!isEditing || !canManageRoutes) return;
        const fetchEditData = async () => {
            try {
                const [zonesData, settersData, colorsData] = await Promise.all([
                    api.get<Zone[]>('/routes/zones'),
                    api.get<Setter[]>('/admin/setters'),
                    api.get<Color[]>('/routes/colors')
                ]);
                setZones(zonesData);
                setSetters(settersData);
                setColors(colorsData);
            } catch (err) {
                console.error('Failed to fetch edit form data', err);
            }
        };
        fetchEditData();
    }, [isEditing, canManageRoutes]);

    // Fetch grades for the selected edit zone
    useEffect(() => {
        if (!isEditing || editZoneId === '') return;
        const fetchEditGrades = async () => {
            try {
                const gradesData = await api.get<string[]>(`/routes/grades?zone_id=${editZoneId}`);
                setEditGrades(gradesData);
            } catch (err) {
                console.error('Failed to fetch grades for zone', err);
            }
        };
        fetchEditGrades();
    }, [isEditing, editZoneId]);

    const startEditing = () => {
        if (!route) return;
        setEditZoneId(route.zone_id);
        setEditColor(route.color);
        setEditGrade(route.intended_grade);
        setEditSetterId(route.setter?.id ?? '');
        setEditSetDate(route.set_date ? route.set_date.split('T')[0] : '');
        setEditStatus(route.status);
        setEditPhotoFile(null);
        setEditError('');
        setIsEditing(true);
    };

    const handleEditSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!route) return;
        setEditError('');
        try {
            setIsSubmitting(true);
            const updatePayload: Record<string, any> = {};
            if (editZoneId !== '' && editZoneId !== route.zone_id) updatePayload.zone_id = editZoneId;
            if (editColor && editColor !== route.color) updatePayload.color = editColor;
            if (editGrade && editGrade !== route.intended_grade) updatePayload.intended_grade = editGrade;
            if (editSetterId !== '' && editSetterId !== route.setter?.id) updatePayload.setter_id = editSetterId;
            if (editSetDate && editSetDate !== route.set_date?.split('T')[0]) updatePayload.set_date = editSetDate;
            if (editStatus && editStatus !== route.status) updatePayload.status = editStatus;

            if (Object.keys(updatePayload).length > 0) {
                await api.patch(`/admin/routes/${route.id}`, updatePayload);
            }
            if (editPhotoFile) {
                const formData = new FormData();
                formData.append('file', editPhotoFile);
                await api.postFormData(`/routes/${route.id}/photo`, formData);
            }
            setIsEditing(false);
            await fetchRouteDetail(false);
        } catch (err: any) {
            setEditError(err.message || 'Failed to update route.');
        } finally {
            setIsSubmitting(false);
        }
    };

    const handleToggleArchive = async () => {
        if (!route) return;
        const newStatus = route.status === 'archived' ? 'active' : 'archived';
        try {
            setIsSubmitting(true);
            await api.patch(`/admin/routes/${route.id}/archive`, { status: newStatus });
            await fetchRouteDetail(false);
        } catch (err: any) {
            console.error('Failed to toggle archive', err);
        } finally {
            setIsSubmitting(false);
        }
    };

    const handleCommentSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!newComment.trim() || isGuest) return;

        try {
            setIsSubmitting(true);
            await api.post(`/routes/${id}/comments`, { content: newComment });
            setNewComment('');
            await fetchRouteDetail(false); // Refresh data
        } catch (err: any) {
            console.error('Failed to post comment', err);
        } finally {
            setIsSubmitting(false);
        }
    };

    const handleVoteSubmit = async () => {
        if (!votedGrade || isGuest) return;

        try {
            setIsSubmitting(true);
            await api.post(`/routes/${id}/votes`, { voted_grade: votedGrade });
            setVotedGrade('');
            await fetchRouteDetail(false);
        } catch (err: any) {
            console.error('Failed to submit vote', err);
        } finally {
            setIsSubmitting(false);
        }
    };

    const handleRatingSubmit = async (selectedRating: number) => {
        if (isGuest) return;
        try {
            setIsSubmitting(true);
            await api.post(`/routes/${id}/ratings`, { rating: selectedRating });
            setRating(selectedRating);
            await fetchRouteDetail(false);
        } catch (err: any) {
            console.error('Failed to submit rating', err);
        } finally {
            setIsSubmitting(false);
        }
    };

    const handleLogAscent = async (ascentType: string) => {
        if (isGuest) return;
        try {
            setIsSubmitting(true);
            await api.post(`/routes/${id}/ascents`, { ascent_type: ascentType });
            await fetchRouteDetail(false);
        } catch (err: any) {
            console.error('Failed to log ascent', err);
        } finally {
            setIsSubmitting(false);
        }
    };

    const handleUnlogAscent = async (ascentType: string) => {
        if (isGuest || !user || !route) return;
        const ascentRecord = route.ascents.find(a => a.user_id === user.id && a.ascent_type === ascentType);
        if (!ascentRecord) return;

        try {
            setIsSubmitting(true);
            await api.delete(`/routes/ascents/${ascentRecord.id}`);
            await fetchRouteDetail(false);
        } catch (err: any) {
            console.error('Failed to unlog ascent', err);
        } finally {
            setIsSubmitting(false);
        }
    };

    if (isLoading) {
        return (
            <div style={{ display: 'flex', justifyContent: 'center', padding: '3rem' }}>
                <span className="loader" style={{ borderColor: 'var(--border-color)', borderTopColor: 'var(--primary-color)' }}></span>
            </div>
        );
    }

    if (error || !route) {
        return (
            <div style={{ textAlign: 'center', padding: '3rem' }}>
                <div style={{ color: 'var(--danger-color)', marginBottom: '1rem' }}>{error || 'Route not found'}</div>
                <Button onClick={() => navigate(-1)} variant="secondary">Go Back</Button>
            </div>
        );
    }

    // Calculations
    const avgRating = route.route_ratings.length > 0
        ? (route.route_ratings.reduce((acc, r) => acc + r.rating, 0) / route.route_ratings.length).toFixed(1)
        : 'No ratings yet';
    // Ascent Counts
    const boulderAscents = route.ascents.filter(a => a.ascent_type === 'boulder').length;
    const topRopeAscents = route.ascents.filter(a => a.ascent_type === 'top_rope').length;
    const leadAscents = route.ascents.filter(a => a.ascent_type === 'lead').length;

    const hasLoggedAscent = (type: string) => {
        if (!user) return false;
        return route.ascents.some(a => a.user_id === user.id && a.ascent_type === type);
    };

    const isLeadAllowed = [4, 7, 9].includes(route.zone_id);

    const currentUserVote = user ? route.grade_votes.find(v => v.user_id === user.id) : null;

    return (
        <div className="route-detail-page animate-fade-in">
            <div className="detail-top-bar">
                <Button onClick={() => navigate(-1)} variant="secondary" style={{ width: 'fit-content' }}>
                    ← Back
                </Button>
                {canManageRoutes && !isEditing && (
                    <div className="manage-buttons">
                        <Button onClick={startEditing} variant="primary" style={{ width: 'fit-content' }}>✏️ Edit</Button>
                        <Button
                            onClick={handleToggleArchive}
                            variant={route.status === 'archived' ? 'primary' : 'danger'}
                            disabled={isSubmitting}
                            style={{ width: 'fit-content' }}
                        >
                            {route.status === 'archived' ? '📦 Unarchive' : '📦 Archive'}
                        </Button>
                    </div>
                )}
            </div>

            {/* Edit Form */}
            {isEditing && canManageRoutes && (
                <Card className="edit-route-card">
                    <h3 className="section-title">Edit Route</h3>
                    {editError && <div className="error-banner" style={{ color: 'var(--error-color)', marginBottom: '1rem' }}>{editError}</div>}
                    <form onSubmit={handleEditSubmit} className="edit-route-form">
                        <div className="edit-form-grid">
                            <div className="input-group">
                                <label className="input-label">Zone</label>
                                <select className="input-field" value={editZoneId} onChange={e => setEditZoneId(Number(e.target.value) || '')}>
                                    <option value="">Select Zone</option>
                                    {zones.map(z => <option key={z.id} value={z.id}>{z.name} ({z.route_type})</option>)}
                                </select>
                            </div>
                            <div className="input-group">
                                <label className="input-label">Grade</label>
                                <select className="input-field" value={editGrade} onChange={e => setEditGrade(e.target.value)} disabled={editGrades.length === 0}>
                                    {editGrades.map(g => <option key={g} value={g}>{g}</option>)}
                                </select>
                            </div>
                            <div className="input-group">
                                <label className="input-label">Hold Color</label>
                                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                                    <select className="input-field" value={editColor} onChange={e => setEditColor(e.target.value)} style={{ flex: 1, margin: 0 }}>
                                        {colors.map(c => <option key={c.id} value={c.hex_value}>{c.name}</option>)}
                                    </select>
                                    <div style={{ width: '28px', height: '28px', borderRadius: '50%', backgroundColor: editColor, border: '1px solid var(--border-color)', flexShrink: 0 }} />
                                </div>
                            </div>
                            <div className="input-group">
                                <label className="input-label">Setter</label>
                                <select className="input-field" value={editSetterId} onChange={e => setEditSetterId(Number(e.target.value) || '')}>
                                    <option value="">Select Setter</option>
                                    {setters.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
                                </select>
                            </div>
                            <div className="input-group">
                                <label className="input-label">Set Date</label>
                                <input type="date" className="input-field" value={editSetDate} onChange={e => setEditSetDate(e.target.value)} />
                            </div>
                            <div className="input-group">
                                <label className="input-label">Status</label>
                                <select className="input-field" value={editStatus} onChange={e => setEditStatus(e.target.value)}>
                                    <option value="active">Active</option>
                                    <option value="archived">Archived</option>
                                </select>
                            </div>
                            <div className="input-group">
                                <label className="input-label">Update Photo (Optional)</label>
                                <input
                                    type="file"
                                    className="input-field"
                                    accept="image/*"
                                    onChange={e => setEditPhotoFile(e.target.files?.[0] || null)}
                                    style={{ padding: '0.4rem' }}
                                />
                            </div>
                        </div>
                        <div className="edit-form-actions">
                            <Button type="submit" variant="primary" isLoading={isSubmitting}>Save Changes</Button>
                            <Button type="button" variant="secondary" onClick={() => setIsEditing(false)}>Cancel</Button>
                        </div>
                    </form>
                </Card>
            )}

            {/* Main Info Card */}
            <Card className="detail-card">
                {route.photo_url && (
                    <div className="route-photo-container" style={{ margin: '-1.5rem -1.5rem 1rem -1.5rem', overflow: 'hidden', borderTopLeftRadius: 'var(--radius)', borderTopRightRadius: 'var(--radius)' }}>
                        <img
                            src={`${import.meta.env.VITE_API_URL || '/api'}${route.photo_url}`}
                            alt={`${route.color_name || route.color} Route`}
                            style={{ width: '100%', height: 'auto', maxHeight: '400px', objectFit: 'cover', display: 'block' }}
                        />
                    </div>
                )}

                <div className="detail-color-strip" style={{ backgroundColor: route.color || 'var(--primary-color)' }} />

                <div className="detail-header">
                    <h1 className="detail-title">{(route.color_name || route.color).charAt(0).toUpperCase() + (route.color_name || route.color).slice(1)} Route in {route.zone?.name || 'Unknown Zone'}</h1>
                    <span className="detail-grade">{route.intended_grade}</span>
                </div>

                <div className="detail-meta">
                    <p><strong>Setter:</strong> {route.setter?.name || 'Unknown'}</p>
                    <p><strong>Set Date:</strong> {new Date(route.set_date).toLocaleDateString()}</p>
                    <p><strong>Status:</strong> <span style={{ textTransform: 'capitalize' }}>{route.status}</span></p>
                    <p><strong>Community Rating:</strong> ⭐ {avgRating} ({route.route_ratings.length} ratings)</p>
                    {route.zone?.route_type === 'boulder' ? (
                        <p><strong>Total Ascents:</strong> {boulderAscents}</p>
                    ) : (
                        <p><strong>Ascents:</strong> {topRopeAscents} Top Rope {isLeadAllowed && `/ ${leadAscents} Lead`}</p>
                    )}
                </div>
            </Card>

            {/* Actions Section (Hidden for Guests) */}
            {!isGuest && (
                <div className="actions-section">
                    <Card>
                        <h3 className="section-title">Rate this route</h3>
                        <div className="star-rating">
                            {[1, 2, 3, 4, 5].map(star => (
                                <span
                                    key={star}
                                    className={`star ${rating >= star ? 'filled' : ''}`}
                                    onClick={() => handleRatingSubmit(star)}
                                >
                                    ★
                                </span>
                            ))}
                        </div>

                        <h3 className="section-title" style={{ marginTop: '1.5rem' }}>Vote on Grade</h3>
                        {currentUserVote && (
                            <p style={{ marginBottom: '1rem', color: 'var(--text-secondary)' }}>
                                You voted: <strong>{currentUserVote.voted_grade}</strong>
                            </p>
                        )}
                        <div className="vote-group">
                            <select
                                className="input-field"
                                value={votedGrade}
                                onChange={e => setVotedGrade(e.target.value)}
                                style={{ margin: 0, flex: 1, padding: '0.5rem' }}
                                disabled={grades.length === 0}
                            >
                                <option value="">Select Grade</option>
                                {grades.map(g => (
                                    <option key={g} value={g}>{g}</option>
                                ))}
                            </select>
                            <Button onClick={handleVoteSubmit} disabled={isSubmitting || !votedGrade}>
                                {currentUserVote ? 'Change Vote' : 'Vote'}
                            </Button>
                        </div>

                        <h3 className="section-title" style={{ marginTop: '1.5rem' }}>Log Ascent</h3>
                        <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                            {route.zone?.route_type === 'boulder' ? (
                                hasLoggedAscent('boulder') ? (
                                    <Button variant="secondary" onClick={() => handleUnlogAscent('boulder')} disabled={isSubmitting}>Unlog Boulder</Button>
                                ) : (
                                    <Button variant="primary" onClick={() => handleLogAscent('boulder')} disabled={isSubmitting}>Log Boulder</Button>
                                )
                            ) : (
                                <>
                                    {hasLoggedAscent('top_rope') ? (
                                        <Button variant="secondary" onClick={() => handleUnlogAscent('top_rope')} disabled={isSubmitting}>Unlog Top Rope</Button>
                                    ) : (
                                        <Button variant="primary" onClick={() => handleLogAscent('top_rope')} disabled={isSubmitting}>Log Top Rope</Button>
                                    )}
                                    {isLeadAllowed && (
                                        hasLoggedAscent('lead') ? (
                                            <Button variant="secondary" onClick={() => handleUnlogAscent('lead')} disabled={isSubmitting}>Unlog Lead</Button>
                                        ) : (
                                            <Button variant="primary" onClick={() => handleLogAscent('lead')} disabled={isSubmitting}>Log Lead</Button>
                                        )
                                    )}
                                </>
                            )}
                        </div>
                    </Card>
                </div>
            )}

            {/* Interactions Read-Only Lists */}
            <div className="interactions-grid">

                {/* Grade Votes */}
                <Card>
                    <h3 className="section-title">Community Consensus</h3>
                    {route.grade_votes.length === 0 ? (
                        <p className="empty-text">No votes yet.</p>
                    ) : (
                        <div className="consensus-bar-container" style={{ padding: '0.5rem 0' }}>
                            {/* Group votes by grade and sort by most popular */}
                            {(() => {
                                const voteCounts = route.grade_votes.reduce((acc, v) => {
                                    acc[v.voted_grade] = (acc[v.voted_grade] || 0) + 1;
                                    return acc;
                                }, {} as Record<string, number>);

                                const totalVotes = route.grade_votes.length;

                                return Object.entries(voteCounts)
                                    .sort((a, b) => b[1] - a[1]) // Sort descending by vote count
                                    .map(([grade, count]) => {
                                        const percentage = totalVotes > 0 ? count / totalVotes : 0;
                                        return (
                                            <div key={grade} style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '10px' }}>
                                                <span style={{ width: '40px', fontSize: '0.85rem', fontWeight: 600 }}>{grade}</span>
                                                <div style={{ flex: 1, height: '16px', backgroundColor: 'var(--border-color, rgba(128,128,128,0.2))', borderRadius: '4px', position: 'relative' }}>
                                                    <div style={{ width: `${percentage * 100}%`, height: '100%', backgroundColor: 'var(--primary-color, #3b82f6)', borderRadius: '4px' }} />
                                                </div>
                                                <span style={{ width: '30px', textAlign: 'right', fontSize: '0.85rem', color: 'var(--text-secondary)' }}>{count}</span>
                                            </div>
                                        );
                                    });
                            })()}
                        </div>
                    )}
                </Card>

                {/* Comments */}
                <Card className="comments-card">
                    <h3 className="section-title">Comments</h3>

                    {!isGuest && (
                        <form onSubmit={handleCommentSubmit} className="comment-form">
                            <Input
                                placeholder="Add a comment..."
                                value={newComment}
                                onChange={(e) => setNewComment(e.target.value)}
                                fullWidth
                                style={{ marginBottom: '0.5rem' }}
                            />
                            <Button type="submit" disabled={isSubmitting || !newComment.trim()} style={{ alignSelf: 'flex-end' }}>
                                Post
                            </Button>
                        </form>
                    )}

                    <div className="comments-list">
                        {route.comments.length === 0 ? (
                            <p className="empty-text">No comments yet.</p>
                        ) : (
                            route.comments.map(c => (
                                <div key={c.id} className="comment-bubble">
                                    <div className="comment-meta">
                                        <span className="comment-author">{c.user?.username || 'User'}</span>
                                        <span className="comment-date">{new Date(c.created_at).toLocaleDateString()}</span>
                                    </div>
                                    <div
                                        className="comment-body"
                                        dangerouslySetInnerHTML={{ __html: sanitizeHtml(c.content) }}
                                    />
                                </div>
                            ))
                        )}
                    </div>
                </Card>
            </div>
        </div>
    );
};
