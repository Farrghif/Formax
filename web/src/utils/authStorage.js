const TOKEN_KEY = 'token'
const EXPIRES_KEY = 'auth_expires'
const REMEMBER_KEY = 'auth_remember'
const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000

export function setAuth(token, remember = false) {
  localStorage.setItem(TOKEN_KEY, token)
  // juga simpan di sessionStorage untuk kompatibilitas cek cepat
  try { sessionStorage.setItem(TOKEN_KEY, token) } catch {}
  if (remember) {
    localStorage.setItem(REMEMBER_KEY, 'true')
    localStorage.setItem(EXPIRES_KEY, String(Date.now() + THIRTY_DAYS_MS))
  } else {
    localStorage.setItem(REMEMBER_KEY, 'false')
    localStorage.removeItem(EXPIRES_KEY)
    // non-remember: token tetap ada tapi tidak auto-redirect 30 hari
    // expiry mengikuti JWT backend (7 hari), jadi tidak set EXPIRES_KEY
  }
}

export function getValidToken() {
  const token = localStorage.getItem(TOKEN_KEY) || (() => { try { return sessionStorage.getItem(TOKEN_KEY) } catch { return null } })()
  if (!token) return null
  const remember = localStorage.getItem(REMEMBER_KEY) === 'true'
  // hanya cek expiry lokal untuk remember me 30 hari
  if (remember) {
    const exp = localStorage.getItem(EXPIRES_KEY)
    if (exp && Date.now() > Number(exp)) {
      clearAuth()
      return null
    }
  }
  return token
}

export function isRemembered() {
  return localStorage.getItem(REMEMBER_KEY) === 'true' && !!getValidToken()
}

export function clearAuth() {
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(EXPIRES_KEY)
  localStorage.removeItem(REMEMBER_KEY)
  localStorage.removeItem('user')
  try { sessionStorage.removeItem(TOKEN_KEY) } catch {}
}
