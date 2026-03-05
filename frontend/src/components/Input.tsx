import { type InputHTMLAttributes, forwardRef } from 'react';
import './Input.css';

export interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
    label?: string;
    error?: string;
    fullWidth?: boolean;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(
    ({ label, error, fullWidth = true, className = '', id, ...props }, ref) => {
        const inputId = id || `input-${Math.random().toString(36).substr(2, 9)}`;
        const widthClass = fullWidth ? 'input-full' : '';
        const errorClass = error ? 'input-error' : '';

        return (
            <div className={`input-group ${widthClass} ${className}`}>
                {label && <label htmlFor={inputId} className="input-label">{label}</label>}
                <input
                    ref={ref}
                    id={inputId}
                    className={`input-field ${errorClass}`}
                    {...props}
                />
                {error && <span className="input-error-text">{error}</span>}
            </div>
        );
    }
);

Input.displayName = 'Input';
