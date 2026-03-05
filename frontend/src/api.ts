/**
 * api.ts
 * Utility for making API requests to the backend securely.
 * Automatically includes credentials (HttpOnly cookies) in all requests.
 */

const API_BASE_URL = import.meta.env.VITE_API_URL || '/api';

interface RequestOptions extends RequestInit {
    data?: any;
}

class ApiError extends Error {
    status: number;
    data: any;

    constructor(status: number, data: any, message: string) {
        super(message);
        this.status = status;
        this.data = data;
        this.name = 'ApiError';
    }
}

export const api = {
    async request<T>(endpoint: string, options: RequestOptions = {}): Promise<T> {
        const { data, headers, ...customConfig } = options;

        const config: RequestInit = {
            ...customConfig,
            headers: {
                ...headers,
            },
            // CRITICAL SECURITY RULE: Include credentials to send HttpOnly cookies
            credentials: 'include',
        };

        // Only set Content-Type to application/json if data is not FormData
        if (!(data instanceof FormData)) {
            config.headers = {
                'Content-Type': 'application/json',
                ...config.headers
            };
        }

        if (data) {
            if (data instanceof FormData) {
                config.body = data;
            } else {
                config.body = JSON.stringify(data);
            }
        }

        try {
            const response = await fetch(`${API_BASE_URL}${endpoint}`, config);

            let responseData;
            if (response.status !== 204) {
                const contentType = response.headers.get('content-type');
                if (contentType && contentType.includes('application/json')) {
                    try {
                        responseData = await response.json();
                    } catch (e) {
                        console.warn("Expected JSON but parsing failed:", e);
                    }
                }
            }

            if (!response.ok) {
                throw new ApiError(
                    response.status,
                    responseData,
                    responseData?.detail || response.statusText || 'An error occurred'
                );
            }

            return responseData as T;
        } catch (error) {
            if (error instanceof ApiError) {
                throw error;
            }
            throw new Error(`Network error: ${(error as Error).message}`);
        }
    },

    get<T>(endpoint: string, options?: RequestOptions) {
        return this.request<T>(endpoint, { ...options, method: 'GET' });
    },

    post<T>(endpoint: string, data?: any, options?: RequestOptions) {
        return this.request<T>(endpoint, { ...options, method: 'POST', data });
    },

    put<T>(endpoint: string, data?: any, options?: RequestOptions) {
        return this.request<T>(endpoint, { ...options, method: 'PUT', data });
    },

    patch<T>(endpoint: string, data?: any, options?: RequestOptions) {
        return this.request<T>(endpoint, { ...options, method: 'PATCH', data });
    },

    delete<T>(endpoint: string, options?: RequestOptions) {
        return this.request<T>(endpoint, { ...options, method: 'DELETE' });
    },

    postFormData<T>(endpoint: string, formData: FormData, options?: RequestOptions) {
        return this.request<T>(endpoint, { ...options, method: 'POST', data: formData });
    },
};
