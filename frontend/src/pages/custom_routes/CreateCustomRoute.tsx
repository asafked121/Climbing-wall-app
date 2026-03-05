import React, { useState, useRef, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Button } from '../../components/Button';
import { Input } from '../../components/Input';
import { Card } from '../../components/Card';
import './CustomRoutes.css';

interface Hold {
    id: string;
    x: number;
    y: number;
    radius: number;
}

export const CreateCustomRoute: React.FC = () => {
    const [file, setFile] = useState<File | null>(null);
    const [previewUrl, setPreviewUrl] = useState<string | null>(null);
    const [photoUrl, setPhotoUrl] = useState<string | null>(null);
    const [allHolds, setAllHolds] = useState<Hold[]>([]);
    const [selectedHoldIds, setSelectedHoldIds] = useState<Set<string>>(new Set());
    const [name, setName] = useState('');
    const [intendedGrade, setIntendedGrade] = useState('V0');

    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);

    const navigate = useNavigate();
    const canvasRef = useRef<HTMLCanvasElement>(null);
    const imageRef = useRef<HTMLImageElement>(null);
    const containerRef = useRef<HTMLDivElement>(null);

    const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        if (e.target.files && e.target.files[0]) {
            setFile(e.target.files[0]);
            setPreviewUrl(URL.createObjectURL(e.target.files[0]));
            setAllHolds([]);
            setSelectedHoldIds(new Set());
            setPhotoUrl(null);
        }
    };

    const handleDetectHolds = async () => {
        if (!file) return;
        setLoading(true);
        setError(null);

        const formData = new FormData();
        formData.append('file', file);

        try {
            const token = localStorage.getItem('token');
            const response = await fetch(`${import.meta.env.VITE_API_URL || '/api'}/custom-routes/detect-holds`, {
                method: 'POST',
                headers: {
                    ...(token ? { 'Authorization': `Bearer ${token}` } : {})
                },
                body: formData
            });

            if (!response.ok) throw new Error('Failed to detect holds');
            const data = await response.json();

            setPhotoUrl(data.photo_url);
            setAllHolds(data.holds || []);
        } catch (err: any) {
            setError(err.message);
        } finally {
            setLoading(false);
        }
    };

    const drawCanvas = () => {
        const canvas = canvasRef.current;
        const img = imageRef.current;
        if (!canvas || !img || !allHolds.length) return;

        const ctx = canvas.getContext('2d');
        if (!ctx) return;

        // Match canvas size to displayed image size
        canvas.width = img.clientWidth;
        canvas.height = img.clientHeight;

        ctx.clearRect(0, 0, canvas.width, canvas.height);

        // Calculate scaling factor between natural image size and displayed size
        const scaleX = canvas.width / img.naturalWidth;
        const scaleY = canvas.height / img.naturalHeight;

        allHolds.forEach(hold => {
            const cx = hold.x * scaleX;
            const cy = hold.y * scaleY;
            const radius = hold.radius * Math.max(scaleX, Math.min(scaleX, scaleY));

            const isSelected = selectedHoldIds.has(hold.id);

            ctx.beginPath();
            ctx.arc(cx, cy, Math.max(radius, 10), 0, 2 * Math.PI);
            ctx.lineWidth = 3;
            // Unselected = light blue dashed, Selected = strong green solid
            if (isSelected) {
                ctx.strokeStyle = '#34c759';
                ctx.fillStyle = 'rgba(52, 199, 89, 0.4)';
                ctx.fill();
            } else {
                ctx.strokeStyle = 'rgba(255, 255, 255, 0.6)';
                ctx.fillStyle = 'rgba(255, 255, 255, 0.1)';
                ctx.setLineDash([5, 5]);
            }
            ctx.stroke();
            ctx.setLineDash([]); // reset
        });
    };

    // Redraw whenever holds or selection change
    useEffect(() => {
        drawCanvas();
    }, [allHolds, selectedHoldIds]);

    // Redraw on window resize
    useEffect(() => {
        window.addEventListener('resize', drawCanvas);
        return () => window.removeEventListener('resize', drawCanvas);
    }, [allHolds, selectedHoldIds]);

    const handleCanvasClick = (e: React.MouseEvent<HTMLCanvasElement>) => {
        const canvas = canvasRef.current;
        const img = imageRef.current;
        if (!canvas || !img || !allHolds.length) return;

        const rect = canvas.getBoundingClientRect();
        // Coordinates relative to canvas
        const clickX = e.clientX - rect.left;
        const clickY = e.clientY - rect.top;

        const scaleX = canvas.width / img.naturalWidth;
        const scaleY = canvas.height / img.naturalHeight;

        // Find if we clicked on any hold
        let clickedHoldId: string | null = null;

        // Check in reverse order so top overlapping hold is selected
        for (let i = allHolds.length - 1; i >= 0; i--) {
            const hold = allHolds[i];
            const cx = hold.x * scaleX;
            const cy = hold.y * scaleY;
            const radius = Math.max(hold.radius * Math.max(scaleX, scaleY), 15); // min click radius 15px

            const dist = Math.sqrt(Math.pow(clickX - cx, 2) + Math.pow(clickY - cy, 2));
            if (dist <= radius) {
                clickedHoldId = hold.id;
                break;
            }
        }

        if (clickedHoldId) {
            const newSelected = new Set(selectedHoldIds);
            if (newSelected.has(clickedHoldId)) {
                newSelected.delete(clickedHoldId);
            } else {
                newSelected.add(clickedHoldId);
            }
            setSelectedHoldIds(newSelected);
        }
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!photoUrl) {
            setError("Please detect holds first.");
            return;
        }

        const selectedHoldsList = allHolds.filter(h => selectedHoldIds.has(h.id));
        if (selectedHoldsList.length === 0) {
            setError("Please select at least one hold for your route.");
            return;
        }

        setLoading(true);
        setError(null);

        try {
            const token = localStorage.getItem('token');
            const response = await fetch(`${import.meta.env.VITE_API_URL || '/api'}/custom-routes/`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    ...(token ? { 'Authorization': `Bearer ${token}` } : {})
                },
                body: JSON.stringify({
                    name,
                    intended_grade: intendedGrade,
                    photo_url: photoUrl,
                    holds: JSON.stringify(selectedHoldsList)
                })
            });

            if (!response.ok) throw new Error('Failed to create route');
            const data = await response.json();
            navigate(`/community/${data.id}`);
        } catch (err: any) {
            setError(err.message);
            setLoading(false);
        }
    };

    return (
        <div className="create-custom-container fade-in">
            <h2>Post a Community Route</h2>
            {error && <div className="error-message">{error}</div>}

            <form onSubmit={handleSubmit} className="custom-route-form">
                {!allHolds.length ? (
                    <Card className="upload-card">
                        <div className="upload-section">
                            <label className="upload-label">
                                {previewUrl ? (
                                    <img src={previewUrl} alt="Preview" className="upload-preview" />
                                ) : (
                                    <div className="upload-placeholder">
                                        <span className="upload-icon">📷</span>
                                        <span>Tap to select photo of a wall</span>
                                    </div>
                                )}
                                <input type="file" accept="image/*" onChange={handleFileChange} style={{ display: 'none' }} />
                            </label>

                            {file && (
                                <Button
                                    type="button"
                                    onClick={handleDetectHolds}
                                    disabled={loading}
                                    style={{ marginTop: '1rem', width: '100%' }}
                                >
                                    {loading ? 'Detecting Holds...' : 'Detect Holds (OpenCV)'}
                                </Button>
                            )}
                        </div>
                    </Card>
                ) : (
                    <Card className="holds-selection-card">
                        <p className="instruction-text">Tap the detected holds to include them in your route.</p>
                        <div className="canvas-container" ref={containerRef}>
                            {previewUrl && (
                                <img
                                    ref={imageRef}
                                    src={previewUrl}
                                    alt="Wall"
                                    className="wall-image"
                                    onLoad={drawCanvas}
                                />
                            )}
                            <canvas
                                ref={canvasRef}
                                className="holds-canvas"
                                onClick={handleCanvasClick}
                            />
                        </div>

                        <div className="form-inputs">
                            <Input
                                label="Route Name"
                                value={name}
                                onChange={(e) => setName(e.target.value)}
                                required
                                placeholder="E.g. Dyno Master"
                            />

                            <div className="input-container">
                                <label className="input-label">Intended Grade</label>
                                <select
                                    className="input-field"
                                    value={intendedGrade}
                                    onChange={(e) => setIntendedGrade(e.target.value)}
                                >
                                    {['V0', 'V1', 'V2', 'V3', 'V4', 'V5', 'V6', 'V7', 'V8', 'V9', 'V10'].map(grade => (
                                        <option key={grade} value={grade}>{grade}</option>
                                    ))}
                                </select>
                            </div>
                        </div>

                        <Button type="submit" disabled={loading} style={{ width: '100%', marginTop: '1rem' }}>
                            {loading ? 'Posting...' : 'Post Route'}
                        </Button>
                    </Card>
                )}
            </form>
        </div>
    );
};
