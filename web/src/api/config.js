export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://127.0.0.1:8000';

export async function readJsonResponse(res, fallbackMessage) {
  let json;

  try {
    json = await res.json();
  } catch {
    json = null;
  }

  if (!res.ok) {
    throw new Error(json?.detail || fallbackMessage);
  }

  return json;
} 