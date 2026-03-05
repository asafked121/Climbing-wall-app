import DOMPurify from 'dompurify';

/**
 * XSS security utility to sanitize dynamic HTML content before injecting it.
 * Ref: Security & Vulnerability Prevention Rules (prevent innerHTML abuse).
 */
export const sanitizeHtml = (html: string): string => {
    return DOMPurify.sanitize(html, {
        USE_PROFILES: { html: true },
        ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'p', 'br'], // Strict allowlist for comment formatting
        ALLOWED_ATTR: [],
    });
};
