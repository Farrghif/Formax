import { API_BASE_URL, apiFetch, readJsonResponse } from './config';

/**
 * Kirim OTP ke email (wajib sebelum signup)
 * @param {string} email
 */
export async function sendOtp(email) {
  const res = await apiFetch(`${API_BASE_URL}/auth/send-otp`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email }),
  });

  const json = await res.json();
  if (!res.ok) throw new Error(json.detail || 'Gagal mengirim OTP');
  return json;
}

/**
 * Kirim OTP untuk Lupa Password
 * @param {string} email
 */
export async function sendForgotPasswordOtp(email) {
  const res = await apiFetch(`${API_BASE_URL}/auth/forgot-password/send-otp`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email }),
  });

  return readJsonResponse(res, 'Gagal mengirim OTP reset password');
}

/**
 * Verifikasi OTP untuk Lupa Password
 * @param {string} email
 * @param {string} otp
 */
export async function verifyForgotPasswordOtp(email, otp) {
  const res = await apiFetch(`${API_BASE_URL}/auth/forgot-password/verify-otp`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, otp }),
  });

  return readJsonResponse(res, 'Kode OTP tidak valid');
}

/**
 * Reset password dengan OTP
 * @param {{ email: string, otp: string, new_password: string }} data
 */
export async function resetPassword(data) {
  const res = await apiFetch(`${API_BASE_URL}/auth/forgot-password/reset-password`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });

  return readJsonResponse(res, 'Gagal mengubah password');
}

/**
 * Signup / Register user baru (wajib sertakan OTP)
 * @param {{ full_name: string, email: string, password: string, otp: string }} data
 */
export async function signup(data) {
  const res = await apiFetch(`${API_BASE_URL}/auth/signup`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });

  return readJsonResponse(res, 'Signup gagal');
}

/**
 * Login user
 * @param {{ email: string, password: string, remember?: boolean }} data
 */
export async function login(data) {
  const res = await apiFetch(`${API_BASE_URL}/auth/login`, {
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
  const res = await apiFetch(`${API_BASE_URL}/auth/me`, {
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
  const res = await apiFetch(`${API_BASE_URL}/auth/me`, {
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
 * Change current user password (requires token)
 * @param {string} token
 * @param {{ old_password: string, new_password: string }} data
 */
export async function changePassword(token, data) {
  const res = await apiFetch(`${API_BASE_URL}/auth/change-password`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(data),
  });

  return readJsonResponse(res, 'Gagal mengubah password');
}

/**
 * Logout (client-side: hapus token dari localStorage)
 */
export function logout() {
  localStorage.removeItem('token');
  localStorage.removeItem('user');
  localStorage.removeItem('auth_expires');
  localStorage.removeItem('auth_remember');
  try { sessionStorage.removeItem('token'); } catch {}
}
