import { API_BASE_URL, readJsonResponse } from './config';

/**
 * List semua form milik user (untuk halaman History / Recent History)
 */
export async function getMyForms(token) {
  const res = await fetch(`${API_BASE_URL}/forms`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  return readJsonResponse(res, 'Gagal mengambil daftar form');
}

/**
 * Buat form baru (blank atau dari template)
 */
export async function createForm(token, data) {
  const res = await fetch(`${API_BASE_URL}/forms`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(data),
  });
  return readJsonResponse(res, 'Gagal membuat form');
}

/**
 * Get detail form (owner only)
 */
export async function getForm(token, formId) {
  const res = await fetch(`${API_BASE_URL}/forms/${formId}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  return readJsonResponse(res, 'Gagal mengambil form');
}

/**
 * Update form (title, description, status, dates, etc.)
 */
export async function updateForm(token, formId, data) {
  const res = await fetch(`${API_BASE_URL}/forms/${formId}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(data),
  });
  return readJsonResponse(res, 'Gagal mengupdate form');
}

/**
 * Hapus form
 */
export async function deleteForm(token, formId) {
  const res = await fetch(`${API_BASE_URL}/forms/${formId}`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${token}` },
  });
  return readJsonResponse(res, 'Gagal menghapus form');
}

/**
 * Generate QR code untuk form
 */
export async function generateQR(token, formId) {
  const res = await fetch(`${API_BASE_URL}/forms/${formId}/generate-qr`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
  });
  return readJsonResponse(res, 'Gagal generate QR');
}
