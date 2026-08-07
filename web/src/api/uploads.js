const BASE_URL = 'http://localhost:8000';

/**
 * Upload file (banner form, avatar, dll). Kembalikan { file_url }.
 */
export async function uploadFile(token, file) {
  const formData = new FormData();
  formData.append('file', file);
  const res = await fetch(`${BASE_URL}/uploads`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: formData,
  });
  const json = await res.json();
  if (!res.ok) throw new Error(json.detail || 'Gagal mengupload file');
  return json;
}
