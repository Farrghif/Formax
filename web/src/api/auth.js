const BASE_URL = 'http://localhost:8000';

/**
 * Signup / Register user baru
 * @param {{ full_name: string, email: string, password: string }} data
 */
export async function signup(data) {
  const res = await fetch(`${BASE_URL}/auth/signup`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });

  const json = await res.json();
  if (!res.ok) throw new Error(json.detail || 'Signup gagal');
  return json; // { access_token, token_type }
}

/**
 * Login user
 * @param {{ email: string, password: string }} data
 */
export async function login(data) {
  const res = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });

  const json = await res.json();
  if (!res.ok) throw new Error(json.detail || 'Login gagal');
  return json; // { access_token, token_type }
}

/**
 * Get current user info (requires token)
 */
export async function getMe(token) {
  const res = await fetch(`${BASE_URL}/auth/me`, {
    headers: { Authorization: `Bearer ${token}` },
  });

  const json = await res.json();
  if (!res.ok) throw new Error(json.detail || 'Gagal mengambil data user');
  return json; // UserOut
}

/**
 * Logout (client-side: hapus token dari localStorage)
 */
export function logout() {
  localStorage.removeItem('token');
  localStorage.removeItem('user');
}
