import { useEffect, useState, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { getMe, logout } from '../api/auth';
import { getMyForms, deleteForm } from '../api/forms';
import { getTemplates } from '../api/templates';
import '../styles/dashboard.css';

export default function DashboardPage() {
  const navigate = useNavigate();
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [activeNav, setActiveNav] = useState('dashboard');
  const [searchQuery, setSearchQuery] = useState('');
  const [templates, setTemplates] = useState([]);
  const [recentForms, setRecentForms] = useState([]);
  const [allForms, setAllForms] = useState([]);
  const [contextMenu, setContextMenu] = useState(null); // { formId, x, y }
  const [toast, setToast] = useState(null);
  const contextRef = useRef(null);

  const token = localStorage.getItem('token');

  useEffect(() => {
    if (!token) {
      navigate('/auth');
      return;
    }
    Promise.all([
      getMe(token),
      getTemplates(token).catch(() => []),
      getMyForms(token).catch(() => []),
    ])
      .then(([userData, tpls, forms]) => {
        setUser(userData);
        setTemplates(tpls);
        // Sort by created_at desc, take 3 for recent
        const sorted = [...forms].sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
        setAllForms(sorted);
        setRecentForms(sorted.slice(0, 3));
      })
      .catch(() => {
        logout();
        navigate('/auth');
      })
      .finally(() => setLoading(false));
  }, [navigate, token]);

  // Close context menu when clicking outside
  useEffect(() => {
    const handleClick = (e) => {
      if (contextRef.current && !contextRef.current.contains(e.target)) {
        setContextMenu(null);
      }
    };
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, []);

  const showToast = (msg, isError = false) => {
    setToast({ msg, isError });
    setTimeout(() => setToast(null), 3000);
  };

  const handleLogout = () => {
    logout();
    navigate('/auth');
  };

  const handleCreateBlank = () => {
    navigate('/form-builder');
  };

  const handleTemplateClick = (template) => {
    navigate(`/form-builder?template=${template.id}`);
  };

  const handleFormClick = (form) => {
    navigate(`/form-builder/${form.id}`);
  };

  const handleDeleteForm = async (formId) => {
    try {
      await deleteForm(token, formId);
      const updated = allForms.filter(f => f.id !== formId);
      setAllForms(updated);
      setRecentForms(updated.slice(0, 3));
      setContextMenu(null);
      showToast('Form berhasil dihapus');
    } catch (err) {
      showToast(err.message, true);
    }
  };

  const formatTimeAgo = (dateStr) => {
    const now = new Date();
    const date = new Date(dateStr);
    const diff = now - date;
    const mins = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days = Math.floor(diff / 86400000);
    const weeks = Math.floor(days / 7);
    const months = Math.floor(days / 30);

    if (mins < 1) return 'Baru saja';
    if (mins < 60) return `${mins} menit lalu`;
    if (hours < 24) return `${hours} jam lalu`;
    if (days < 7) return `${days} hari lalu`;
    if (weeks < 4) return `${weeks} minggu lalu`;
    return `${months} bulan lalu`;
  };

  const getInitials = (name = '') =>
    name.split(' ').slice(0, 2).map((w) => w[0]).join('').toUpperCase();

  // Separate system and user templates
  const systemTemplates = templates.filter(t => t.is_system);

  // Filter forms for search
  const filteredForms = allForms.filter(f =>
    f.title.toLowerCase().includes(searchQuery.toLowerCase())
  );

  if (loading) {
    return (
      <div className="db-loading">
        <div className="db-spinner" />
        <p>Memuat dashboard...</p>
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
            <svg width="36" height="36" viewBox="0 0 36 36" fill="none">
              <rect width="36" height="36" rx="8" fill="url(#logo-grad-db)" />
              <text x="7" y="25" fontFamily="Inter, sans-serif" fontWeight="800" fontSize="18" fill="#fff">F4</text>
              <defs>
                <linearGradient id="logo-grad-db" x1="0" y1="0" x2="36" y2="36" gradientUnits="userSpaceOnUse">
                  <stop stopColor="#3b82f6" />
                  <stop offset="1" stopColor="#1d4ed8" />
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
          {/* ===== DASHBOARD VIEW ===== */}
          {activeNav === 'dashboard' && (
            <>
              {/* Template Cards Row */}
              <div className="db-templates-row">
                {/* Create New */}
                <button id="btn-create-blank" className="db-card-create" onClick={handleCreateBlank}>
                  <div className="db-create-icon">
                    <svg width="28" height="28" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                      <circle cx="12" cy="12" r="10" />
                      <line x1="12" y1="8" x2="12" y2="16" />
                      <line x1="8" y1="12" x2="16" y2="12" />
                    </svg>
                  </div>
                  <span>Create New Template</span>
                </button>

                {/* System Templates */}
                {systemTemplates.length > 0 ? (
                  systemTemplates.map((tpl, idx) => {
                    const bgClass = idx === 0 ? 'blank-bg' : idx === 1 ? 'attendance-bg' : 'exam-bg';
                    const subtitles = ['Start from scratch', 'Event or class tracking', 'Assessments & Quizzes'];
                    return (
                      <div
                        key={tpl.id}
                        className="db-card-system"
                        onClick={() => handleTemplateClick(tpl)}
                      >
                        <div className={`db-card-preview ${bgClass}`}>
                          {idx === 2 && (
                            <span className="db-badge">
                              <svg viewBox="0 0 16 16" fill="currentColor"><circle cx="8" cy="8" r="6" /></svg>
                              Free enabled by default
                            </span>
                          )}
                          <div className="db-preview-doc">
                            <div className="db-preview-line db-line-wide" />
                            <div className="db-preview-line db-line-mid" />
                            <div className="db-preview-line db-line-short" />
                            <div className="db-preview-line db-line-mid" />
                          </div>
                        </div>
                        <div className="db-card-info">
                          <p className="db-card-title">{tpl.title}</p>
                          <p className="db-card-subtitle">{subtitles[idx] || tpl.description || ''}</p>
                        </div>
                      </div>
                    );
                  })
                ) : (
                  <>
                    {/* Fallback static cards when no system templates exist */}
                    {[
                      { title: 'Blank Form', subtitle: 'Start from scratch', bg: 'blank-bg' },
                      { title: 'Attendance Form', subtitle: 'Event or class tracking', bg: 'attendance-bg' },
                      { title: 'Exam Form', subtitle: 'Assessments & Quizzes', bg: 'exam-bg', badge: true },
                    ].map((card, idx) => (
                      <div key={idx} className="db-card-system" onClick={handleCreateBlank}>
                        <div className={`db-card-preview ${card.bg}`}>
                          {card.badge && (
                            <span className="db-badge">
                              <svg viewBox="0 0 16 16" fill="currentColor"><circle cx="8" cy="8" r="6" /></svg>
                              Free enabled by default
                            </span>
                          )}
                          <div className="db-preview-doc">
                            <div className="db-preview-line db-line-wide" />
                            <div className="db-preview-line db-line-mid" />
                            <div className="db-preview-line db-line-short" />
                            <div className="db-preview-line db-line-mid" />
                          </div>
                        </div>
                        <div className="db-card-info">
                          <p className="db-card-title">{card.title}</p>
                          <p className="db-card-subtitle">{card.subtitle}</p>
                        </div>
                      </div>
                    ))}
                  </>
                )}
              </div>

              {/* Recent History */}
              <h2 className="db-section-title">Recent History</h2>
              {recentForms.length > 0 ? (
                <div className="db-recent-grid">
                  {recentForms.map((form) => (
                    <div key={form.id} className="db-recent-card" onClick={() => handleFormClick(form)}>
                      <div className="db-recent-preview">
                        {form.banner_url ? (
                          <img src={form.banner_url} alt={form.title} className="db-recent-banner" />
                        ) : (
                          <div className="db-preview-doc">
                            <div className="db-preview-line db-line-wide" />
                            <div className="db-preview-line db-line-mid" />
                            <div className="db-preview-line db-line-short" />
                          </div>
                        )}
                      </div>
                      <div className="db-recent-footer">
                        <div>
                          <p className="db-recent-title">{form.title}</p>
                          <p className="db-recent-date">Updated {formatTimeAgo(form.created_at)}</p>
                        </div>
                        <div style={{ position: 'relative' }}>
                          <button
                            className="db-card-menu"
                            aria-label="Options"
                            onClick={(e) => {
                              e.stopPropagation();
                              setContextMenu(contextMenu?.formId === form.id ? null : { formId: form.id });
                            }}
                          >
                            <svg width="16" height="16" fill="currentColor" viewBox="0 0 24 24">
                              <circle cx="12" cy="5" r="1.5" />
                              <circle cx="12" cy="12" r="1.5" />
                              <circle cx="12" cy="19" r="1.5" />
                            </svg>
                          </button>
                          {contextMenu?.formId === form.id && (
                            <div className="db-context-menu" ref={contextRef}>
                              <button className="db-context-item" onClick={(e) => { e.stopPropagation(); handleFormClick(form); }}>
                                <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                                  <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7" />
                                  <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z" />
                                </svg>
                                Edit
                              </button>
                              <button className="db-context-item danger" onClick={(e) => { e.stopPropagation(); handleDeleteForm(form.id); }}>
                                <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                                  <polyline points="3 6 5 6 21 6" />
                                  <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2" />
                                </svg>
                                Hapus
                              </button>
                            </div>
                          )}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="db-empty-state">
                  <svg width="48" height="48" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}>
                    <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" />
                    <polyline points="14 2 14 8 20 8" />
                  </svg>
                  <p>Belum ada form. Mulai buat form pertamamu!</p>
                </div>
              )}
            </>
          )}

          {/* ===== TEMPLATE VIEW ===== */}
          {activeNav === 'template' && (
            <>
              <h2 className="db-section-title">Semua Template</h2>
              {templates.length > 0 ? (
                <div className="db-recent-grid">
                  {templates.map((tpl) => (
                    <div key={tpl.id} className="db-recent-card" onClick={() => handleTemplateClick(tpl)}>
                      <div className="db-recent-preview">
                        <div className="db-preview-doc">
                          <div className="db-preview-line db-line-wide" />
                          <div className="db-preview-line db-line-mid" />
                          <div className="db-preview-line db-line-short" />
                        </div>
                      </div>
                      <div className="db-recent-footer">
                        <div>
                          <p className="db-recent-title">{tpl.title}</p>
                          <p className="db-recent-date">{tpl.is_system ? 'System Template' : 'My Template'}</p>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="db-empty-state">
                  <svg width="48" height="48" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}>
                    <rect x="3" y="3" width="18" height="18" rx="2" />
                    <path d="M3 9h18M9 21V9" />
                  </svg>
                  <p>Belum ada template</p>
                </div>
              )}
            </>
          )}

          {/* ===== HISTORY VIEW ===== */}
          {activeNav === 'history' && (
            <>
              <h2 className="db-section-title">Riwayat Form</h2>
              {filteredForms.length > 0 ? (
                <div className="db-recent-grid">
                  {filteredForms.map((form) => (
                    <div key={form.id} className="db-recent-card" onClick={() => handleFormClick(form)}>
                      <div className="db-recent-preview">
                        {form.banner_url ? (
                          <img src={form.banner_url} alt={form.title} className="db-recent-banner" />
                        ) : (
                          <div className="db-preview-doc">
                            <div className="db-preview-line db-line-wide" />
                            <div className="db-preview-line db-line-mid" />
                            <div className="db-preview-line db-line-short" />
                          </div>
                        )}
                      </div>
                      <div className="db-recent-footer">
                        <div>
                          <p className="db-recent-title">{form.title}</p>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '4px' }}>
                            <span className={`db-status ${form.status}`}>{form.status}</span>
                            <span className="db-recent-date">{form.total_submissions} respons</span>
                          </div>
                        </div>
                        <div style={{ position: 'relative' }}>
                          <button
                            className="db-card-menu"
                            aria-label="Options"
                            onClick={(e) => {
                              e.stopPropagation();
                              setContextMenu(contextMenu?.formId === form.id ? null : { formId: form.id });
                            }}
                          >
                            <svg width="16" height="16" fill="currentColor" viewBox="0 0 24 24">
                              <circle cx="12" cy="5" r="1.5" />
                              <circle cx="12" cy="12" r="1.5" />
                              <circle cx="12" cy="19" r="1.5" />
                            </svg>
                          </button>
                          {contextMenu?.formId === form.id && (
                            <div className="db-context-menu" ref={contextRef}>
                              <button className="db-context-item" onClick={(e) => { e.stopPropagation(); handleFormClick(form); }}>
                                <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                                  <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7" />
                                  <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z" />
                                </svg>
                                Edit
                              </button>
                              <button className="db-context-item danger" onClick={(e) => { e.stopPropagation(); handleDeleteForm(form.id); }}>
                                <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                                  <polyline points="3 6 5 6 21 6" />
                                  <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2" />
                                </svg>
                                Hapus
                              </button>
                            </div>
                          )}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="db-empty-state">
                  <svg width="48" height="48" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}>
                    <polyline points="1 4 1 10 7 10" />
                    <path d="M3.51 15a9 9 0 1 0 .49-4.39" />
                  </svg>
                  <p>Belum ada riwayat</p>
                </div>
              )}
            </>
          )}
        </section>
      </main>

      {/* Toast */}
      {toast && (
        <div className={`db-toast ${toast.isError ? 'error' : ''}`}>
          {toast.msg}
        </div>
      )}
    </div>
  );
}
