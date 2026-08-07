import { useEffect, useState, useCallback } from 'react';
import { useNavigate, useParams, useSearchParams } from 'react-router-dom';
import ReactQuill from 'react-quill-new';
import 'react-quill-new/dist/quill.snow.css';
import { getMe, logout } from '../api/auth';
import { createForm, getForm, updateForm, generateQR } from '../api/forms';
import { getTemplate } from '../api/templates';
import { uploadFile } from '../api/uploads';
import { API_BASE_URL } from '../api/config';
import {
  createQuestionInForm,
  updateQuestion,
  deleteQuestion,
  createOption,
  updateOption,
  deleteOption,
} from '../api/questions';
import '../styles/form-builder.css';

const QUESTION_TYPES = [
  { value: 'text', label: 'Teks' },
  { value: 'single_choice', label: 'Pilihan Ganda' },
  { value: 'checkbox', label: 'Checkbox' },
  { value: 'dropdown', label: 'Dropdown' },
  { value: 'date', label: 'Tanggal' },
  { value: 'file_upload', label: 'Upload File' },
];

const QUILL_MODULES = {
  toolbar: [
    ['bold', 'italic', 'underline'],
    [{ list: 'ordered' }, { list: 'bullet' }],
    ['link'],
    ['clean'],
  ],
};

const QUILL_FORMATS = ['bold', 'italic', 'underline', 'list', 'link'];

function generateSlug(title) {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .substring(0, 60) + '-' + Date.now().toString(36);
}

export default function FormBuilderPage() {
  const navigate = useNavigate();
  const { formId } = useParams();
  const [searchParams] = useSearchParams();
  const templateId = searchParams.get('template');

  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [bannerUploading, setBannerUploading] = useState(false);
  const [activeTab, setActiveTab] = useState('soal');
  const [activeQuestion, setActiveQuestion] = useState(null);
  const [toast, setToast] = useState(null);
  const [showQrModal, setShowQrModal] = useState(false);
  const [copiedLink, setCopiedLink] = useState(false);


  // Form data
  const [formData, setFormData] = useState({
    id: null,
    title: '',
    description: '',
    status: 'draft',
    slug: '',
    accept_responses: true,
    banner_url: null,
    start_date: '',
    end_date: '',
    join_token: null,
    qr_code_url: null,
  });

  // Questions (local state)
  const [questions, setQuestions] = useState([]);

  // Settings flags
  const [useJoinToken, setUseJoinToken] = useState(false);

  const token = localStorage.getItem('token');

  const showToast = useCallback((msg, type = 'info') => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3000);
  }, []);

  // Load initial data
  useEffect(() => {
    if (!token) {
      navigate('/auth');
      return;
    }

    const load = async () => {
      try {
        const userData = await getMe(token);
        setUser(userData);

        if (formId) {
          // Edit mode: load existing form
          const form = await getForm(token, formId);
          setFormData({
            id: form.id,
            title: form.title,
            description: form.description || '',
            status: form.status,
            slug: form.slug,
            accept_responses: form.accept_responses,
            banner_url: form.banner_url || null,
            start_date: form.start_date ? form.start_date.substring(0, 16) : '',
            end_date: form.end_date ? form.end_date.substring(0, 16) : '',
            join_token: form.join_token,
            qr_code_url: form.qr_code_url,
          });
          setUseJoinToken(!!form.join_token);
          setQuestions(
            (form.questions || [])
              .sort((a, b) => a.order_index - b.order_index)
              .map((q) => ({
                ...q,
                _saved: true,
                options: (q.options || []).sort((a, b) => a.order_index - b.order_index).map((o) => ({ ...o, _saved: true })),
              }))
          );
        } else if (templateId) {
          // Create from template: load template questions as initial data
          try {
            const tpl = await getTemplate(token, templateId);
            setFormData((prev) => ({
              ...prev,
              title: tpl.title || '',
              description: tpl.description || '',
            }));
            setQuestions(
              (tpl.questions || [])
                .sort((a, b) => a.order_index - b.order_index)
                .map((q, idx) => ({
                  _tempId: `temp-${idx}`,
                  type: q.type,
                  label: q.label,
                  placeholder: q.placeholder || '',
                  is_required: q.is_required,
                  order_index: idx,
                  settings: q.settings || {},
                  options: (q.options || []).map((o, oidx) => ({
                    _tempId: `temp-opt-${idx}-${oidx}`,
                    label: o.label,
                    value: o.value || '',
                    order_index: oidx,
                  })),
                }))
            );
          } catch {
            showToast('Gagal memuat template', 'error');
          }
        }
      } catch {
        logout();
        navigate('/auth');
      } finally {
        setLoading(false);
      }
    };

    load();
  }, [formId, templateId, token, navigate, showToast]);

  // ============================================================
  // SAVE / CREATE FORM
  // ============================================================
  const handleSave = async () => {
    if (!formData.title.trim()) {
      showToast('Judul form tidak boleh kosong', 'error');
      return;
    }

    setSaving(true);
    try {
      if (formData.id) {
        // Update existing form
        await updateForm(token, formData.id, {
          title: formData.title,
          description: formData.description,
          status: formData.status,
          accept_responses: formData.accept_responses,
          banner_url: formData.banner_url,
          start_date: formData.start_date || null,
          end_date: formData.end_date || null,
        });

        // Save questions
        for (const q of questions) {
          if (q.id && q._saved) {
            // Update existing question
            await updateQuestion(token, q.id, {
              type: q.type,
              label: q.label,
              placeholder: q.placeholder,
              is_required: q.is_required,
              order_index: q.order_index,
              settings: q.settings,
            });
            // Handle options
            for (const opt of q.options) {
              if (opt.id && opt._saved) {
                await updateOption(token, opt.id, {
                  label: opt.label,
                  value: opt.value,
                  order_index: opt.order_index,
                });
              } else if (!opt.id) {
                const newOpt = await createOption(token, q.id, {
                  label: opt.label,
                  value: opt.value || '',
                  order_index: opt.order_index,
                });
                opt.id = newOpt.id;
                opt._saved = true;
              }
            }
          } else if (!q.id) {
            // Create new question
            const newQ = await createQuestionInForm(token, formData.id, {
              type: q.type,
              label: q.label,
              placeholder: q.placeholder || '',
              is_required: q.is_required,
              order_index: q.order_index,
              settings: q.settings || {},
              options: q.options.map((o) => ({
                label: o.label,
                value: o.value || '',
                order_index: o.order_index,
              })),
            });
            q.id = newQ.id;
            q._saved = true;
            q.options = (newQ.options || []).map((o) => ({ ...o, _saved: true }));
          }
        }

        showToast('Form berhasil disimpan!', 'success');
      } else {
        // Create new form
        const slug = formData.slug || generateSlug(formData.title);
        const payload = {
          title: formData.title,
          description: formData.description,
          status: formData.status,
          accept_responses: formData.accept_responses,
          slug,
          template_id: templateId || null,
          banner_url: formData.banner_url,
          start_date: formData.start_date || null,
          end_date: formData.end_date || null,
          use_join_token: useJoinToken,
          questions: templateId
            ? []
            : questions.map((q, idx) => ({
                type: q.type,
                label: q.label,
                placeholder: q.placeholder || '',
                is_required: q.is_required,
                order_index: idx,
                settings: q.settings || {},
                options: (q.options || []).map((o, oidx) => ({
                  label: o.label,
                  value: o.value || '',
                  order_index: oidx,
                })),
              })),
        };

        const created = await createForm(token, payload);
        setFormData((prev) => ({
          ...prev,
          id: created.id,
          slug: created.slug,
          join_token: created.join_token,
        }));
        setQuestions(
          (created.questions || [])
            .sort((a, b) => a.order_index - b.order_index)
            .map((q) => ({
              ...q,
              _saved: true,
              options: (q.options || []).map((o) => ({ ...o, _saved: true })),
            }))
        );

        // Update URL to edit mode without reloading
        window.history.replaceState(null, '', `/form-builder/${created.id}`);
        showToast('Form berhasil dibuat!', 'success');
      }
    } catch (err) {
      showToast(err.message || 'Gagal menyimpan form', 'error');
    } finally {
      setSaving(false);
    }
  };

  // ============================================================
  // QUESTION MANAGEMENT (local state)
  // ============================================================
  const addQuestion = () => {
    const newQ = {
      _tempId: `temp-${Date.now()}`,
      type: 'single_choice',
      label: '',
      placeholder: '',
      is_required: false,
      order_index: questions.length,
      settings: {},
      options: [
        { _tempId: `temp-opt-${Date.now()}-0`, label: 'Opsi 1', value: '', order_index: 0 },
      ],
    };
    setQuestions((prev) => [...prev, newQ]);
    setActiveQuestion(newQ._tempId || newQ.id);
  };

  const duplicateQuestion = (index) => {
    const original = questions[index];
    const copy = {
      ...original,
      id: undefined,
      _tempId: `temp-${Date.now()}`,
      _saved: false,
      order_index: questions.length,
      options: (original.options || []).map((o, oidx) => ({
        ...o,
        id: undefined,
        _tempId: `temp-opt-dup-${Date.now()}-${oidx}`,
        _saved: false,
      })),
    };
    setQuestions((prev) => [...prev.slice(0, index + 1), copy, ...prev.slice(index + 1)]);
  };

  const removeQuestion = async (index) => {
    const q = questions[index];
    if (q.id) {
      try {
        await deleteQuestion(token, q.id);
      } catch (err) {
        showToast(err.message, 'error');
        return;
      }
    }
    setQuestions((prev) => prev.filter((_, i) => i !== index));
  };

  const updateQuestionLocal = (index, updates) => {
    setQuestions((prev) => prev.map((q, i) => (i === index ? { ...q, ...updates, _saved: false } : q)));
  };

  // Option management
  const addOptionToQuestion = (qIndex) => {
    setQuestions((prev) =>
      prev.map((q, i) =>
        i === qIndex
          ? {
              ...q,
              _saved: false,
              options: [
                ...q.options,
                {
                  _tempId: `temp-opt-${Date.now()}`,
                  label: `Opsi ${q.options.length + 1}`,
                  value: '',
                  order_index: q.options.length,
                },
              ],
            }
          : q
      )
    );
  };

  const updateOptionLocal = (qIndex, oIndex, updates) => {
    setQuestions((prev) =>
      prev.map((q, i) =>
        i === qIndex
          ? {
              ...q,
              _saved: false,
              options: q.options.map((o, j) => (j === oIndex ? { ...o, ...updates, _saved: false } : o)),
            }
          : q
      )
    );
  };

  const removeOptionLocal = async (qIndex, oIndex) => {
    const opt = questions[qIndex].options[oIndex];
    if (opt.id) {
      try {
        await deleteOption(token, opt.id);
      } catch (err) {
        showToast(err.message, 'error');
        return;
      }
    }
    setQuestions((prev) =>
      prev.map((q, i) =>
        i === qIndex ? { ...q, _saved: false, options: q.options.filter((_, j) => j !== oIndex) } : q
      )
    );
  };

  const getPublicLink = () => {
    return `${API_BASE_URL}/f/${formData.slug}`;
  };

  const handleCopyLink = () => {
    const link = getPublicLink();
    navigator.clipboard.writeText(link);
    setCopiedLink(true);
    setTimeout(() => setCopiedLink(false), 2000);
  };

  const handleGenerateQR = async () => {
    if (!formData.id) {
      showToast('Simpan form terlebih dahulu', 'error');
      return;
    }
    try {
      const result = await generateQR(token, formData.id);
      setFormData((prev) => ({ ...prev, qr_code_url: result.qr_code_url }));
      setShowQrModal(true);
      showToast('QR Code berhasil dibuat!', 'success');
    } catch (err) {
      showToast(err.message, 'error');
    }
  };


  // ============================================================
  // BANNER
  // ============================================================
  const handleBannerUpload = async (e) => {
    const file = e.target.files && e.target.files[0];
    if (!file) return;
    setBannerUploading(true);
    try {
      const result = await uploadFile(token, file);
      setFormData((prev) => ({ ...prev, banner_url: result.file_url }));
      showToast('Banner berhasil diupload', 'success');
    } catch (err) {
      showToast(err.message, 'error');
    } finally {
      setBannerUploading(false);
      e.target.value = '';
    }
  };

  const handleRemoveBanner = () => {
    setFormData((prev) => ({ ...prev, banner_url: null }));
  };

  // ============================================================
  // HELPERS
  // ============================================================
  const getInitials = (name = '') =>
    name.split(' ').slice(0, 2).map((w) => w[0]).join('').toUpperCase();

  const hasOptions = (type) => ['single_choice', 'checkbox', 'dropdown'].includes(type);

  const getOptionIndicator = (type) => {
    if (type === 'single_choice') return 'fb-option-radio';
    if (type === 'checkbox') return 'fb-option-checkbox';
    return null;
  };

  if (loading) {
    return (
      <div className="fb-loading">
        <div className="db-spinner" />
        <p>Memuat form builder...</p>
      </div>
    );
  }

  return (
    <div className="db-root">
      {/* Sidebar (shared with dashboard) */}
      <aside className="db-sidebar">
        <div className="db-logo">
          <div className="db-logo-icon">
            <svg width="36" height="36" viewBox="0 0 36 36" fill="none">
              <rect width="36" height="36" rx="8" fill="url(#logo-grad-fb)" />
              <text x="7" y="25" fontFamily="Inter, sans-serif" fontWeight="800" fontSize="18" fill="#fff">F4</text>
              <defs>
                <linearGradient id="logo-grad-fb" x1="0" y1="0" x2="36" y2="36" gradientUnits="userSpaceOnUse">
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

        <nav className="db-nav">
          <button className="db-nav-item" onClick={() => navigate('/dashboard')}>
            <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <rect x="3" y="3" width="7" height="7" rx="1" /><rect x="14" y="3" width="7" height="7" rx="1" />
              <rect x="3" y="14" width="7" height="7" rx="1" /><rect x="14" y="14" width="7" height="7" rx="1" />
            </svg>
            <span>Dashboard</span>
          </button>
          <button className="db-nav-item" onClick={() => navigate('/dashboard')}>
            <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <rect x="3" y="3" width="18" height="18" rx="2" /><path d="M3 9h18M9 21V9" />
            </svg>
            <span>Template</span>
          </button>
          <button className="db-nav-item" onClick={() => navigate('/dashboard')}>
            <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <polyline points="1 4 1 10 7 10" /><path d="M3.51 15a9 9 0 1 0 .49-4.39" />
            </svg>
            <span>History</span>
          </button>
        </nav>

        <div className="db-sidebar-footer">
          <div className="db-user">
            <div className="db-avatar">
              {user?.avatar_url ? <img src={user.avatar_url} alt={user.full_name} /> : <span>{getInitials(user?.full_name)}</span>}
            </div>
            <div className="db-user-info">
              <span className="db-user-name">{user?.full_name}</span>
              <span className="db-user-email">{user?.email}</span>
            </div>
          </div>
          <button className="db-logout-btn" onClick={() => { logout(); navigate('/auth'); }} aria-label="Logout">
            <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4" /><polyline points="16 17 21 12 16 7" /><line x1="21" y1="12" x2="9" y2="12" />
            </svg>
          </button>
        </div>
      </aside>

      {/* Main */}
      <main className="fb-main">
        {/* Topbar */}
        <header className="fb-topbar">
          <div className="fb-topbar-left">
            <button className="fb-back-btn" onClick={() => navigate('/dashboard')} aria-label="Back to dashboard">
              <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <polyline points="15 18 9 12 15 6" />
              </svg>
            </button>
          </div>

          <div className="fb-topbar-center">
            <button className={`fb-tab ${activeTab === 'soal' ? 'active' : ''}`} onClick={() => setActiveTab('soal')}>
              Soal
            </button>
            <button className={`fb-tab ${activeTab === 'setelan' ? 'active' : ''}`} onClick={() => setActiveTab('setelan')}>
              Setelan
            </button>
          </div>

          <button className="fb-save-btn" onClick={handleSave} disabled={saving}>
            {saving ? 'Menyimpan...' : 'Simpan Draf'}
          </button>
        </header>

        {/* Content */}
        <section className="fb-content">
          {activeTab === 'soal' && (
            <>
              <div className="fb-editor-area">
                {/* Progress Bar */}
                <div className="fb-progress-bar">
                  <div
                    className="fb-progress-fill"
                    style={{
                      width: `${questions.length > 0 ? Math.min(100, (questions.filter((q) => q.label.trim()).length / questions.length) * 100) : 0}%`,
                    }}
                  />
                </div>

                {/* Form Header */}
                <div className="fb-header-card">
                  {/* Banner */}
                  {formData.banner_url ? (
                    <div className="fb-banner-wrap">
                      <img src={formData.banner_url} alt="Banner form" className="fb-banner-img" />
                      <div className="fb-banner-actions">
                        <label className="fb-banner-btn">
                          {bannerUploading ? 'Mengupload...' : 'Ganti Banner'}
                          <input type="file" accept="image/*" hidden onChange={handleBannerUpload} disabled={bannerUploading} />
                        </label>
                        <button className="fb-banner-btn danger" onClick={handleRemoveBanner} disabled={bannerUploading}>
                          Hapus Banner
                        </button>
                      </div>
                    </div>
                  ) : (
                    <div className="fb-banner-upload" onClick={() => document.getElementById('fb-banner-input')?.click()}>
                      {bannerUploading ? (
                        <span>Mengupload banner...</span>
                      ) : (
                        <>
                          <svg width="28" height="28" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                            <rect x="3" y="3" width="18" height="18" rx="2" />
                            <circle cx="8.5" cy="8.5" r="1.5" />
                            <polyline points="21 15 16 10 5 21" />
                          </svg>
                          <span>Tambahkan Banner</span>
                        </>
                      )}
                      <input
                        id="fb-banner-input"
                        type="file"
                        accept="image/*"
                        hidden
                        onChange={handleBannerUpload}
                        disabled={bannerUploading}
                      />
                    </div>
                  )}

                  <input
                    className="fb-title-input"
                    type="text"
                    placeholder="Judul Formulir"
                    value={formData.title}
                    onChange={(e) => setFormData((prev) => ({ ...prev, title: e.target.value }))}
                  />
                  <p className="fb-desc-label">Deskripsi</p>
                  <div className="fb-wysiwyg-wrap">
                    <ReactQuill
                      theme="snow"
                      value={formData.description}
                      onChange={(val) => setFormData((prev) => ({ ...prev, description: val }))}
                      modules={QUILL_MODULES}
                      formats={QUILL_FORMATS}
                      placeholder="Deskripsi formulir..."
                    />
                  </div>
                </div>

                {/* Questions */}
                {questions.map((q, qIdx) => {
                  const qKey = q.id || q._tempId;
                  const isActive = activeQuestion === qKey;

                  return (
                    <div
                      key={qKey}
                      className={`fb-question-card ${isActive ? 'active' : ''}`}
                      onClick={() => setActiveQuestion(qKey)}
                    >
                      {/* Top: label + type */}
                      <div className="fb-question-top">
                        <input
                          className="fb-question-label-input"
                          type="text"
                          placeholder="Tulis pertanyaan di sini..."
                          value={q.label}
                          onChange={(e) => updateQuestionLocal(qIdx, { label: e.target.value })}
                        />
                        <select
                          className="fb-type-select"
                          value={q.type}
                          onChange={(e) => {
                            const newType = e.target.value;
                            const updates = { type: newType };
                            // Add default option if switching to choice type and has no options
                            if (hasOptions(newType) && (!q.options || q.options.length === 0)) {
                              updates.options = [{ _tempId: `temp-opt-${Date.now()}`, label: 'Opsi 1', value: '', order_index: 0 }];
                            }
                            updateQuestionLocal(qIdx, updates);
                          }}
                        >
                          {QUESTION_TYPES.map((t) => (
                            <option key={t.value} value={t.value}>{t.label}</option>
                          ))}
                        </select>
                      </div>

                      {/* Options (for single_choice, checkbox, dropdown) */}
                      {hasOptions(q.type) && (
                        <div className="fb-options-list">
                          {(q.options || []).map((opt, oIdx) => (
                            <div key={opt.id || opt._tempId} className="fb-option-row">
                              {getOptionIndicator(q.type) && <div className={getOptionIndicator(q.type)} />}
                              {q.type === 'dropdown' && (
                                <span style={{ color: '#94a3b8', fontSize: '13px', minWidth: '20px' }}>{oIdx + 1}.</span>
                              )}
                              <input
                                className="fb-option-input"
                                type="text"
                                value={opt.label}
                                onChange={(e) => updateOptionLocal(qIdx, oIdx, { label: e.target.value })}
                                placeholder={`Opsi ${oIdx + 1}`}
                              />
                              {q.options.length > 1 && (
                                <button
                                  className="fb-option-delete"
                                  onClick={() => removeOptionLocal(qIdx, oIdx)}
                                  aria-label="Hapus opsi"
                                >
                                  <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                                    <line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" />
                                  </svg>
                                </button>
                              )}
                            </div>
                          ))}

                          <div className="fb-add-option-row">
                            {getOptionIndicator(q.type) && <div className={getOptionIndicator(q.type)} style={{ opacity: 0.4 }} />}
                            <button className="fb-add-option-btn" onClick={() => addOptionToQuestion(qIdx)}>
                              Tambah opsi
                            </button>
                            <span style={{ color: '#cbd5e1', fontSize: '13px' }}>atau</span>
                            <button
                              className="fb-add-other-btn"
                              onClick={() => {
                                setQuestions((prev) =>
                                  prev.map((qq, i) =>
                                    i === qIdx
                                      ? {
                                          ...qq,
                                          _saved: false,
                                          options: [
                                            ...qq.options,
                                            {
                                              _tempId: `temp-opt-other-${Date.now()}`,
                                              label: 'Lainnya',
                                              value: '__other__',
                                              order_index: qq.options.length,
                                            },
                                          ],
                                        }
                                      : qq
                                  )
                                );
                              }}
                            >
                              tambahkan &quot;Lainnya&quot;
                            </button>
                          </div>
                        </div>
                      )}

                      {/* Text placeholder for text type */}
                      {q.type === 'text' && (
                        <div style={{ marginTop: '8px' }}>
                          <input
                            style={{
                              width: '100%',
                              border: 'none',
                              borderBottom: '1px dashed #e2e8f0',
                              padding: '8px 0',
                              fontFamily: "'Inter', sans-serif",
                              fontSize: '14px',
                              color: '#cbd5e1',
                              outline: 'none',
                              background: 'transparent',
                            }}
                            type="text"
                            placeholder="Jawaban teks panjang..."
                            disabled
                          />
                        </div>
                      )}

                      {/* Date placeholder */}
                      {q.type === 'date' && (
                        <div style={{ marginTop: '8px' }}>
                          <input
                            style={{
                              width: '200px',
                              border: '1px solid #e2e8f0',
                              borderRadius: '8px',
                              padding: '8px 12px',
                              fontFamily: "'Inter', sans-serif",
                              fontSize: '14px',
                              color: '#cbd5e1',
                              outline: 'none',
                              background: '#fafbfc',
                            }}
                            type="date"
                            disabled
                          />
                        </div>
                      )}

                      {/* File upload placeholder */}
                      {q.type === 'file_upload' && (
                        <div
                          style={{
                            marginTop: '8px',
                            border: '2px dashed #e2e8f0',
                            borderRadius: '8px',
                            padding: '20px',
                            textAlign: 'center',
                            color: '#94a3b8',
                            fontSize: '13px',
                          }}
                        >
                          📎 Area upload file
                        </div>
                      )}

                      {/* Required note */}
                      {q.is_required && <p className="fb-required-note">* Wajib diisi</p>}

                      {/* Footer actions */}
                      <div className="fb-question-footer">
                        {/* Duplicate */}
                        <button className="fb-q-action-btn" onClick={() => duplicateQuestion(qIdx)} title="Duplikat">
                          <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                            <rect x="9" y="9" width="13" height="13" rx="2" />
                            <path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1" />
                          </svg>
                        </button>
                        {/* Delete */}
                        <button className="fb-q-action-btn danger" onClick={() => removeQuestion(qIdx)} title="Hapus">
                          <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                            <polyline points="3 6 5 6 21 6" />
                            <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2" />
                          </svg>
                        </button>
                        {/* Required toggle */}
                        <div className="fb-required-wrap">
                          <span className="fb-required-label">Wajib diisi</span>
                          <button
                            className={`fb-toggle ${q.is_required ? 'on' : 'off'}`}
                            onClick={() => updateQuestionLocal(qIdx, { is_required: !q.is_required })}
                            aria-label="Toggle required"
                          />
                        </div>
                      </div>
                    </div>
                  );
                })}

                {/* Add Question Button */}
                <button className="fb-add-question-btn" onClick={addQuestion}>
                  <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <circle cx="12" cy="12" r="10" />
                    <line x1="12" y1="8" x2="12" y2="16" />
                    <line x1="8" y1="12" x2="16" y2="12" />
                  </svg>
                  Tambah Pertanyaan
                </button>
              </div>

              {/* Floating actions */}
              <div className="fb-float-actions">
                <button className="fb-float-btn" onClick={addQuestion} title="Tambah pertanyaan teks">
                  <svg width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path d="M4 7V4h16v3" /><path d="M9 20h6" /><path d="M12 4v16" />
                  </svg>
                </button>
                <button className="fb-float-btn" title="Tambah gambar" onClick={() => showToast('Fitur gambar coming soon')}>
                  <svg width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <rect x="3" y="3" width="18" height="18" rx="2" />
                    <circle cx="8.5" cy="8.5" r="1.5" />
                    <polyline points="21 15 16 10 5 21" />
                  </svg>
                </button>
                <button className="fb-float-btn" title="Tambah video" onClick={() => showToast('Fitur video coming soon')}>
                  <svg width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <polygon points="23 7 16 12 23 17 23 7" />
                    <rect x="1" y="5" width="15" height="14" rx="2" />
                  </svg>
                </button>
                <button className="fb-float-btn" title="Tambah section" onClick={() => showToast('Fitur section coming soon')}>
                  <svg width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" />
                    <polyline points="14 2 14 8 20 8" />
                  </svg>
                </button>
              </div>
            </>
          )}

          {/* ===== SETTINGS TAB ===== */}
          {activeTab === 'setelan' && (
            <div className="fb-editor-area">
              <div className="fb-settings-card">
                <h2 className="fb-settings-title">Setelan Formulir</h2>

                {/* Slug */}
                <div className="fb-setting-group">
                  <label className="fb-setting-label">Slug URL</label>
                  <input
                    className="fb-setting-input"
                    type="text"
                    placeholder="slug-form-anda"
                    value={formData.slug}
                    onChange={(e) => setFormData((prev) => ({ ...prev, slug: e.target.value }))}
                    disabled={!!formData.id}
                  />
                  <p className="fb-slug-preview">
                    Link: {API_BASE_URL}/f/{formData.slug || 'slug-form-anda'}
                  </p>
                </div>

                {/* Status */}
                <div className="fb-setting-row">
                  <div>
                    <p className="fb-setting-row-label">Status</p>
                    <p className="fb-setting-row-desc">Status publikasi form</p>
                  </div>
                  <select
                    className="fb-status-select"
                    value={formData.status}
                    onChange={(e) => setFormData((prev) => ({ ...prev, status: e.target.value }))}
                  >
                    <option value="draft">Draft</option>
                    <option value="published">Published</option>
                    <option value="closed">Closed</option>
                  </select>
                </div>

                {/* Accept Responses */}
                <div className="fb-setting-row">
                  <div>
                    <p className="fb-setting-row-label">Terima Respons</p>
                    <p className="fb-setting-row-desc">Apakah form menerima jawaban baru</p>
                  </div>
                  <button
                    className={`fb-toggle ${formData.accept_responses ? 'on' : 'off'}`}
                    onClick={() => setFormData((prev) => ({ ...prev, accept_responses: !prev.accept_responses }))}
                  />
                </div>

                {/* Join Token */}
                <div className="fb-setting-row">
                  <div>
                    <p className="fb-setting-row-label">Token Ujian</p>
                    <p className="fb-setting-row-desc">Peserta harus memasukkan token untuk mengisi form</p>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    {formData.join_token && (
                      <code style={{ fontSize: '12px', background: '#f1f5f9', padding: '4px 8px', borderRadius: '6px', color: '#2563eb', fontWeight: 600 }}>
                        {formData.join_token}
                      </code>
                    )}
                    <button
                      className={`fb-toggle ${useJoinToken ? 'on' : 'off'}`}
                      onClick={() => setUseJoinToken(!useJoinToken)}
                      disabled={!!formData.id}
                    />
                  </div>
                </div>

                {/* Date Range */}
                <div className="fb-setting-group" style={{ marginTop: '22px' }}>
                  <label className="fb-setting-label">Jadwal Buka/Tutup</label>
                  <div className="fb-date-inputs">
                    <div>
                      <label className="fb-setting-label" style={{ fontSize: '11px', color: '#94a3b8' }}>Mulai</label>
                      <input
                        className="fb-setting-input"
                        type="datetime-local"
                        value={formData.start_date}
                        onChange={(e) => setFormData((prev) => ({ ...prev, start_date: e.target.value }))}
                      />
                    </div>
                    <div>
                      <label className="fb-setting-label" style={{ fontSize: '11px', color: '#94a3b8' }}>Selesai</label>
                      <input
                        className="fb-setting-input"
                        type="datetime-local"
                        value={formData.end_date}
                        onChange={(e) => setFormData((prev) => ({ ...prev, end_date: e.target.value }))}
                      />
                    </div>
                  </div>
                </div>

                {/* QR Code */}
                <div className="fb-setting-row" style={{ borderBottom: 'none', marginTop: '8px' }}>
                  <div>
                    <p className="fb-setting-row-label">QR Code</p>
                    <p className="fb-setting-row-desc">Generate QR code untuk dibagikan</p>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    {formData.qr_code_url && (
                      <button
                        type="button"
                        className="fb-qr-btn"
                        style={{ background: '#f1f5f9', color: '#334155', border: '1px solid #cbd5e1' }}
                        onClick={() => setShowQrModal(true)}
                      >
                        Lihat QR
                      </button>
                    )}
                    <button className="fb-qr-btn" onClick={handleGenerateQR} disabled={!formData.id}>
                      {formData.qr_code_url ? 'Regenerate QR' : 'Generate QR'}
                    </button>
                  </div>
                </div>
              </div>
            </div>
          )}
        </section>
      </main>

      {/* QR Code Modal Pop-up */}
      {showQrModal && formData.qr_code_url && (
        <div className="fb-modal-overlay" onClick={() => setShowQrModal(false)}>
          <div className="fb-modal-card" onClick={(e) => e.stopPropagation()}>
            <button className="fb-modal-close" onClick={() => setShowQrModal(false)} aria-label="Tutup">
              <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <line x1="18" y1="6" x2="6" y2="18" />
                <line x1="6" y1="6" x2="18" y2="18" />
              </svg>
            </button>

            <h3 className="fb-modal-title">QR Code Formulir</h3>
            <p className="fb-modal-subtitle">Pindai kode QR untuk membuka formulir ini di perangkat seluler</p>

            <div className="fb-qr-img-wrapper">
              <img src={formData.qr_code_url} alt="QR Code Form" />
            </div>

            <div className="fb-share-link-box">
              <span className="fb-share-link-text">{getPublicLink()}</span>
              <button className={`fb-copy-btn ${copiedLink ? 'copied' : ''}`} onClick={handleCopyLink}>
                {copiedLink ? 'Tersalin!' : 'Salin Link'}
              </button>
            </div>

            <div className="fb-modal-actions">
              <a
                href={formData.qr_code_url}
                download={`qrcode-${formData.slug}.png`}
                target="_blank"
                rel="noopener noreferrer"
                className="fb-modal-btn secondary"
                style={{ textDecoration: 'none' }}
              >
                <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4" />
                  <polyline points="7 10 12 15 17 10" />
                  <line x1="12" y1="15" x2="12" y2="3" />
                </svg>
                Unduh QR
              </a>
              <a
                href={getPublicLink()}
                target="_blank"
                rel="noopener noreferrer"
                className="fb-modal-btn primary"
                style={{ textDecoration: 'none' }}
              >
                <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6" />
                  <polyline points="15 3 21 3 21 9" />
                  <line x1="10" y1="14" x2="21" y2="3" />
                </svg>
                Buka Form
              </a>
            </div>
          </div>
        </div>
      )}

      {/* Toast */}
      {toast && (
        <div className={`fb-toast ${toast.type === 'error' ? 'error' : toast.type === 'success' ? 'success' : ''}`}>
          {toast.msg}
        </div>
      )}
    </div>
  );
}

