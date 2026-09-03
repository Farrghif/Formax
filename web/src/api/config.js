export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://127.0.0.1:8000';

// Ambil atau buat anonymous identity untuk isi form tanpa login (Google-Forms style)
// Disimpan di localStorage agar persist antar reload / tabs
export function getRespondentKey() {
  try {
    let key = localStorage.getItem('respondent_key');
    if (!key) {
      key = (globalThis.crypto && globalThis.crypto.randomUUID)
        ? globalThis.crypto.randomUUID()
        : `rk_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`;
      localStorage.setItem('respondent_key', key);
    }
    return key;
  } catch {
    return null;
  }
}

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

// Helper untuk header auth anonim: Authorization (jika ada token) + X-Respondent-Key (selalu)
export function getAuthHeaders(token) {
  const headers = {};
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const rkey = getRespondentKey();
  if (rkey) headers['X-Respondent-Key'] = rkey;
  return headers;
}

export async function readJsonResponse(res, fallbackMessage) {
  let json;

  try {
    json = await res.json();
  } catch {
    // Ignore JSON parse error, json remains null
  }

  if (!res.ok) {
    if (res.status === 404 && json?.detail === 'Not Found') {
      throw new Error('Endpoint backend belum tersedia atau server backend belum direstart.');
    }
    throw new Error(json?.detail || fallbackMessage);
  }

  return json;
} 