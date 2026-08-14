import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { getMe, updateMe, logout } from '../api/auth';
import logoForm4x from '../assets/logo_form4x.png';
import '../styles/dashboard.css';

export default function ProfilePage() {
  const navigate = useNavigate();
  const token = localStorage.getItem('token');

  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

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
              {form.avatar_url ? (
                <img src={form.avatar_url} alt={displayName} />
              ) : (
                <span>{getInitials(displayName)}</span>
              )}
            </div>
            <div className="db-user-info">
              <span className="db-user-name">{displayName}</span>
              <span className="db-user-email">{displayEmail}</span>
            </div>
          </div>
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
        <header className="db-topbar" style={{ justifyContent: 'flex-start' }}>
          <button className="back-nav-btn" onClick={() => navigate('/dashboard')}>
            ← Kembali ke Dashboard
          </button>
        </header>

        <section className="db-content">
          <div className="profile-container">
            <div className="profile-header-card">
              <div className="profile-avatar-large">
                {form.avatar_url ? (
                  <img src={form.avatar_url} alt={displayName} />
                ) : (
                  <span>{getInitials(displayName)}</span>
                )}
              </div>
              <div className="profile-header-details">
                <h2>{displayName}</h2>
                <p>{displayEmail}</p>
                <span className="profile-badge">Akun Terverifikasi</span>
              </div>
            </div>

            <div className="profile-form-card">
              <div className="profile-card-title">
                <h3>Edit Informasi Profil</h3>
                <p>Perbarui nama lengkap, email, atau tautan foto profil Anda</p>
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

                <div className="profile-form-group">
                  <label htmlFor="email">Email</label>
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

                <div className="profile-form-group">
                  <label htmlFor="avatar_url">URL Foto Profil (Opsional)</label>
                  <input
                    id="avatar_url"
                    type="url"
                    name="avatar_url"
                    value={form.avatar_url}
                    onChange={handleChange}
                    placeholder="https://example.com/avatar.jpg"
                  />
                </div>

                <div className="profile-form-actions">
                  <button type="button" className="db-btn-cancel" onClick={() => navigate('/dashboard')}>
                    Batal
                  </button>
                  <button type="submit" className="history-btn-result" disabled={saving}>
                    {saving ? 'Menyimpan...' : 'Simpan Perubahan'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </section>
      </main>
    </div>
  );
}
