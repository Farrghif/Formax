const BASE_URL = 'http://localhost:8000';

/**
 * List semua template (system + user templates)
 */
export async function getTemplates(token) {
  const res = await fetch(`${BASE_URL}/templates`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const json = await res.json();
  if (!res.ok) throw new Error(json.detail || 'Gagal mengambil templates');
  return json;
}

/**
 * Get detail template (termasuk questions)
 */
export async function getTemplate(token, templateId) {
  const res = await fetch(`${BASE_URL}/templates/${templateId}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const json = await res.json();
  if (!res.ok) throw new Error(json.detail || 'Gagal mengambil template');
  return json;
}

/**
 * List template buatan sendiri saja
 */
export async function getMyTemplates(token) {
  const res = await fetch(`${BASE_URL}/templates/mine`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const json = await res.json();
  if (!res.ok) throw new Error(json.detail || 'Gagal mengambil templates');
  return json;
}
