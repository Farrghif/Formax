import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { getMe, logout } from '../api/auth';
import '../styles/dashboard.css';

export default function DashboardPage() {
  const navigate = useNavigate();
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [activeNav, setActiveNav] = useState('dashboard');
  const [searchQuery, setSearchQuery] = useState('');

  // Dummy template data
  const templates = [
    { id: 1, title: 'Quizz', updatedAt: '2 days ago', color: '#c7d7f0' },
    { id: 2, title: 'Ujian', updatedAt: '1 week ago', color: '#d4e4f7' },
    { id: 3, title: 'Angket Classmeet', updatedAt: '1 month ago', color: '#e0eaf8' },
  ];

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) {
      navigate('/auth');
      return;
    }
    getMe(token)
      .then((data) => setUser(data))
      .catch(() => {
        logout();
        navigate('/auth');
      })
      .finally(() => setLoading(false));
  }, [navigate]);

  const handleLogout = () => {
    logout();
    navigate('/auth');
  };

  const filteredTemplates = templates.filter((t) =>
    t.title.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const getInitials = (name = '') =>
    name
      .split(' ')
      .slice(0, 2)
      .map((w) => w[0])
      .join('')
      .toUpperCase();

  if (loading) {
    return (
      <div className="db-loading">
        <div className="db-spinner" />
        <p>Loading...</p>
      </div>
    );
  }

  return (
    <div className="db-root">
      {/* Sidebar */}
      <aside className="db-sidebar">
        {/* Logo */}
        <div className="db-logo">
          <div className="db-logo-icon">
            <svg width="28" height="28" viewBox="0 0 36 36" fill="none">
              <rect width="36" height="36" rx="8" fill="url(#logo-grad)" />
              <path d="M10 12h16M10 18h10M10 24h13" stroke="#fff" strokeWidth="2.5" strokeLinecap="round" />
              <defs>
                <linearGradient id="logo-grad" x1="0" y1="0" x2="36" y2="36" gradientUnits="userSpaceOnUse">
                  <stop stopColor="#f472b6" />
                  <stop offset="1" stopColor="#ec4899" />
                </linearGradient>
              </defs>
            </svg>
          </div>
          <div className="db-logo-text">
            <span className="db-logo-name">Form4x</span>
            <span className="db-logo-tagline">Tempat membuat Form Terlengkap</span>
          </div>
        </div>

        {/* Nav */}
        <nav className="db-nav">
          {[
            {
              key: 'dashboard',
              label: 'Dashboard',
              icon: (
                <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <rect x="3" y="3" width="7" height="7" rx="1" />
                  <rect x="14" y="3" width="7" height="7" rx="1" />
                  <rect x="3" y="14" width="7" height="7" rx="1" />
                  <rect x="14" y="14" width="7" height="7" rx="1" />
                </svg>
              ),
            },
            {
              key: 'template',
              label: 'Template',
              icon: (
                <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <rect x="3" y="3" width="18" height="18" rx="2" />
                  <path d="M3 9h18M9 21V9" />
                </svg>
              ),
            },
            {
              key: 'history',
              label: 'History',
              icon: (
                <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <polyline points="1 4 1 10 7 10" />
                  <path d="M3.51 15a9 9 0 1 0 .49-4.39" />
                </svg>
              ),
            },
          ].map((item) => (
            <button
              key={item.key}
              id={`nav-${item.key}`}
              className={`db-nav-item ${activeNav === item.key ? 'active' : ''}`}
              onClick={() => setActiveNav(item.key)}
            >
              {item.icon}
              <span>{item.label}</span>
            </button>
          ))}
        </nav>

        {/* User Footer */}
        <div className="db-sidebar-footer">
          <div className="db-user">
            <div className="db-avatar">
              {user?.avatar_url ? (
                <img src={user.avatar_url} alt={user.full_name} />
              ) : (
                <span>{getInitials(user?.full_name)}</span>
              )}
            </div>
            <div className="db-user-info">
              <span className="db-user-name">{user?.full_name}</span>
              <span className="db-user-email">{user?.email}</span>
            </div>
          </div>
          <button id="btn-logout" className="db-logout-btn" onClick={handleLogout} aria-label="Logout">
            <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4" />
              <polyline points="16 17 21 12 16 7" />
              <line x1="21" y1="12" x2="9" y2="12" />
            </svg>
          </button>
        </div>
      </aside>

      {/* Main */}
      <main className="db-main">
        {/* Topbar */}
        <header className="db-topbar">
          <h1 className="db-page-title">
            {activeNav === 'dashboard' && 'Dashboard'}
            {activeNav === 'template' && 'Template'}
            {activeNav === 'history' && 'History'}
          </h1>
          <div className="db-search-wrap">
            <svg className="db-search-icon" width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <circle cx="11" cy="11" r="8" />
              <line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            <input
              id="search-input"
              className="db-search"
              type="text"
              placeholder="Search"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </div>
        </header>

        {/* Content */}
        <section className="db-content">
          {activeNav === 'dashboard' && (
            <div className="db-grid">
              {/* Create New Card */}
              <button id="btn-create-template" className="db-card db-card-create">
                <div className="db-create-icon">
                  <svg width="32" height="32" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                    <circle cx="12" cy="12" r="10" />
                    <line x1="12" y1="8" x2="12" y2="16" />
                    <line x1="8" y1="12" x2="16" y2="12" />
                  </svg>
                </div>
                <span>Create New Template</span>
              </button>

              {/* Template Cards */}
              {filteredTemplates.map((t) => (
                <div key={t.id} className="db-card db-card-template" style={{ '--card-color': t.color }}>
                  <div className="db-card-preview">
                    {/* Mini form preview illustration */}
                    <div className="db-preview-lines">
                      <div className="db-preview-line db-line-wide" />
                      <div className="db-preview-line db-line-mid" />
                      <div className="db-preview-line db-line-short" />
                      <div className="db-preview-line db-line-mid" />
                    </div>
                  </div>
                  <div className="db-card-footer">
                    <div>
                      <p className="db-card-title">{t.title}</p>
                      <p className="db-card-date">Updated {t.updatedAt}</p>
                    </div>
                    <button className="db-card-menu" aria-label="Options">
                      <svg width="16" height="16" fill="currentColor" viewBox="0 0 24 24">
                        <circle cx="12" cy="5" r="1.5" />
                        <circle cx="12" cy="12" r="1.5" />
                        <circle cx="12" cy="19" r="1.5" />
                      </svg>
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}

          {activeNav === 'template' && (
            <div className="db-empty-state">
              <svg width="56" height="56" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}>
                <rect x="3" y="3" width="18" height="18" rx="2" />
                <path d="M3 9h18M9 21V9" />
              </svg>
              <p>Belum ada template</p>
            </div>
          )}

          {activeNav === 'history' && (
            <div className="db-empty-state">
              <svg width="56" height="56" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}>
                <polyline points="1 4 1 10 7 10" />
                <path d="M3.51 15a9 9 0 1 0 .49-4.39" />
              </svg>
              <p>Belum ada riwayat</p>
            </div>
          )}
        </section>
      </main>
    </div>
  );
}
