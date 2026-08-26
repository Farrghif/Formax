import { API_BASE_URL, readJsonResponse } from './config';

/**
 * Ambil detail form publik berdasarkan slug (wajib token auth)
 */
export async function getPublicFormBySlug(token, slug) {
  const res = await fetch(`${API_BASE_URL}/forms/public/${slug}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  return readJsonResponse(res, 'Gagal mengambil data form');
}

/**
 * Join form untuk memulai / melanjutkan submission
 * @param {string} token - Auth JWT token
 * @param {string} slug - Form slug
 * @param {string} [joinToken] - Join token jika form membutuhkan token ujian
 */
export async function joinForm(token, slug, joinToken = null) {
  const res = await fetch(`${API_BASE_URL}/forms/public/${slug}/join`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ token: joinToken || null }),
  });
  return readJsonResponse(res, 'Gagal bergabung ke form');
}

/**
 * Autosave jawaban per soal
 */
export async function saveAnswer(token, submissionId, payload) {
  const res = await fetch(`${API_BASE_URL}/submissions/${submissionId}/answers`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(payload),
  });
  return readJsonResponse(res, 'Gagal menyimpan jawaban');
}

/**
 * Ambil progress submission (X/Y)
 */
export async function getSubmissionProgress(token, submissionId) {
  const res = await fetch(`${API_BASE_URL}/submissions/${submissionId}/progress`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  return readJsonResponse(res, 'Gagal mengambil progress');
}

/**
 * Final submit jawaban
 */
export async function submitFinal(token, submissionId) {
  const res = await fetch(`${API_BASE_URL}/submissions/${submissionId}/submit`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
  });
  return readJsonResponse(res, 'Gagal mengirimkan form');
}

/**
 * Ambil hasil submission untuk responden (skor + benar/salah per soal).
 * Hanya aktif jika form.allow_see_result true.
 */
export async function getSubmissionResult(token, submissionId) {
  const res = await fetch(`${API_BASE_URL}/submissions/${submissionId}/result`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  return readJsonResponse(res, 'Gagal mengambil hasil form');
}

/**
 * Tandai submission sebagai curang (keluar dari mode full screen).
 * Hanya aktif jika form.require_fullscreen true.
 */
export async function flagCheated(token, submissionId) {
  const res = await fetch(`${API_BASE_URL}/submissions/${submissionId}/flag-cheated`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
  });
  return readJsonResponse(res, 'Gagal menandai submission');
}
