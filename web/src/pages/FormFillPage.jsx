import { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { getPublicFormBySlug, joinForm, saveAnswer, submitFinal } from '../api/submissions';
import { uploadFile } from '../api/uploads';
import { getMe } from '../api/auth';
import '../styles/form-fill.css';

const QUESTIONS_PER_PAGE = 4;

export default function FormFillPage() {
  const { slug } = useParams();
  const navigate = useNavigate();
  const token = localStorage.getItem('token');

  // Form & Submission states
  const [form, setForm] = useState(null);
  const [submissionId, setSubmissionId] = useState(null);
  const [answers, setAnswers] = useState({}); // { [question_id]: { answer_text, answer_options, file_url } }
  const [loading, setLoading] = useState(true);
  const [errorMsg, setErrorMsg] = useState('');

  // Pagination & Navigation
  const [currentPage, setCurrentPage] = useState(0);

  // Join Token modal
  const [showJoinModal, setShowJoinModal] = useState(false);
  const [joinTokenInput, setJoinTokenInput] = useState('');
  const [joinError, setJoinError] = useState('');

  // Submit states
  const [showSubmitModal, setShowSubmitModal] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isSubmitted, setIsSubmitted] = useState(false);

  // User Profile & Hover Popover
  const [userProfile, setUserProfile] = useState(null);
  const [showProfilePopover, setShowProfilePopover] = useState(false);
  const hoverTimeoutRef = useRef(null);

  // Countdown timer
  const [timeLeft, setTimeLeft] = useState(null);

  // File uploading state
  const [uploadingFiles, setUploadingFiles] = useState({});
  // Guard agar joinForm tidak dipanggil ganda (double effect / double click)
  const joiningRef = useRef(false);

  // 1. Initial Load & Auth Check
  useEffect(() => {
    if (!token) {
      navigate(`/auth?redirect=/f/${slug}`);
      return;
    }

    const loadForm = async () => {
      try {
        setLoading(true);
        setErrorMsg('');
        const formData = await getPublicFormBySlug(token, slug);
        setForm(formData);

        // Try auto joining form (if no join token required or user already joined)
        try {
          if (joiningRef.current) return;
          joiningRef.current = true;
          const sub = await joinForm(token, slug);
          setSubmissionId(sub.id);
          if (sub.submitted_at) {
            setIsSubmitted(true);
          }
          // Load existing answers if any
          if (sub.answers && Array.isArray(sub.answers)) {
            const initialAnswers = {};
            sub.answers.forEach((ans) => {
              initialAnswers[ans.question_id] = {
                answer_text: ans.answer_text || '',
                answer_options: ans.answer_options || [],
                file_url: ans.file_url || null,
              };
            });
            setAnswers(initialAnswers);
          }
        } catch (err) {
          // If error mentions token required, show join token modal
          if (formData.join_token || (err.message && err.message.toLowerCase().includes('token'))) {
            setShowJoinModal(true);
          } else {
            setErrorMsg(err.message || 'Gagal memulai form');
          }
        } finally {
          joiningRef.current = false;
        }
      } catch (err) {
        setErrorMsg(err.message || 'Form tidak ditemukan atau belum dipublikasikan');
      } finally {
        setLoading(false);
      }
    };

    loadForm();
  }, [slug, token, navigate]);

  // Handle manual join with token
  const handleJoinWithToken = async (e) => {
    e.preventDefault();
    setJoinError('');
    try {
      const sub = await joinForm(token, slug, joinTokenInput);
      setSubmissionId(sub.id);
      setShowJoinModal(false);
      if (sub.submitted_at) {
        setIsSubmitted(true);
      }
      if (sub.answers && Array.isArray(sub.answers)) {
        const initialAnswers = {};
        sub.answers.forEach((ans) => {
          initialAnswers[ans.question_id] = {
            answer_text: ans.answer_text || '',
            answer_options: ans.answer_options || [],
            file_url: ans.file_url || null,
          };
        });
        setAnswers(initialAnswers);
      }
    } catch (err) {
      setJoinError(err.message || 'Token tidak valid');
    }
  };

  // Handle Final Submit
  const handleFinalSubmit = async () => {
    if (!submissionId) return;
    try {
      setIsSubmitting(true);
      await submitFinal(token, submissionId);
      setIsSubmitted(true);
      setShowSubmitModal(false);
    } catch (err) {
      alert(err.message || 'Gagal mengirimkan form');
    } finally {
      setIsSubmitting(false);
    }
  };

  // Timer countdown hook
  useEffect(() => {
    if (!form || !form.end_date || isSubmitted) return;

    const parseDateMs = (dateStr) => {
      if (!dateStr) return null;
      let d = new Date(dateStr);
      if (isNaN(d.getTime())) {
        d = new Date(dateStr.replace(' ', 'T'));
      }
      return isNaN(d.getTime()) ? null : d.getTime();
    };

    const targetMs = parseDateMs(form.end_date);
    if (!targetMs) return;

    const updateTimer = () => {
      const now = new Date().getTime();
      const diff = Math.floor((targetMs - now) / 1000);
      if (diff <= 0) {
        setTimeLeft(0);
        // Auto submit when time expires
        if (submissionId && !isSubmitted && !isSubmitting) {
          handleFinalSubmit();
        }
      } else {
        setTimeLeft(diff);
      }
    };

    updateTimer();
    const interval = setInterval(updateTimer, 1000);
    return () => clearInterval(interval);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [form, submissionId, isSubmitted, isSubmitting]);

  // Format timer
  const formatTimer = (seconds) => {
    if (seconds === null || seconds < 0) return '00:00';
    const hrs = Math.floor(seconds / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    if (hrs > 0) {
      return `${hrs.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  // Handle profile hover - requirement: "di kanan atas logo profile jika dihover hanya memuat API get me saja"
  const handleProfileMouseEnter = () => {
    if (hoverTimeoutRef.current) clearTimeout(hoverTimeoutRef.current);
    setShowProfilePopover(true);
    if (!userProfile) {
      getMe(token)
        .then((data) => setUserProfile(data))
        .catch(() => {});
    }
  };

  const handleProfileMouseLeave = () => {
    hoverTimeoutRef.current = setTimeout(() => {
      setShowProfilePopover(false);
    }, 200);
  };

  // Helper to check if a question is answered
  const isQuestionAnswered = (qId) => {
    const ans = answers[qId];
    if (!ans) return false;
    if (ans.answer_text && ans.answer_text.trim().length > 0) return true;
    if (Array.isArray(ans.answer_options) && ans.answer_options.length > 0) return true;
    if (ans.file_url) return true;
    return false;
  };

  // Answer handler & Autosave
  const handleAnswerChange = (questionId, newAnswerData) => {
    const updated = {
      ...answers,
      [questionId]: {
        ...(answers[questionId] || {}),
        ...newAnswerData,
      },
    };
    setAnswers(updated);

    // Trigger autosave to backend if submission exists
    if (submissionId) {
      saveAnswer(token, submissionId, {
        question_id: questionId,
        answer_text: updated[questionId].answer_text || null,
        answer_options: updated[questionId].answer_options || null,
        file_url: updated[questionId].file_url || null,
      }).catch((err) => console.error('Autosave error:', err));
    }
  };

  // Handle file upload for file_upload question type
  const handleFileUpload = async (questionId, file) => {
    if (!file) return;
    setUploadingFiles((prev) => ({ ...prev, [questionId]: true }));
    try {
      const result = await uploadFile(token, file);
      handleAnswerChange(questionId, {
        file_url: result.file_url,
        answer_text: file.name,
      });
    } catch (err) {
      console.error('File upload error:', err);
      alert('Gagal mengupload file: ' + (err.message || 'Terjadi kesalahan'));
    } finally {
      setUploadingFiles((prev) => ({ ...prev, [questionId]: false }));
    }
  };



  // Question type label helper
  const getTypeLabel = (type) => {
    const map = {
      text: 'Teks',
      single_choice: 'Pilihan Ganda',
      checkbox: 'Checkbox',
      dropdown: 'Dropdown',
      date: 'Tanggal',
      file_upload: 'Upload File',
    };
    return map[type] || type;
  };

  // Render question input based on type
  const renderQuestionInput = (q, currentAnswer) => {
    switch (q.type) {
      case 'single_choice':
        return (
          <div className="options-list">
            {(q.options || []).map((opt) => {
              const isSelected =
                currentAnswer.answer_text === opt.label ||
                (Array.isArray(currentAnswer.answer_options) && currentAnswer.answer_options.includes(opt.label));
              return (
                <div
                  key={opt.id}
                  className={`option-item ${isSelected ? 'selected' : ''}`}
                  onClick={() =>
                    handleAnswerChange(q.id, {
                      answer_text: opt.label,
                      answer_options: [opt.label],
                    })
                  }
                >
                  <div className="option-radio">{isSelected && <div className="option-radio-dot" />}</div>
                  <span className="option-label-text">{opt.label}</span>
                  {isSelected && (
                    <svg className="option-check-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M5 13l4 4L19 7" />
                    </svg>
                  )}
                </div>
              );
            })}
          </div>
        );

      case 'checkbox':
        return (
          <div className="options-list">
            {(q.options || []).map((opt) => {
              const currentSelected = Array.isArray(currentAnswer.answer_options) ? currentAnswer.answer_options : [];
              const isSelected = currentSelected.includes(opt.label);
              return (
                <div
                  key={opt.id}
                  className={`option-item ${isSelected ? 'selected' : ''}`}
                  onClick={() => {
                    let nextSelected;
                    if (isSelected) {
                      nextSelected = currentSelected.filter((item) => item !== opt.label);
                    } else {
                      nextSelected = [...currentSelected, opt.label];
                    }
                    handleAnswerChange(q.id, {
                      answer_text: nextSelected.join(', '),
                      answer_options: nextSelected,
                    });
                  }}
                >
                  <div className="option-checkbox-box">
                    {isSelected && (
                      <svg width="12" height="12" fill="none" stroke="white" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M5 13l4 4L19 7" />
                      </svg>
                    )}
                  </div>
                  <span className="option-label-text">{opt.label}</span>
                </div>
              );
            })}
          </div>
        );

      case 'dropdown':
        return (
          <div className="dropdown-wrapper">
            <select
              className="question-dropdown"
              value={currentAnswer.answer_text || ''}
              onChange={(e) => {
                const val = e.target.value;
                handleAnswerChange(q.id, {
                  answer_text: val,
                  answer_options: val ? [val] : [],
                });
              }}
            >
              <option value="">— Pilih jawaban —</option>
              {(q.options || []).map((opt) => (
                <option key={opt.id} value={opt.label}>
                  {opt.label}
                </option>
              ))}
            </select>
            <svg className="dropdown-chevron" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
            </svg>
          </div>
        );

      case 'date':
        return (
          <input
            type="date"
            className="question-input question-date-input"
            value={currentAnswer.answer_text || ''}
            onChange={(e) => handleAnswerChange(q.id, { answer_text: e.target.value })}
          />
        );

      case 'file_upload':
        return (
          <div className="file-upload-area">
            {currentAnswer.file_url ? (
              <div className="file-uploaded-preview">
                <div className="file-icon-wrap">
                  <svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                </div>
                <div className="file-uploaded-info">
                  <span className="file-uploaded-name">{currentAnswer.answer_text || 'File uploaded'}</span>
                  <a href={currentAnswer.file_url} target="_blank" rel="noopener noreferrer" className="file-uploaded-link">
                    Lihat file ↗
                  </a>
                </div>
                <button
                  className="file-remove-btn"
                  onClick={() => handleAnswerChange(q.id, { file_url: null, answer_text: '' })}
                  title="Hapus file"
                >
                  <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
            ) : (
              <label className="file-drop-zone">
                <input
                  type="file"
                  className="file-hidden-input"
                  onChange={(e) => {
                    if (e.target.files && e.target.files[0]) {
                      handleFileUpload(q.id, e.target.files[0]);
                    }
                  }}
                  disabled={uploadingFiles[q.id]}
                />
                {uploadingFiles[q.id] ? (
                  <div className="file-uploading-state">
                    <div className="file-spinner" />
                    <span>Mengupload file...</span>
                  </div>
                ) : (
                  <>
                    <svg width="32" height="32" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                    </svg>
                    <span className="file-drop-text">Klik untuk upload atau drag & drop file</span>
                    <span className="file-drop-hint">Maksimal 10MB</span>
                  </>
                )}
              </label>
            )}
          </div>
        );

      case 'text':
      default:
        return (
          <input
            type="text"
            className="question-input"
            placeholder={q.placeholder || 'Ketik jawaban Anda di sini...'}
            value={currentAnswer.answer_text || ''}
            onChange={(e) => handleAnswerChange(q.id, { answer_text: e.target.value })}
          />
        );
    }
  };

  // Render Loading & Error States
  if (loading) {
    return (
      <div className="form-fill-container" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div className="ff-loading-wrap">
          <div className="ff-spinner" />
          <p>Memuat form...</p>
        </div>
      </div>
    );
  }

  if (errorMsg) {
    return (
      <div className="form-fill-container" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div className="modal-card">
          <h2 className="modal-title" style={{ color: '#EF4444' }}>Terjadi Kesalahan</h2>
          <p className="modal-desc">{errorMsg}</p>
          <button className="modal-btn-primary" onClick={() => navigate('/dashboard')}>
            Kembali ke Dashboard
          </button>
        </div>
      </div>
    );
  }

  // Join Token Modal View
  if (showJoinModal) {
    return (
      <div className="modal-overlay">
        <div className="modal-card">
          <h2 className="modal-title">Masukkan Token Form</h2>
          <p className="modal-desc">
            Form ini membutuhkan token khusus dari pembuat form sebelum Anda dapat mengisi pertanyaan.
          </p>
          <form onSubmit={handleJoinWithToken}>
            <input
              type="text"
              className="modal-input"
              placeholder="Contoh: X8K9L2"
              value={joinTokenInput}
              onChange={(e) => setJoinTokenInput(e.target.value)}
              required
            />
            {joinError && <p style={{ color: '#EF4444', fontSize: '13px', marginBottom: '16px' }}>{joinError}</p>}
            <div className="modal-actions">
              <button type="button" className="modal-btn-secondary" onClick={() => navigate('/dashboard')}>
                Batal
              </button>
              <button type="submit" className="modal-btn-primary">
                Mulai Isi Form
              </button>
            </div>
          </form>
        </div>
      </div>
    );
  }

  // Submitted Success View
  if (isSubmitted) {
    return (
      <div className="form-fill-container">
        <header className="form-fill-header">
          <h1 className="form-fill-logo">Form4x</h1>
          <div className="form-fill-header-right">
            <div
              className="profile-menu-wrapper"
              onMouseEnter={handleProfileMouseEnter}
              onMouseLeave={handleProfileMouseLeave}
            >
              <button className="profile-avatar-btn" aria-label="Profile">
                <svg width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                </svg>
              </button>
              {showProfilePopover && (
                <div className="profile-popover">
                  <div className="profile-popover-header">
                    <div className="profile-popover-avatar">
                      {userProfile?.full_name ? userProfile.full_name.charAt(0).toUpperCase() : 'U'}
                    </div>
                    <div className="profile-popover-info">
                      <p className="profile-popover-name">{userProfile?.full_name || 'Loading...'}</p>
                      <p className="profile-popover-email">{userProfile?.email || ''}</p>
                    </div>
                  </div>
                  <div className="profile-popover-footer">
                    <span className="profile-popover-status">
                      <span className="status-dot" /> Terhubung
                    </span>
                  </div>
                </div>
              )}
            </div>
          </div>
        </header>
        <div className="success-card">
          <div className="success-icon-wrap">
            <svg width="36" height="36" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M5 13l4 4L19 7" />
            </svg>
          </div>
          <h2 style={{ fontSize: '24px', fontWeight: '800', color: '#0F172A', marginBottom: '12px' }}>
            Jawaban Berhasil Terkirim!
          </h2>
          <p style={{ color: '#64748B', fontSize: '15px', lineHeight: '1.6', marginBottom: '28px' }}>
            Terima kasih telah mengisi <strong>{form?.title}</strong>. Jawaban Anda telah tersimpan dengan aman di sistem.
          </p>
          <button className="modal-btn-primary" onClick={() => navigate('/dashboard')}>
            Kembali ke Dashboard
          </button>
        </div>
      </div>
    );
  }

  const questions = (form?.questions || []).sort((a, b) => a.order_index - b.order_index);
  const totalQuestions = questions.length;
  const totalPages = Math.max(1, Math.ceil(totalQuestions / QUESTIONS_PER_PAGE));
  const currentQuestions = questions.slice(currentPage * QUESTIONS_PER_PAGE, (currentPage + 1) * QUESTIONS_PER_PAGE);
  const answeredCount = questions.filter((q) => isQuestionAnswered(q.id)).length;

  return (
    <div className="form-fill-container">
      {/* Header Bar */}
      <header className="form-fill-header">
        <h1 className="form-fill-logo">Form4x</h1>
        <div className="form-fill-header-right">
          {timeLeft !== null && (
            <div className={`form-fill-timer ${timeLeft <= 60 ? 'urgent' : ''}`}>
              <svg className="form-fill-timer-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <span>{formatTimer(timeLeft)}</span>
            </div>
          )}

          {/* Profile Logo - Hover fetches GET /auth/me */}
          <div
            className="profile-menu-wrapper"
            onMouseEnter={handleProfileMouseEnter}
            onMouseLeave={handleProfileMouseLeave}
          >
            <button className="profile-avatar-btn" aria-label="Profile User">
              <svg width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
              </svg>
            </button>
            {showProfilePopover && (
              <div className="profile-popover">
                <div className="profile-popover-header">
                  <div className="profile-popover-avatar">
                    {userProfile?.full_name ? userProfile.full_name.charAt(0).toUpperCase() : 'U'}
                  </div>
                  <div className="profile-popover-info">
                    <p className="profile-popover-name">{userProfile?.full_name || 'Loading...'}</p>
                    <p className="profile-popover-email">{userProfile?.email || ''}</p>
                  </div>
                </div>
                <div className="profile-popover-footer">
                  <span className="profile-popover-status">
                    <span className="status-dot" /> Active Session
                  </span>
                </div>
              </div>
            )}
          </div>
        </div>
      </header>

      {/* Main Grid Content */}
      <main className="form-fill-main">
        {/* Left Column: Question Navigator */}
        <aside className="question-navigator">
          <h2 className="navigator-title">Question Navigator</h2>
          <p className="navigator-subtitle">{totalQuestions} Questions Total</p>
          <div className="navigator-grid">
            {questions.map((q, idx) => {
              const isAns = isQuestionAnswered(q.id);
              const qPage = Math.floor(idx / QUESTIONS_PER_PAGE);
              const isCurrentPage = qPage === currentPage;
              return (
                <div
                  key={q.id}
                  className={`navigator-box ${isAns ? 'answered' : 'unanswered'} ${isCurrentPage ? 'current-page' : ''}`}
                  onClick={() => {
                    setCurrentPage(qPage);
                    window.scrollTo({ top: 0, behavior: 'smooth' });
                  }}
                  title={`Soal #${idx + 1} (${isAns ? 'Sudah Diisi' : 'Belum Diisi'})`}
                >
                  {idx + 1}
                </div>
              );
            })}
          </div>
        </aside>

        {/* Right Column: Questions Form Content */}
        <section className="form-content-area">
          {form?.banner_url && (
            <div className="form-fill-banner">
              <img src={form.banner_url} alt="Banner form" className="form-fill-banner-img" />
            </div>
          )}
          <div className="form-header-details">
            <h2 className="form-title">{form?.title}</h2>
            {form?.description && (
              <div
                className="form-description"
                dangerouslySetInnerHTML={{ __html: form.description }}
              />
            )}
          </div>

          {/* Warning Banner */}
          {form?.end_date && (
            <div className="form-notice-banner">
              <svg className="notice-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
              <span>Form akan otomatis terkirim saat waktu habis</span>
            </div>
          )}

          {/* Paginated Questions */}
          {currentQuestions.map((q, localIdx) => {
            const globalNumber = currentPage * QUESTIONS_PER_PAGE + localIdx + 1;
            const currentAnswer = answers[q.id] || {};
            const points = q.settings?.points || null;
            const contextText = q.settings?.context || q.settings?.reading_text || null;

            return (
              <div key={q.id} className="question-card" id={`q-${q.id}`}>
                <div className="question-card-header">
                  <div className="question-label">
                    <span className="question-number">{globalNumber}.</span>
                    <div className="question-label-content" dangerouslySetInnerHTML={{ __html: q.label }} />
                    {q.is_required && <span className="required-star">*</span>}
                  </div>
                  <div className="question-header-right">
                    <span className="question-type-tag">{getTypeLabel(q.type)}</span>
                    {points !== null && <span className="points-badge">{points} poin</span>}
                  </div>
                </div>

                {/* Context Box if available (e.g. reading passage box from design mock) */}
                {contextText && <div className="question-context-box">{contextText}</div>}

                {/* Render question input based on type */}
                {renderQuestionInput(q, currentAnswer)}
              </div>
            );
          })}

          {/* Bottom Bar Controls */}
          <div className="form-bottom-bar">
            <div className="progress-pill">
              {answeredCount}/{totalQuestions}
            </div>

            <div className="pagination-controls">
              <button
                className="btn-nav-prev"
                onClick={() => {
                  setCurrentPage((prev) => Math.max(0, prev - 1));
                  window.scrollTo({ top: 0, behavior: 'smooth' });
                }}
                disabled={currentPage === 0}
              >
                Kembali
              </button>
              <button
                className="btn-nav-next"
                onClick={() => {
                  setCurrentPage((prev) => Math.min(totalPages - 1, prev + 1));
                  window.scrollTo({ top: 0, behavior: 'smooth' });
                }}
                disabled={currentPage >= totalPages - 1}
              >
                Berikutnya
              </button>
            </div>

            <button className="btn-submit-final" onClick={() => setShowSubmitModal(true)}>
              <span>Kirim Jawaban</span>
              <span>»</span>
            </button>
          </div>
        </section>
      </main>

      {/* Confirmation Submit Modal */}
      {showSubmitModal && (
        <div className="modal-overlay">
          <div className="modal-card">
            <h2 className="modal-title">Kirim Jawaban Form?</h2>
            <p className="modal-desc">
              Anda telah menjawab {answeredCount} dari {totalQuestions} pertanyaan. Setelah dikirim, jawaban tidak dapat diubah lagi.
            </p>
            <div className="modal-actions">
              <button className="modal-btn-secondary" onClick={() => setShowSubmitModal(false)} disabled={isSubmitting}>
                Periksa Kembali
              </button>
              <button className="modal-btn-primary" onClick={() => handleFinalSubmit()} disabled={isSubmitting}>
                {isSubmitting ? 'Mengirim...' : 'Ya, Kirim Sekarang'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
