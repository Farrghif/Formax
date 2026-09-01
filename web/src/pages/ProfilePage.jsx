import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { getMe, updateMe, logout } from '../api/auth';
import logoForm4x from '../assets/logo_form4x.png';
import ThemeToggle from '../components/ThemeToggle';
import '../styles/dashboard.css';

export default function ProfilePage() {
  const navigate = useNavigate();
  const token = localStorage.getItem('token');

  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [imgError, setImgError] = useState(false);

  const [form, setForm] = useState({
    full_name: '',
    email: '',
    avatar_url: '',
  });

  useEffect(() => {
    if (!token) {
      navigate('/auth');
      return;
    }

    getMe(token)
      .then((userData) => {
        setUser(userData);
        setForm({
          full_name: userData.full_name || '',
          email: userData.email || '',
          avatar_url: userData.avatar_url || '',
        });
      })
      .catch((err) => {
        setError(err.message || 'Gagal memuat profil');
      })
      .finally(() => setLoading(false));
  }, [navigate, token]);

  const getInitials = (name = '') =>
    name
      .split(' ')
      .filter(Boolean)
      .slice(0, 2)
      .map((w) => w[0])
      .join('')
      .toUpperCase() || 'U';

  const handleChange = (e) => {
    const { name, value } = e.target;
    if (name === 'avatar_url') {
      setImgError(false);
    }
    setForm((prev) => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);
    setMessage('');
    setError('');

    try {
      const updatedUser = await updateMe(token, {
        full_name: form.full_name.trim(),
        email: form.email.trim(),
        avatar_url: form.avatar_url.trim() || null,
      });

      setUser(updatedUser);
      setForm({
        full_name: updatedUser.full_name || '',
        email: updatedUser.email || '',
        avatar_url: updatedUser.avatar_url || '',
      });
      setMessage('Profil berhasil diperbarui!');
      setTimeout(() => setMessage(''), 4000);
    } catch (err) {
      setError(err.message || 'Gagal memperbarui profil');
    } finally {
      setSaving(false);
    }
  };

  const handleLogout = () => {
    logout();
    navigate('/auth');
  };

  if (loading) {
    return (
      <div className="db-loading">
        <div className="db-spinner" />
        <p>Memuat profil...</p>
      </div>
    );
  }

  const displayName = form.full_name || user?.full_name || 'Pengguna';
  const displayEmail = form.email || user?.email || '-';

  return (
    <div className="db-root">
      {/* Sidebar */}
      <aside className="db-sidebar">
        <div className="db-logo" onClick={() => navigate('/dashboard')} style={{ cursor: 'pointer' }}>
          <div className="db-logo-icon">
            <img src={logoForm4x} alt="Form4x logo" className="db-logo-img" />
          </div>
          <div className="db-logo-text">
            <span className="db-logo-name">Form4x</span>
            <span className="db-logo-tagline">Tempat membuat Form Terlengkap</span>
          </div>
        </div>

        <nav className="db-nav">
          <button className="db-nav-item" onClick={() => navigate('/dashboard')}>
            <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <rect x="3" y="3" width="7" height="7" rx="1" />
              <rect x="14" y="3" width="7" height="7" rx="1" />
              <rect x="3" y="14" width="7" height="7" rx="1" />
              <rect x="14" y="14" width="7" height="7" rx="1" />
            </svg>
            <span>Dashboard</span>
          </button>
        </nav>

        <div className="db-sidebar-footer">
          <div className="db-user active-user-profile">
            <div className="db-avatar">
              {form.avatar_url && !imgError ? (
                <img src={form.avatar_url} alt={displayName} onError={() => setImgError(true)} />
              ) : (
                <span>{getInitials(displayName)}</span>
              )}
            </div>
            <div className="db-user-info">
              <span className="db-user-name">{displayName}</span>
              <span className="db-user-email">{displayEmail}</span>
            </div>
          </div>
          <ThemeToggle size="sidebar" />
          <button className="db-logout-btn" onClick={handleLogout} aria-label="Logout" title="Keluar">
            <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4" />
              <polyline points="16 17 21 12 16 7" />
              <line x1="21" y1="12" x2="9" y2="12" />
            </svg>
          </button>
        </div>
      </aside>

      {/* Main Content Area */}
      <main className="db-main">
        <header className="db-topbar" style={{ justifyContent: 'space-between' }}>
          <button className="back-nav-btn" onClick={() => navigate('/dashboard')}>
            <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            <span>Kembali ke Dashboard</span>
          </button>
          <ThemeToggle />
        </header>

        <section className="db-content">
          <div className="profile-container">
            {/* Profile Hero Header Card */}
            <div className="profile-hero-card">
              <div className="profile-cover-banner">
                <div className="profile-cover-decor-1" />
                <div className="profile-cover-decor-2" />
              </div>
              <div className="profile-hero-body">
                <div className="profile-avatar-wrapper">
                  <div className="profile-avatar-large">
                    {form.avatar_url && !imgError ? (
                      <img src={form.avatar_url} alt={displayName} onError={() => setImgError(true)} />
                    ) : (
                      <span>{getInitials(displayName)}</span>
                    )}
                  </div>
                  <div className="profile-avatar-status" title="Akun Aktif" />
                </div>

                <div className="profile-hero-details">
                  <div className="profile-name-row">
                    <h2>{displayName}</h2>
                    <span className="profile-badge success-badge">
                      <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      Akun Terverifikasi
                    </span>
                  </div>
                  <p className="profile-email-sub">{displayEmail}</p>

                  <div className="profile-meta-chips">
                    <span className="profile-chip">
                      <svg width="13" height="13" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                      </svg>
                      Anggota Form4x
                    </span>
                    <span className="profile-chip highlight-chip">
                      <svg width="13" height="13" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z" />
                      </svg>
                      Status: Aktif
                    </span>
                  </div>
                </div>
              </div>
            </div>

            {/* Profile Grid Container */}
            <div className="profile-grid-container">
              {/* Left Main Form Card */}
              <div className="profile-form-card">
                <div className="profile-card-header">
                  <div className="profile-header-icon">
                    <svg width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                    </svg>
                  </div>
                  <div className="profile-card-title">
                    <h3>Edit Informasi Profil</h3>
                    <p>Perbarui nama lengkap, email, atau tautan foto profil Anda</p>
                  </div>
                </div>

                {message && (
                  <div className="profile-alert success">
                    <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                    </svg>
                    <span>{message}</span>
                  </div>
                )}

                {error && (
                  <div className="profile-alert danger">
                    <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <span>{error}</span>
                  </div>
                )}

                <form onSubmit={handleSubmit} className="profile-form">
                  <div className="profile-form-group">
                    <label htmlFor="full_name">Nama Lengkap</label>
                    <div className="input-icon-wrapper">
                      <svg className="input-icon" width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                      </svg>
                      <input
                        id="full_name"
                        type="text"
                        name="full_name"
                        value={form.full_name}
                        onChange={handleChange}
                        placeholder="Masukkan nama lengkap"
                        required
                      />
                    </div>
                  </div>

                  <div className="profile-form-group">
                    <label htmlFor="email">Email</label>
                    <div className="input-icon-wrapper">
                      <svg className="input-icon" width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                      </svg>
                      <input
                        id="email"
                        type="email"
                        name="email"
                        value={form.email}
                        onChange={handleChange}
                        placeholder="nama@email.com"
                        required
                      />
                    </div>
                  </div>

                  <div className="profile-form-group">
                    <label htmlFor="avatar_url">URL Foto Profil (Opsional)</label>
                    <div className="input-icon-wrapper">
                      <svg className="input-icon" width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
                      </svg>
                      <input
                        id="avatar_url"
                        type="url"
                        name="avatar_url"
                        value={form.avatar_url}
                        onChange={handleChange}
                        placeholder="https://example.com/avatar.jpg"
                      />
                    </div>
                  </div>

                  {/* Live Avatar Preview Section */}
                  <div className="profile-avatar-live-preview">
                    <div className="live-preview-left">
                      <div className="live-preview-thumb">
                        {form.avatar_url && !imgError ? (
                          <img src={form.avatar_url} alt="Pratinjau Avatar" onError={() => setImgError(true)} />
                        ) : (
                          <span>{getInitials(displayName)}</span>
                        )}
                      </div>
                      <div className="live-preview-text">
                        <span className="preview-label">Pratinjau Foto Profil</span>
                        <span className="preview-sub">
                          {form.avatar_url ? (imgError ? 'URL Foto tidak valid' : 'Gambar dari URL') : 'Inisial Nama (Default)'}
                        </span>
                      </div>
                    </div>
                    {form.avatar_url && (
                      <button
                        type="button"
                        className="clear-avatar-btn"
                        onClick={() => {
                          setForm((prev) => ({ ...prev, avatar_url: '' }));
                          setImgError(false);
                        }}
                        title="Hapus URL"
                      >
                        Reset
                      </button>
                    )}
                  </div>

                  <div className="profile-form-actions">
                    <button type="button" className="db-btn-cancel" onClick={() => navigate('/dashboard')}>
                      Batal
                    </button>
                    <button type="submit" className="history-btn-result profile-submit-btn" disabled={saving}>
                      {saving ? (
                        <>
                          <div className="btn-spinner" />
                          <span>Menyimpan...</span>
                        </>
                      ) : (
                        <>
                          <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                            <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                          </svg>
                          <span>Simpan Perubahan</span>
                        </>
                      )}
                    </button>
                  </div>
                </form>
              </div>

              {/* Right Side Summary Card */}
              <div className="profile-side-card">
                <div className="side-card-header">
                  <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                  </svg>
                  <h4>Ringkasan Akun</h4>
                </div>

                <div className="side-info-list">
                  <div className="side-info-item">
                    <span className="side-info-label">Status Keamanan</span>
                    <span className="side-info-val green-text">
                      <span className="status-dot" /> Aman & Terlindungi
                    </span>
                  </div>

                  <div className="side-info-item">
                    <span className="side-info-label">Tipe Akun</span>
                    <span className="side-info-val">Form Creator</span>
                  </div>

                  <div className="side-info-item">
                    <span className="side-info-label">Email Terhubung</span>
                    <span className="side-info-val truncate-text">{displayEmail}</span>
                  </div>
                </div>

                <div className="side-tip-box">
                  <div className="tip-header">
                    <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <span>Tips Profil</span>
                  </div>
                  <p>Gunakan link gambar publik dengan protokol HTTPS (seperti Imgur, Unsplash, atau Google Drive) untuk hasil tampilan foto profil terbaik.</p>
                </div>
              </div>
            </div>
          </div>
        </section>
      </main>
    </div>
  );
}

