import { useEffect, useState, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { getMe, logout } from '../api/auth';
import { getMyForms, deleteForm, getForm, getFormSubmissions, exportSubmissions } from '../api/forms';
import { getTemplates, deleteTemplate } from '../api/templates';
import { parseServerTime } from '../utils/date';
import logoForm4x from '../assets/logo_form4x.png';
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
  const [contextMenu, setContextMenu] = useState(null); // { type: 'form'|'template', id }
  const [toast, setToast] = useState(null);
  const contextRef = useRef(null);

  // History / Results Subviews: 'list' | 'results' | 'detail'
  const [historySubView, setHistorySubView] = useState('list');
  const [selectedFormForResults, setSelectedFormForResults] = useState(null);
  const [formDetail, setFormDetail] = useState(null);
  const [submissionsList, setSubmissionsList] = useState([]);
  const [resultsLoading, setResultsLoading] = useState(false);
  const [exporting, setExporting] = useState(false);

  // Filters & Selected Respondent
  const [statusFilter, setStatusFilter] = useState('all'); // 'all' | 'completed' | 'process'
  const [respondentSearch, setRespondentSearch] = useState('');
  const [selectedRespondent, setSelectedRespondent] = useState(null);
  const [confirmDeleteForm, setConfirmDeleteForm] = useState(null); // objek form yang mau dihapus

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
        const sorted = [...forms].sort((a, b) => parseServerTime(b.created_at) - parseServerTime(a.created_at));
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
      const updated = allForms.filter((f) => f.id !== formId);
      setAllForms(updated);
      setRecentForms(updated.slice(0, 3));
      setContextMenu(null);
      showToast('Form berhasil dihapus');
    } catch (err) {
      showToast(err.message, true);
    }
  };

  const handleConfirmDelete = async () => {
    if (!confirmDeleteForm) return;
    await handleDeleteForm(confirmDeleteForm.id);
    setConfirmDeleteForm(null);
  };

  const handleDeleteTemplate = async (templateId) => {
    try {
      await deleteTemplate(token, templateId);
      setTemplates((prev) => prev.filter((t) => t.id !== templateId));
      setContextMenu(null);
      showToast('Template berhasil dihapus');
    } catch (err) {
      showToast(err.message, true);
    }
  };

  // Open Full-Page Results View ("Lihat Hasil")
  const handleOpenResultsPage = async (form) => {
    setSelectedFormForResults(form);
    setHistorySubView('results');
    setResultsLoading(true);
    setSelectedRespondent(null);
    setRespondentSearch('');
    setStatusFilter('all');

    try {
      const [detail, subs] = await Promise.all([
        getForm(token, form.id),
        getFormSubmissions(token, form.id),
      ]);
      setFormDetail(detail);

      // Calculate Quiz scoring and duration for each submission
      const processedSubs = subs.map((sub) => {
        let correctCount = 0;
        let totalGradable = 0;

        const questions = (detail.questions || []).sort((a, b) => a.order_index - b.order_index);

        questions.forEach((q) => {
          const correctOpts = (q.options || []).filter((o) => o.is_correct).map((o) => o.label);
          if (correctOpts.length > 0) {
            totalGradable += 1;
            const ans = (sub.answers || []).find((a) => a.question_id === q.id);
            if (ans) {
              const userSelected = ans.answer_options || (ans.answer_text ? [ans.answer_text] : []);
              const isMatch =
                correctOpts.length === userSelected.length &&
                correctOpts.every((opt) => userSelected.includes(opt));
              if (isMatch) {
                correctCount += 1;
              }
            }
          }
        });

        const scorePercent = totalGradable > 0 ? Math.round((correctCount / totalGradable) * 100) : null;

        // Duration calculation
        let durationMinutes = 0;
        let durationStr = '-';
        if (sub.started_at && sub.submitted_at) {
          const diffMs = parseServerTime(sub.submitted_at).getTime() - parseServerTime(sub.started_at).getTime();
          const totalSecs = Math.max(0, Math.floor(diffMs / 1000));
          const mins = Math.floor(totalSecs / 60);
          const secs = totalSecs % 60;
          durationMinutes = mins;
          durationStr = mins > 0 ? `${mins}m ${secs}s` : `${secs}s`;
        }

        return {
          ...sub,
          correctCount,
          totalGradable,
          scorePercent,
          durationMinutes,
          durationStr,
          isCompleted: !!sub.submitted_at,
        };
      });

      setSubmissionsList(processedSubs);
    } catch (err) {
      showToast(err.message || 'Gagal memuat hasil respons', true);
    } finally {
      setResultsLoading(false);
    }
  };

  // Trigger Excel Download
  const handleExportExcel = async () => {
    if (!selectedFormForResults) return;
    try {
      setExporting(true);
      await exportSubmissions(token, selectedFormForResults.id, selectedFormForResults.slug);
      showToast('File Excel berhasil diunduh!');
    } catch (err) {
      showToast(err.message || 'Gagal mengekspor data', true);
    } finally {
      setExporting(false);
    }
  };

  const formatTimeAgo = (dateStr) => {
    if (!dateStr) return '';
    const now = new Date();
    const date = parseServerTime(dateStr);
    if (!date) return '';
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

  const formatDateString = (dateStr) => {
    if (!dateStr) return '-';
    const date = parseServerTime(dateStr);
    if (!date) return '-';
    return date.toLocaleString('id-ID', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const getInitials = (name = '') =>
    name.split(' ').slice(0, 2).map((w) => w[0]).join('').toUpperCase();

  const systemTemplates = templates.filter((t) => t.is_system);

  const filteredForms = allForms.filter((f) =>
    f.title.toLowerCase().includes(searchQuery.toLowerCase())
  );

  // Filter respondents by search & status
  const filteredRespondents = submissionsList.filter((sub) => {
    const name = sub.user?.full_name || 'Responden (User)';
    const email = sub.user?.email || '';
    const matchesSearch =
      name.toLowerCase().includes(respondentSearch.toLowerCase()) ||
      email.toLowerCase().includes(respondentSearch.toLowerCase());

    if (!matchesSearch) return false;
    if (statusFilter === 'completed') return sub.isCompleted;
    if (statusFilter === 'process') return !sub.isCompleted;
    return true;
  });

  // Calculate Overall Stats for View 1
  const totalRespondents = submissionsList.length;
  const scoredSubs = submissionsList.filter((s) => s.scorePercent !== null);
  const avgScore =
    scoredSubs.length > 0
      ? Math.round(scoredSubs.reduce((acc, curr) => acc + curr.scorePercent, 0) / scoredSubs.length)
      : null;

  const completedSubs = submissionsList.filter((s) => s.isCompleted);
  const avgDuration =
    completedSubs.length > 0
      ? Math.round(completedSubs.reduce((acc, curr) => acc + curr.durationMinutes, 0) / completedSubs.length)
      : 0;

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
      {/* Sidebar - Preserved and always active */}
      <aside className="db-sidebar">
        <div className="db-logo">
          <div className="db-logo-icon">
            <img src={logoForm4x} alt="Form4x logo" className="db-logo-img" />
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
              onClick={() => {
                setActiveNav(item.key);
                setHistorySubView('list');
              }}
            >
              {item.icon}
              <span>{item.label}</span>
            </button>
          ))}
        </nav>

        {/* User Footer */}
        <div className="db-sidebar-footer">
          <div
            className="db-user"
            onClick={() => navigate('/profile')}
            title="Lihat & Edit Profil"
            style={{ cursor: 'pointer' }}
          >
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

      {/* Main Content Panel */}
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

        {/* Content Area */}
        <section className="db-content">
          {/* ===== DASHBOARD VIEW ===== */}
          {activeNav === 'dashboard' && (
            <>
              <div className="db-templates-row">
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
                              <svg width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                                <circle cx="12" cy="12" r="10" />
                                <polyline points="12 6 12 12 16 14" />
                              </svg>
                              Timer Enabled
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
                    {[
                      { title: 'Blank Form', subtitle: 'Start from scratch', bg: 'blank-bg' },
                      { title: 'Attendance Form', subtitle: 'Event or class tracking', bg: 'attendance-bg' },
                      { title: 'Exam Form', subtitle: 'Assessments & Quizzes', bg: 'exam-bg', badge: true },
                    ].map((card, idx) => (
                      <div key={idx} className="db-card-system" onClick={handleCreateBlank}>
                        <div className={`db-card-preview ${card.bg}`}>
                          {card.badge && (
                            <span className="db-badge">
                              <svg width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                                <circle cx="12" cy="12" r="10" />
                                <polyline points="12 6 12 12 16 14" />
                              </svg>
                              Timer Enabled
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
                              setContextMenu(contextMenu?.type === 'form' && contextMenu.id === form.id ? null : { type: 'form', id: form.id });
                            }}
                          >
                            <svg width="16" height="16" fill="currentColor" viewBox="0 0 24 24">
                              <circle cx="12" cy="5" r="1.5" />
                              <circle cx="12" cy="12" r="1.5" />
                              <circle cx="12" cy="19" r="1.5" />
                            </svg>
                          </button>
                          {contextMenu?.type === 'form' && contextMenu.id === form.id && (
                            <div className="db-context-menu" ref={contextRef}>
                              <button className="db-context-item" onClick={(e) => { e.stopPropagation(); handleFormClick(form); }}>
                                <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                                  <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7" />
                                  <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z" />
                                </svg>
                                Edit
                              </button>
                              <button className="db-context-item danger" onClick={(e) => { e.stopPropagation(); setConfirmDeleteForm(form); }}>
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
                        {tpl.banner_url ? (
                          <img src={tpl.banner_url} alt={tpl.title} className="db-recent-banner" />
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
                          <p className="db-recent-title">{tpl.title}</p>
                          <p className="db-recent-date">{tpl.is_system ? 'System Template' : 'My Template'}</p>
                        </div>
                        {!tpl.is_system && (
                          <div style={{ position: 'relative' }}>
                            <button
                              className="db-card-menu"
                              aria-label="Options"
                              onClick={(e) => {
                                e.stopPropagation();
                                setContextMenu(contextMenu?.type === 'template' && contextMenu.id === tpl.id ? null : { type: 'template', id: tpl.id });
                              }}
                            >
                              <svg width="16" height="16" fill="currentColor" viewBox="0 0 24 24">
                                <circle cx="12" cy="5" r="1.5" />
                                <circle cx="12" cy="12" r="1.5" />
                                <circle cx="12" cy="19" r="1.5" />
                              </svg>
                            </button>
                            {contextMenu?.type === 'template' && contextMenu.id === tpl.id && (
                              <div className="db-context-menu" ref={contextRef}>
                                <button className="db-context-item danger" onClick={(e) => { e.stopPropagation(); handleDeleteTemplate(tpl.id); }}>
                                  <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                                    <polyline points="3 6 5 6 21 6" />
                                    <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2" />
                                  </svg>
                                  Hapus
                                </button>
                              </div>
                            )}
                          </div>
                        )}
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
              {/* SUBVIEW 1: FORM CARDS GRID */}
              {historySubView === 'list' && (
                <>
                  <h2 className="db-section-title">Riwayat Form</h2>
                  {filteredForms.length > 0 ? (
                    <div className="history-card-grid">
                      {filteredForms.map((form) => (
                        <div key={form.id} className="history-card">
                          <div className="history-card-preview">
                            {form.banner_url ? (
                              <img src={form.banner_url} alt={form.title} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                            ) : (
                              <div className="db-preview-doc">
                                <div className="db-preview-line db-line-wide" />
                                <div className="db-preview-line db-line-mid" />
                                <div className="db-preview-line db-line-short" />
                              </div>
                            )}
                          </div>
                          <div style={{ position: 'absolute', top: 10, right: 10, zIndex: 5 }}>
                            <button
                              className="db-card-menu history-card-menu"
                              aria-label="Opsi Form"
                              onClick={(e) => {
                                e.stopPropagation();
                                setContextMenu(contextMenu?.type === 'form' && contextMenu.id === form.id ? null : { type: 'form', id: form.id });
                              }}
                            >
                              <svg width="16" height="16" fill="currentColor" viewBox="0 0 24 24">
                                <circle cx="12" cy="5" r="1.5" />
                                <circle cx="12" cy="12" r="1.5" />
                                <circle cx="12" cy="19" r="1.5" />
                              </svg>
                            </button>
                            {contextMenu?.type === 'form' && contextMenu.id === form.id && (
                              <div className="db-context-menu" ref={contextRef}>
                                <button className="db-context-item" onClick={(e) => { e.stopPropagation(); handleFormClick(form); }}>
                                  <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                                    <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7" />
                                    <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z" />
                                  </svg>
                                  Edit
                                </button>
                                <button className="db-context-item danger" onClick={(e) => { e.stopPropagation(); setConfirmDeleteForm(form); }}>
                                  <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                                    <polyline points="3 6 5 6 21 6" />
                                    <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2" />
                                  </svg>
                                  Hapus
                                </button>
                              </div>
                            )}
                          </div>
                          <div className="history-card-body">
                            <div className="history-card-info">
                              <h3 className="history-card-title" title={form.title}>{form.title}</h3>
                              <div className="history-card-status-wrap">
                                <span className={`db-status ${form.status}`}>{form.status}</span>
                              </div>
                              <span className="history-card-responses-text">{form.total_submissions} Respons</span>
                            </div>
                            <button
                              className="history-btn-result"
                              onClick={() => handleOpenResultsPage(form)}
                            >
                              Lihat Hasil
                            </button>
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
                      <p>Belum ada riwayat form</p>
                    </div>
                  )}
                </>
              )}

              {/* SUBVIEW 2: HASIL RESPONDEN (Image 1 Mockup) */}
              {historySubView === 'results' && selectedFormForResults && (
                <div className="results-page-container">
                  {/* Top Bar Navigation & Header */}
                  <div className="results-header-row">
                    <div className="results-header-titles">
                      <button
                        className="back-nav-btn"
                        onClick={() => setHistorySubView('list')}
                        style={{ marginBottom: '8px' }}
                      >
                        ← Kembali ke Riwayat Form
                      </button>
                      <h2>Riwayat Form</h2>
                      <p>Hasil Responden - <strong>{selectedFormForResults.title}</strong></p>
                    </div>

                    <button
                      className="btn-export-excel"
                      onClick={handleExportExcel}
                      disabled={exporting || submissionsList.length === 0}
                    >
                      <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                      </svg>
                      <span>{exporting ? 'Mengekspor...' : 'Ekspor ke Excel'}</span>
                    </button>
                  </div>

                  {/* 3 Summary Stats Cards */}
                  <div className="stats-cards-grid">
                    {/* Card 1: Total Responden */}
                    <div className="stat-card">
                      <div className="stat-icon-box">
                        <svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                        </svg>
                      </div>
                      <div className="stat-info-wrap">
                        <span className="stat-label">TOTAL RESPONDEN</span>
                        <span className="stat-value">{totalRespondents}</span>
                      </div>
                    </div>

                    {/* Card 2: Rata-Rata Skor */}
                    <div className="stat-card">
                      <div className="stat-icon-box">
                        <svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <path strokeLinecap="round" strokeLinejoin="round" d="M9 19v-6a2 2 0 012-2h2a2 2 0 012 2v6m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2" />
                        </svg>
                      </div>
                      <div className="stat-info-wrap">
                        <span className="stat-label">RATA-RATA SKOR</span>
                        <span className="stat-value">{avgScore !== null ? `${avgScore}/100` : '-'}</span>
                      </div>
                    </div>

                    {/* Card 3: Waktu Rata-Rata */}
                    <div className="stat-card">
                      <div className="stat-icon-box">
                        <svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <path strokeLinecap="round" strokeLinejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                      </div>
                      <div className="stat-info-wrap">
                        <span className="stat-label">WAKTU RATA-RATA</span>
                        <span className="stat-value">{avgDuration > 0 ? `${avgDuration} Menit` : '-'}</span>
                      </div>
                    </div>
                  </div>

                  {/* Table Card Container */}
                  <div className="table-card-container">
                    <div className="table-card-header">
                      <h3 className="table-card-title">Daftar Responden</h3>
                      <div className="table-header-filters">
                        <input
                          type="text"
                          className="db-search"
                          placeholder="Cari nama atau email..."
                          value={respondentSearch}
                          onChange={(e) => setRespondentSearch(e.target.value)}
                          style={{ width: '220px', padding: '6px 12px', fontSize: '13px' }}
                        />
                        <select
                          className="filter-select"
                          value={statusFilter}
                          onChange={(e) => setStatusFilter(e.target.value)}
                        >
                          <option value="all">Semua Status</option>
                          <option value="completed">Selesai</option>
                          <option value="process">Proses</option>
                        </select>
                      </div>
                    </div>

                    {resultsLoading ? (
                      <div style={{ textAlign: 'center', padding: '48px 0', color: '#64748B' }}>
                        <div className="db-spinner" style={{ margin: '0 auto 12px' }} />
                        <p>Memuat daftar responden...</p>
                      </div>
                    ) : filteredRespondents.length === 0 ? (
                      <div className="db-empty-state" style={{ padding: '40px 0' }}>
                        <p>Belum ada data responden yang sesuai.</p>
                      </div>
                    ) : (
                      <div className="resp-table-wrap">
                        <table className="resp-data-table">
                          <thead>
                            <tr>
                              <th>NAMA</th>
                              <th>EMAIL</th>
                              <th>TANGGAL SUBMIT</th>
                              <th>SKOR</th>
                              <th>STATUS</th>
                              <th style={{ textAlign: 'right' }}>AKSI</th>
                            </tr>
                          </thead>
                          <tbody>
                            {filteredRespondents.map((sub) => {
                              const name = sub.user?.full_name || 'Responden (User)';
                              const email = sub.user?.email || '-';
                              const isCompleted = sub.isCompleted;

                              return (
                                <tr key={sub.id}>
                                  <td className="td-user-name">{name}</td>
                                  <td className="td-user-email">{email}</td>
                                  <td>{formatDateString(sub.submitted_at || sub.started_at)}</td>
                                  <td className="td-score-val">
                                    {sub.scorePercent !== null ? `${sub.scorePercent}/100` : '-'}
                                  </td>
                                  <td>
                                    <span className={`status-pill ${isCompleted ? 'completed' : 'process'}`}>
                                      • {isCompleted ? 'Selesai' : 'Proses'}
                                    </span>
                                  </td>
                                  <td style={{ textAlign: 'right' }}>
                                    <button
                                      className="btn-table-view"
                                      onClick={() => {
                                        setSelectedRespondent(sub);
                                        setHistorySubView('detail');
                                      }}
                                    >
                                      Lihat Jawaban »
                                    </button>
                                  </td>
                                </tr>
                              );
                            })}
                          </tbody>
                        </table>
                      </div>
                    )}

                    <div className="table-card-footer">
                      <span>
                        Menampilkan {filteredRespondents.length > 0 ? 1 : 0}-{filteredRespondents.length} dari {totalRespondents} responden
                      </span>
                      <div className="pagination-arrows">
                        <button className="pagination-btn" disabled>‹</button>
                        <button className="pagination-btn" disabled>›</button>
                      </div>
                    </div>
                  </div>

                  {/* Visual Analytics & Question Summary Charts */}
                  <div className="analytics-section">
                    <div className="analytics-section-header">
                      <div>
                        <h3 className="analytics-section-title">
                          <svg width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                            <path strokeLinecap="round" strokeLinejoin="round" d="M9 19v-6a2 2 0 012-2h2a2 2 0 012 2v6m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2" />
                          </svg>
                          Ringkasan & Visualisasi Jawaban
                        </h3>
                        <p className="analytics-section-subtitle">Analisis statistik distribusi jawaban responden per pertanyaan</p>
                      </div>
                    </div>

                    <div className="analytics-questions-grid">
                      {(formDetail?.questions || [])
                        .sort((a, b) => a.order_index - b.order_index)
                        .map((q, idx) => {
                          const typeLabels = {
                            text: 'Teks', single_choice: 'Pilihan Ganda', checkbox: 'Checkbox',
                            dropdown: 'Dropdown', date: 'Tanggal', file_upload: 'Upload File',
                          };

                          // Find all answers for this question across all submissions
                          const allAnsForQ = submissionsList
                            .map((sub) => ({
                              ans: (sub.answers || []).find((a) => a.question_id === q.id),
                              user: sub.user,
                              submittedAt: sub.submitted_at,
                            }))
                            .filter((item) => {
                              const a = item.ans;
                              if (!a) return false;
                              return !!(a.answer_text || (Array.isArray(a.answer_options) && a.answer_options.length > 0) || a.file_url);
                            });

                          const answeredCountForQ = allAnsForQ.length;
                          const isOptionType = ['single_choice', 'checkbox', 'dropdown'].includes(q.type) && q.options?.length > 0;
                          const colorPalette = [
                            'linear-gradient(90deg, #0053db, #2563eb)',
                            'linear-gradient(90deg, #10b981, #059669)',
                            'linear-gradient(90deg, #f59e0b, #d97706)',
                            'linear-gradient(90deg, #8b5cf6, #7c3aed)',
                            'linear-gradient(90deg, #ec4899, #db2777)',
                            'linear-gradient(90deg, #6366f1, #4f46e5)',
                          ];

                          return (
                            <div key={q.id} className="analytics-question-card">
                              <div className="analytics-q-header">
                                <h4 className="analytics-q-title">
                                  {idx + 1}. {q.label}
                                </h4>
                                <div className="analytics-q-tags">
                                  <span className="analytics-type-badge">{typeLabels[q.type] || q.type}</span>
                                  <span className="analytics-resp-badge">{answeredCountForQ} Respons</span>
                                </div>
                              </div>

                              {/* Option Charts */}
                              {isOptionType ? (
                                <div className="analytics-chart-wrap">
                                  {q.options.map((opt, oIdx) => {
                                    // Calculate how many respondents picked this option
                                    const pickCount = allAnsForQ.filter((item) => {
                                      const a = item.ans;
                                      if (Array.isArray(a.answer_options)) {
                                        return a.answer_options.includes(opt.label);
                                      }
                                      return a.answer_text === opt.label;
                                    }).length;

                                    const percent = answeredCountForQ > 0 ? Math.round((pickCount / answeredCountForQ) * 100) : 0;
                                    const gradient = colorPalette[oIdx % colorPalette.length];

                                    return (
                                      <div key={opt.id} className="analytics-bar-item">
                                        <div className="analytics-bar-info">
                                          <div className="analytics-opt-label">
                                            <span>{opt.label}</span>
                                            {opt.is_correct && <span className="analytics-correct-key">✓ Kunci Jawaban</span>}
                                          </div>
                                          <span className="analytics-opt-stats">
                                            <strong>{percent}%</strong> ({pickCount} responden)
                                          </span>
                                        </div>
                                        <div className="analytics-bar-track">
                                          <div
                                            className="analytics-bar-fill"
                                            style={{
                                              width: `${percent}%`,
                                              background: gradient,
                                            }}
                                          />
                                        </div>
                                      </div>
                                    );
                                  })}
                                </div>
                              ) : (
                                /* Text / Date / File Upload feed summary */
                                <div className="analytics-text-feed">
                                  {allAnsForQ.length === 0 ? (
                                    <p className="analytics-empty-text">Belum ada jawaban untuk pertanyaan ini.</p>
                                  ) : (
                                    allAnsForQ.slice(0, 5).map((item, itemIdx) => (
                                      <div key={itemIdx} className="analytics-feed-row">
                                        <div className="analytics-feed-user">
                                          <strong>{item.user?.full_name || 'Responden'}</strong>
                                          <span>• {item.submittedAt ? formatDateString(item.submittedAt) : 'Proses'}</span>
                                        </div>
                                        <div className="analytics-feed-ans">
                                          {q.type === 'file_upload' && item.ans.file_url ? (
                                            <a href={item.ans.file_url} target="_blank" rel="noopener noreferrer" style={{ color: '#0053db', fontWeight: 600 }}>
                                              Lihat File Upload ↗
                                            </a>
                                          ) : (
                                            item.ans.answer_text || '-'
                                          )}
                                        </div>
                                      </div>
                                    ))
                                  )}
                                  {allAnsForQ.length > 5 && (
                                    <div className="analytics-feed-more">
                                      + {allAnsForQ.length - 5} jawaban lainnya (lihat di detail responden)
                                    </div>
                                  )}
                                </div>
                              )}
                            </div>
                          );
                        })}
                    </div>
                  </div>
                </div>
              )}

              {/* SUBVIEW 3: INDIVIDUAL RESPONDENT ANSWER DETAIL (Image 2 Mockup) */}
              {historySubView === 'detail' && selectedRespondent && (
                <div className="results-page-container">
                  <button
                    className="back-nav-btn"
                    onClick={() => setHistorySubView('results')}
                  >
                    ← Kembali ke Daftar Responden
                  </button>

                  {/* Header Summary Card */}
                  <div className="detail-header-card">
                    <div>
                      <span className="detail-header-formtitle">
                        {formDetail?.title || selectedFormForResults?.title}
                      </span>
                      <h2 className="detail-header-name">
                        {selectedRespondent.user?.full_name || 'Responden (User)'}
                      </h2>
                      <div className="detail-header-metarow">
                        <span className="detail-meta-item">
                          <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                            <path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                          </svg>
                          {selectedRespondent.user?.email || '-'}
                        </span>
                        <span className="detail-meta-item">
                          <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                            <path strokeLinecap="round" strokeLinejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                          </svg>
                          {selectedRespondent.durationStr}
                        </span>
                        <span className="detail-meta-item">
                          <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                            <path strokeLinecap="round" strokeLinejoin="round" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                          </svg>
                          {formatDateString(selectedRespondent.submitted_at || selectedRespondent.started_at)} WIB
                        </span>
                      </div>
                    </div>

                    {selectedRespondent.scorePercent !== null && (
                      <div className="detail-score-box">
                        <p className="detail-score-label">Total Nilai</p>
                        <h3 className="detail-score-num">{selectedRespondent.scorePercent}/100</h3>
                      </div>
                    )}
                  </div>

                  {/* Questions & Answers Breakdown */}
                  <div>
                    {(formDetail?.questions || [])
                      .sort((a, b) => a.order_index - b.order_index)
                      .map((q, idx) => {
                        const ans = (selectedRespondent.answers || []).find((a) => a.question_id === q.id);
                        const points = q.settings?.points || null;
                        const correctOpts = (q.options || []).filter((o) => o.is_correct).map((o) => o.label);
                        const isQuizQ = correctOpts.length > 0;
                        const userSelected = ans?.answer_options || (ans?.answer_text ? [ans.answer_text] : []);

                        // Type label for badge
                        const typeLabels = {
                          text: 'Teks', single_choice: 'Pilihan Ganda', checkbox: 'Checkbox',
                          dropdown: 'Dropdown', date: 'Tanggal', file_upload: 'Upload File',
                        };

                        // Determine if this question has renderable options (single_choice, checkbox, dropdown)
                        const hasOptionType = ['single_choice', 'checkbox', 'dropdown'].includes(q.type) && q.options?.length > 0;

                        return (
                          <div key={q.id} className="detail-question-card">
                            <div className="detail-question-header">
                              <h3 className="detail-question-title">
                                {idx + 1}. {q.label}
                              </h3>
                              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexShrink: 0 }}>
                                <span style={{ background: '#f1f5f9', color: '#64748b', fontSize: '11px', fontWeight: 600, padding: '3px 10px', borderRadius: '6px' }}>
                                  {typeLabels[q.type] || q.type}
                                </span>
                                {points !== null && <span className="detail-points-badge">{points} Poin</span>}
                              </div>
                            </div>

                            {/* Option-based questions (single_choice, checkbox, dropdown) */}
                            {hasOptionType ? (
                              <div>
                                {q.options.map((opt) => {
                                  const isSelected = userSelected.includes(opt.label);
                                  const isCorrectKey = opt.is_correct;

                                  let cardClass = 'detail-option-card';
                                  if (isSelected && isCorrectKey) {
                                    cardClass += ' selected-correct';
                                  } else if (isSelected && !isCorrectKey && isQuizQ) {
                                    cardClass += ' selected-incorrect';
                                  } else if (isSelected && !isQuizQ) {
                                    cardClass += ' selected-correct';
                                  } else if (!isSelected && isCorrectKey && isQuizQ) {
                                    cardClass += ' is-correct-key';
                                  }

                                  return (
                                    <div key={opt.id} className={cardClass}>
                                      <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                                        <div
                                          style={{
                                            width: '18px',
                                            height: '18px',
                                            borderRadius: q.type === 'checkbox' ? '4px' : '50%',
                                            border: isSelected
                                              ? (isQuizQ ? (isCorrectKey ? '5px solid #0053DB' : '5px solid #E11D48') : '5px solid #0053DB')
                                              : '2px solid #CBD5E1',
                                            backgroundColor: isSelected ? '#FFFFFF' : 'transparent',
                                            flexShrink: 0,
                                          }}
                                        />
                                        <span>{opt.label}</span>
                                      </div>

                                      {/* Indicator */}
                                      {isSelected && isQuizQ && isCorrectKey && (
                                        <div style={{ width: '22px', height: '22px', borderRadius: '50%', backgroundColor: '#0053DB', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '12px' }}>✓</div>
                                      )}
                                      {isSelected && isQuizQ && !isCorrectKey && (
                                        <div style={{ width: '22px', height: '22px', borderRadius: '50%', backgroundColor: '#E11D48', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '12px' }}>✕</div>
                                      )}
                                      {isSelected && !isQuizQ && (
                                        <div style={{ width: '22px', height: '22px', borderRadius: '50%', backgroundColor: '#0053DB', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '12px' }}>✓</div>
                                      )}
                                      {!isSelected && isCorrectKey && isQuizQ && (
                                        <span style={{ fontSize: '12px', color: '#16A34A', fontWeight: 600 }}>Kunci Jawaban</span>
                                      )}
                                    </div>
                                  );
                                })}
                              </div>
                            ) : q.type === 'text' ? (
                              /* Text Answer */
                              <div className="resp-answer-value">
                                {ans?.answer_text || <span style={{ color: '#94a3b8', fontStyle: 'italic' }}>Tidak dijawab</span>}
                              </div>
                            ) : q.type === 'date' ? (
                              /* Date Answer */
                              <div className="resp-answer-value" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                                <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                                  <path strokeLinecap="round" strokeLinejoin="round" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                                </svg>
                                {ans?.answer_text
                                  ? new Date(ans.answer_text).toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' })
                                  : <span style={{ color: '#94a3b8', fontStyle: 'italic' }}>Tidak dijawab</span>}
                              </div>
                            ) : q.type === 'file_upload' ? (
                              /* File Upload Answer */
                              <div className="resp-answer-value">
                                {ans?.file_url ? (
                                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                                    <svg width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="#0053db" strokeWidth={1.5}>
                                      <path strokeLinecap="round" strokeLinejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                                    </svg>
                                    <div>
                                      <span style={{ fontWeight: 600, color: '#0f172a', fontSize: '14px' }}>
                                        {ans.answer_text || 'File terlampir'}
                                      </span>
                                      <br />
                                      <a href={ans.file_url} target="_blank" rel="noopener noreferrer" style={{ color: '#0053db', fontWeight: 500, fontSize: '13px', textDecoration: 'none' }}>
                                        Unduh / Lihat File ↗
                                      </a>
                                    </div>
                                  </div>
                                ) : (
                                  <span style={{ color: '#94a3b8', fontStyle: 'italic' }}>Tidak ada file diupload</span>
                                )}
                              </div>
                            ) : (
                              /* Fallback for any other type */
                              <div className="resp-answer-value">
                                {ans?.answer_text || ans?.file_url || <span style={{ color: '#94a3b8', fontStyle: 'italic' }}>Tidak dijawab</span>}
                              </div>
                            )}
                          </div>
                        );
                      })}
                  </div>
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

      {/* Confirm Delete Modal */}
      {confirmDeleteForm && (
        <div className="db-modal-overlay" onClick={() => setConfirmDeleteForm(null)}>
          <div className="db-modal-card" onClick={(e) => e.stopPropagation()}>
            <div className="db-modal-icon danger">
              <svg width="26" height="26" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <polyline points="3 6 5 6 21 6" />
                <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2" />
              </svg>
            </div>
            <h3 className="db-modal-title">Hapus Form</h3>
            <p className="db-modal-text">
              Yakin ingin menghapus form <strong>"{confirmDeleteForm.title}"</strong>? Semua respons yang masuk ikut terhapus dan tindakan ini tidak bisa dibatalkan.
            </p>
            <div className="db-modal-actions">
              <button className="db-btn-cancel" onClick={() => setConfirmDeleteForm(null)}>
                Batal
              </button>
              <button className="db-btn-danger" onClick={handleConfirmDelete}>
                Hapus
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
