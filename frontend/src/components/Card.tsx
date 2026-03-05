import React, { type ReactNode } from 'react';
import './Card.css';

export interface CardProps {
    children: ReactNode;
    className?: string;
    noPadding?: boolean;
    onClick?: () => void;
}

export const Card: React.FC<CardProps> = ({ children, className = '', noPadding = false, onClick }) => {
    return (
        <div
            className={`card glass ${noPadding ? 'card-no-padding' : ''} ${className}`}
            onClick={onClick}
            style={onClick ? { cursor: 'pointer' } : undefined}
        >
            {children}
        </div>
    );
};
