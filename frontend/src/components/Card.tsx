import React, { type ReactNode } from 'react';
import './Card.css';

export interface CardProps {
    children: ReactNode;
    className?: string;
    noPadding?: boolean;
}

export const Card: React.FC<CardProps> = ({ children, className = '', noPadding = false }) => {
    return (
        <div className={`card glass animate-fade-in ${noPadding ? 'card-no-padding' : ''} ${className}`}>
            {children}
        </div>
    );
};
