export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://127.0.0.1:8000';

// Wrapper fetch yang otomatis inject header bypass ngrok warning page
// Ngrok free (ngrok-free.dev) menampilkan halaman interstitial jika header ini tidak ada,
// yang menyebabkan CORS error di browser meski status 200.
export function apiFetch(url, options = {}) {
  const headers = {
    'ngrok-skip-browser-warning': 'true',
    ...(options.headers || {}),
  };
  return globalThis.fetch(url, { ...options, headers });
}

export async function readJsonResponse(res, fallbackMessage) {
  let json;

  try {
    json = await res.json();
  } catch {
    // Ignore JSON parse error, json remains null
  }

  if (!res.ok) {
    throw new Error(json?.detail || fallbackMessage);
  }

  return json;
} 