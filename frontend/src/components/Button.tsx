import React, { type ButtonHTMLAttributes } from "react";
import "./Button.css";

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: "primary" | "secondary" | "danger" | "ghost";
  fullWidth?: boolean;
  isLoading?: boolean;
}

export const Button: React.FC<ButtonProps> = ({
  children,
  variant = "primary",
  fullWidth = false,
  isLoading = false,
  className = "",
  disabled,
  ...props
}) => {
  const baseClass = "btn";
  const variantClass = `btn-${variant}`;
  const widthClass = fullWidth ? "btn-full" : "";
  const loadingClass = isLoading ? "btn-loading" : "";

  return (
    <button
      className={`${baseClass} ${variantClass} ${widthClass} ${loadingClass} ${className}`}
      disabled={disabled || isLoading}
      {...props}
    >
      {isLoading ? <span className="loader"></span> : children}
    </button>
  );
};
