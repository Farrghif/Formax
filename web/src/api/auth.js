import { API_BASE_URL, readJsonResponse } from './config';

/**
 * Kirim OTP ke email (wajib sebelum signup)
 * @param {string} email
 */
export async function sendOtp(email) {
  const res = await fetch(`${API_BASE_URL}/auth/send-otp`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email }),
  });

  const json = await res.json();
  if (!res.ok) throw new Error(json.detail || 'Gagal mengirim OTP');
  return json;
}

/**
 * Signup / Register user baru (wajib sertakan OTP)
 * @param {{ full_name: string, email: string, password: string, otp: string }} data
 */
export async function signup(data) {
  const res = await fetch(`${API_BASE_URL}/auth/signup`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });

  return readJsonResponse(res, 'Signup gagal');
}

/**
 * Login user
 * @param {{ email: string, password: string }} data
 */
export async function login(data) {
  const res = await fetch(`${API_BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });

  return readJsonResponse(res, 'Login gagal');
}

/**
 * Get current user info (requires token)
 */
export async function getMe(token) {
  const res = await fetch(`${API_BASE_URL}/auth/me`, {
    headers: { Authorization: `Bearer ${token}` },
  });

  return readJsonResponse(res, 'Gagal mengambil data user');
}

/**
 * Update current user profile (requires token)
 * @param {string} token
 * @param {{ full_name?: string, email?: string, avatar_url?: string }} data
 */
export async function updateMe(token, data) {
  const res = await fetch(`${API_BASE_URL}/auth/me`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(data),
  });

  return readJsonResponse(res, 'Gagal memperbarui profil');
}

/**
 * Logout (client-side: hapus token dari localStorage)
 */
export function logout() {
  localStorage.removeItem('token');
  localStorage.removeItem('user');
}
