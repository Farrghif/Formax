import { useState, useEffect, useRef, useCallback } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { getPublicFormBySlug, joinForm, saveAnswer, submitFinal, getSubmissionResult, flagCheated } from '../api/submissions';
import { uploadFile } from '../api/uploads';
import { getMe } from '../api/auth';
import ThemeToggle from '../components/ThemeToggle';
import NgrokImage from '../components/NgrokImage';
import NgrokAudio from '../components/NgrokAudio';
import { apiFetch } from '../api/config';
import logoForm4x from '../assets/logo_form4x.png';
import '../styles/form-fill.css';

const QUESTIONS_PER_PAGE = 4;
const ZOOM_MIN = 50;
const ZOOM_MAX = 200;
const ZOOM_STEP = 10;

// Normalisasi warna hex 8-digit ARGB (format lama dari editor mobile, mis.
// #FF4FC3F7) menjadi #RGB 6-digit. Browser mengartikan 8-digit sebagai
// `#RRGGBBAA` (CSS Color 4) sehingga warna yang dipilih tampil salah/pink.
function normalizeColors(html) {
  return String(html ?? '').replace(/#([0-9A-Fa-f]{8})\b/g, (_m, hex) => {
    const a = parseInt(hex.slice(0, 2), 16);
    const r = parseInt(hex.slice(2, 4), 16);
    const g = parseInt(hex.slice(4, 6), 16);
    const b = parseInt(hex.slice(6, 8), 16);
    if (a === 255) {
      return '#' + hex.slice(2).toUpperCase();
    }
    return `rgba(${r}, ${g}, ${b}, ${(a / 255).toFixed(3)})`;
  });
}

// Terjemah HTML rich-text (milik pembuat form) menjadi objek props yang bisa
// dirender React. Dipakai untuk judul, deskripsi, label soal & opsi agar tampil
// terformat (mirip RichTextView di aplikasi mobile), bukan sebagai tag mentah.
const richHtml = (html) => ({ __html: normalizeColors(html ?? '') });

// Hook untuk fix audio ngrok di dalam container dangerouslySetInnerHTML
// Browser <audio> tidak bisa kirim header ngrok-skip-browser-warning -> perlu blob
function useNgrokAudioFix(containerRef, html) {
  useEffect(() => {
    const el = containerRef.current;
    if (!el || !html) return;
    const audios = el.querySelectorAll('audio[src*="ngrok-free"]');
    if (audios.length === 0) return;
    const controllers = [];
    audios.forEach((audio) => {
      const src = audio.getAttribute('src');
      if (!src || src.startsWith('data:audio/') || src.startsWith('data:video/') || src.startsWith('blob:') || audio.dataset.ngrokFixed) return;
      audio.dataset.ngrokFixed = '1';
      audio.dataset.originalSrc = src;
      const controller = new AbortController();
      controllers.push(controller);
      // Placeholder style sambil load
      audio.style.opacity = '0.6';
      apiFetch(src, { signal: controller.signal })
        .then((res) => {
          if (!res.ok) throw new Error(`HTTP ${res.status}`);
          return res.blob();
        })
        .then((blob) => {
          if (blob.type && blob.type.startsWith('text/html')) throw new Error('Ngrok HTML');
          const blobUrl = URL.createObjectURL(blob);
          audio.src = blobUrl;
          audio.load();
          audio.style.opacity = '1';
          // cleanup saat unmount / html ganti
          audio.dataset.blobUrl = blobUrl;
        })
        .catch((err) => {
          if (err.name === 'AbortError') return;
          console.error('[NgrokAudioFix] gagal:', src, err);
          audio.style.opacity = '1';
        });
    });
    return () => {
      controllers.forEach((c) => c.abort());
      // revoke blob URLs
      if (el) {
        el.querySelectorAll('audio[data-blob-url]').forEach((a) => {
          const u = a.dataset.blobUrl;
          if (u) URL.revokeObjectURL(u);
        });
      }
    };
  }, [html]);
}

// Buang semua markup HTML jadi teks polos. Dipakai untuk konten responden
// (jawaban) dan elemen yang tidak bisa memuat markup seperti <option>.
function stripHtml(html) {
  return String(html ?? '')
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/\s+/g, ' ')
    .trim();
}

export default function FormFillPage() {
  const { slug } = useParams();
  const navigate = useNavigate();
  const token = localStorage.getItem('token');

  // Form & Submission states
  const [form, setForm] = useState(null);
  const [submissionId, setSubmissionId] = useState(null);
  const [answers, setAnswers] = useState({}); // { [question_id]: { answer_text, answer_options, file_url } }
  const [bookmarked, setBookmarked] = useState(() => {
    try {
      const raw = localStorage.getItem(`bm:${slug}`);
      return new Set(JSON.parse(raw || '[]'));
    } catch { return new Set(); }
  });
  const [loading, setLoading] = useState(true);
  const [errorMsg, setErrorMsg] = useState('');

  // Pagination & Navigation
  const [currentPage, setCurrentPage] = useState(0);

  // Zoom controls (perbesar/perkecil teks pertanyaan didalam card)
  const [zoomLevel, setZoomLevel] = useState(() => {
    const saved = parseInt(localStorage.getItem('formFillZoom'), 10);
    return !isNaN(saved) && saved >= ZOOM_MIN && saved <= ZOOM_MAX ? saved : 100;
  });

  // Image Modal / Lightbox preview (klik gambar di soal untuk perbesar)
  const [modalImage, setModalImage] = useState(null);
  const [imgModalZoom, setImgModalZoom] = useState(1);

  // Esc key listener to close image preview
  useEffect(() => {
    if (!modalImage) return;
    const handleKeyDown = (e) => {
      if (e.key === 'Escape') setModalImage(null);
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [modalImage]);

  // Delegated click handler to detect clicks on images within questions/content
  const handleContentImageClick = (e) => {
    const target = e.target;
    if (target && target.tagName === 'IMG') {
      if (
        target.classList.contains('form-fill-logo-img') ||
        target.classList.contains('option-check-icon')
      ) return;

      const src = target.currentSrc || target.src || target.getAttribute('src');
      if (src) {
        setModalImage({
          src,
          alt: target.alt || target.getAttribute('alt') || 'Gambar Pertanyaan',
        });
        setImgModalZoom(1);
      }
    }
  };

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

  // Fullscreen / anti-cheat
  const [cheated, setCheated] = useState(false);
  const cheatedRef = useRef(false);
  const doneRef = useRef(false); // true setelah submit selesai / sudah submit
  const [fullscreenStarted, setFullscreenStarted] = useState(false);
  const [showFullscreenIntro, setShowFullscreenIntro] = useState(false);
  const [showFullscreenWarning, setShowFullscreenWarning] = useState(false);

  // Validasi wajib diisi
  const [validationErrors, setValidationErrors] = useState(() => new Set());

  // Lihat hasil
  const [result, setResult] = useState(null);
  const [showResult, setShowResult] = useState(false);
  const [resultLoading, setResultLoading] = useState(false);

  // Helper untuk ambil token fresh (biar tidak stale closure)
  const getToken = () => localStorage.getItem('token');

  // 1. Initial Load (allow anonymous via respondent_key)
  useEffect(() => {
    // Jangan redirect paksa ke login — biarkan anonim isi via X-Respondent-Key
    // Jika token ada, akan dipakai; jika tidak, akan pakai respondent_key otomatis

    const loadForm = async () => {
      try {
        setLoading(true);
        setErrorMsg('');
        const formData = await getPublicFormBySlug(getToken(), slug);
        setForm(formData);

        // Try auto joining form (if no join token required or user already joined)
        try {
          if (joiningRef.current) return;
          joiningRef.current = true;
          const sub = await joinForm(getToken(), slug);
          setSubmissionId(sub.id);
          if (sub.submitted_at) {
            setIsSubmitted(true);
          } else if (formData.require_fullscreen) {
            setShowFullscreenIntro(true);
          }
          if (sub.is_cheated) {
            setCheated(true);
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
  }, [slug, navigate]);

  // Handle manual join with token
  const handleJoinWithToken = async (e) => {
    e.preventDefault();
    setJoinError('');
    try {
      const sub = await joinForm(getToken(), slug, joinTokenInput);
      setSubmissionId(sub.id);
      setShowJoinModal(false);
      if (sub.submitted_at) {
        setIsSubmitted(true);
      } else if (form?.require_fullscreen) {
        setShowFullscreenIntro(true);
      }
      if (sub.is_cheated) {
        setCheated(true);
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

  // Validasi wajib diisi — dipakai sebelum submit (disable + scroll)
  const getMissingRequired = useCallback(() => {
    if (!form || !form.questions) return [];
    return form.questions.filter((q) => q.is_required && !isQuestionAnswered(q.id));
  }, [form, answers]);

  // Handle Final Submit (dengan validasi wajib)
  const handleFinalSubmit = async () => {
    if (!submissionId) return;
    const missing = getMissingRequired();
    if (missing.length > 0) {
      setValidationErrors(new Set(missing.map((q) => q.id)));
      // pindah ke halaman yang berisi soal wajib pertama
      const idx = (form?.questions || []).findIndex((q) => q.id === missing[0].id);
      if (idx >= 0) {
        const page = Math.floor(idx / QUESTIONS_PER_PAGE);
        setCurrentPage(page);
        // close modal dulu biar scroll terlihat
        setShowSubmitModal(false);
        setTimeout(() => {
          document.getElementById(`q-${missing[0].id}`)?.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }, 120);
      }
      return;
    }
    try {
      setIsSubmitting(true);
      await submitFinal(getToken(), submissionId);
      setIsSubmitted(true);
      doneRef.current = true;
      setShowSubmitModal(false);
      setValidationErrors(new Set());
      try { localStorage.removeItem(`bm:${slug}`); } catch {}
      setBookmarked(new Set());
      if (document.fullscreenElement) {
        document.exitFullscreen().catch(() => {});
      }
    } catch (err) {
      // Jika backend 422 karena wajib, sync highlight + scroll
      const msg = err.message || '';
      // coba parse missing dari detail backend jika ada (sudah di-join di readJsonResponse)
      if (msg.toLowerCase().includes('wajib')) {
        const miss = getMissingRequired();
        if (miss.length > 0) {
          setValidationErrors(new Set(miss.map((q) => q.id)));
          const idx2 = (form?.questions || []).findIndex((q) => q.id === miss[0].id);
          if (idx2 >= 0) {
            setCurrentPage(Math.floor(idx2 / QUESTIONS_PER_PAGE));
            setShowSubmitModal(false);
            setTimeout(() => document.getElementById(`q-${miss[0].id}`)?.scrollIntoView({ behavior: 'smooth', block: 'center' }), 120);
          }
        }
      }
      alert(err.message || 'Gagal mengirimkan form');
    } finally {
      setIsSubmitting(false);
    }
  };

  // Enter fullscreen (dipicu tombol "Mulai" / "Kembali ke Full Screen")
  const enterFullscreen = async () => {
    setFullscreenStarted(true);
    setShowFullscreenWarning(false);
    try {
      const el = document.documentElement;
      if (!document.fullscreenElement && el.requestFullscreen) {
        await el.requestFullscreen();
      }
    } catch {
      // browser menolak (butuh user gesture / unsupported) — tetap lanjut best-effort
    }
  };

  // User keluar fullscreen / pindah tab saat mode fullscreen aktif -> tandai curang (sekali).
  const handleFullscreenExit = useCallback(() => {
    if (cheatedRef.current || doneRef.current) return;
    cheatedRef.current = true;
    setCheated(true);
    setShowFullscreenWarning(true);
    if (submissionId && form?.require_fullscreen) {
      flagCheated(getToken(), submissionId).catch(() => {});
    }
  }, [submissionId, form, token]);

  // Listener fullscreenchange + visibilitychange
  useEffect(() => {
    if (!form?.require_fullscreen || isSubmitted) return;
    const onFullscreenChange = () => {
      if (!document.fullscreenElement) {
        handleFullscreenExit();
      }
    };
    const onVisibilityChange = () => {
      if (document.hidden && document.fullscreenElement) {
        handleFullscreenExit();
      }
    };
    document.addEventListener('fullscreenchange', onFullscreenChange);
    document.addEventListener('visibilitychange', onVisibilityChange);
    return () => {
      document.removeEventListener('fullscreenchange', onFullscreenChange);
      document.removeEventListener('visibilitychange', onVisibilityChange);
    };
  }, [form, isSubmitted, handleFullscreenExit]);

  // Fetch hasil submission untuk ditampilkan
  const handleViewResult = async () => {
    if (!submissionId) return;
    setResultLoading(true);
    try {
      const data = await getSubmissionResult(getToken(), submissionId);
      setResult(data);
      setShowResult(true);
      if (document.fullscreenElement) {
        document.exitFullscreen().catch(() => {});
      }
    } catch (err) {
      alert(err.message || 'Gagal mengambil hasil form');
    } finally {
      setResultLoading(false);
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

  // Zoom handlers (persist ke localStorage)
  useEffect(() => {
    localStorage.setItem('formFillZoom', String(zoomLevel));
  }, [zoomLevel]);

  const handleZoomIn = () => setZoomLevel((z) => Math.min(ZOOM_MAX, z + ZOOM_STEP));
  const handleZoomOut = () => setZoomLevel((z) => Math.max(ZOOM_MIN, z - ZOOM_STEP));
  const handleZoomReset = () => setZoomLevel(100);

  // Handle profile hover - requirement: "di kanan atas logo profile jika dihover hanya memuat API get me saja"
  const handleProfileMouseEnter = () => {
    if (hoverTimeoutRef.current) clearTimeout(hoverTimeoutRef.current);
    setShowProfilePopover(true);
    if (!userProfile) {
      getMe(getToken())
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

  // Bookmark — hanya frontend, persist per form slug (kuning di Navigator)
  useEffect(() => {
    try {
      const raw = localStorage.getItem(`bm:${slug}`);
      setBookmarked(new Set(JSON.parse(raw || '[]')));
    } catch { setBookmarked(new Set()); }
  }, [slug]);

  const toggleBookmark = useCallback((qId) => {
    setBookmarked((prev) => {
      const next = new Set(prev);
      if (next.has(qId)) next.delete(qId);
      else next.add(qId);
      try { localStorage.setItem(`bm:${slug}`, JSON.stringify([...next])); } catch {}
      return next;
    });
  }, [slug]);

  // Answer handler & Autosave (clear validasi wajib jika sudah terisi)
  const handleAnswerChange = (questionId, newAnswerData) => {
    const updated = {
      ...answers,
      [questionId]: {
        ...(answers[questionId] || {}),
        ...newAnswerData,
      },
    };
    setAnswers(updated);
    // jika soal wajib sudah terisi, hapus highlight error
    const cur = updated[questionId];
    const filled = (cur?.answer_text && String(cur.answer_text).trim().length > 0)
      || (Array.isArray(cur?.answer_options) && cur.answer_options.length > 0)
      || !!cur?.file_url;
    if (filled && validationErrors.has(questionId)) {
      setValidationErrors((prev) => {
        const next = new Set(prev);
        next.delete(questionId);
        return next;
      });
    }

    // Trigger autosave to backend if submission exists
    if (submissionId) {
      saveAnswer(getToken(), submissionId, {
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
      const result = await uploadFile(getToken(), file);
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
                  <span className="option-label-text" dangerouslySetInnerHTML={richHtml(opt.label)} />
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
                  <span className="option-label-text" dangerouslySetInnerHTML={richHtml(opt.label)} />
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
                  {stripHtml(opt.label)}
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

  // Halaman Hasil (responden lihat skor + rincian jawaban)
  if (showResult && result) {
    return (
      <div className="form-fill-container">
        <header className="form-fill-header">
          <div className="form-fill-logo-wrap" onClick={() => navigate('/dashboard')} style={{ cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '10px' }} role="button" tabIndex={0} aria-label="Ke dashboard">
            <img src={logoForm4x} alt="Form4x logo" className="form-fill-logo-img" />
            <h1 className="form-fill-logo">Form4x</h1>
          </div>
          <div className="form-fill-header-right">
            <ThemeToggle />
            <button
              className="profile-avatar-btn"
              onClick={() => navigate('/dashboard')}
              aria-label="Kembali ke dashboard"
              title="Kembali ke dashboard"
            >
              <svg width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M3 12l9-9 9 9M5 10v10a1 1 0 001 1h3a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1h3a1 1 0 001-1V10" />
              </svg>
            </button>
          </div>
        </header>
        <main className="result-main">
          <div className="result-card">
            <h2 className="result-title" dangerouslySetInnerHTML={richHtml(result.form_title)} />
            <p className="result-subtitle">Hasil submission Anda</p>

            {result.is_cheated && (
              <div className="cheated-banner">
                <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                </svg>
                Submission ini ditandai curang karena keluar dari mode full screen.
              </div>
            )}

            {result.score_percent !== null ? (
              <div className="score-card">
                <div className={`score-ring ${result.is_cheated ? 'cheated' : ''}`}>
                  <span className="score-value">{result.score_percent}%</span>
                  <span className="score-label">Skor</span>
                </div>
                <div className="score-detail">
                  <div className="score-stat correct">
                    <span className="score-stat-num">{result.correct_count}</span>
                    <span className="score-stat-label">Benar</span>
                  </div>
                  <div className="score-stat">
                    <span className="score-stat-num">{result.total_graded - result.correct_count}</span>
                    <span className="score-stat-label">Salah</span>
                  </div>
                  <div className="score-stat">
                    <span className="score-stat-num">{result.total_graded}</span>
                    <span className="score-stat-label">Dinilai</span>
                  </div>
                </div>
              </div>
            ) : (
              <p className="result-no-score">Form ini tidak memiliki kunci jawaban, jadi skor tidak dihitung.</p>
            )}

            <div className="result-answers">
              {result.answers.map((a, idx) => (
                <div key={a.question_id} className="result-answer-item">
                  <div className="result-answer-header">
                    <span className="result-q-number">{idx + 1}.</span>
                    <div className="result-q-label" dangerouslySetInnerHTML={richHtml(a.label)} />
                    {a.is_correct !== null && a.is_correct !== undefined && (
                      <span className={`result-badge ${a.is_correct ? 'correct' : 'wrong'}`}>
                        {a.is_correct ? 'Benar' : 'Salah'}
                      </span>
                    )}
                  </div>
                  <div className="result-answer-body">
                    <p>
                      <span className="result-label">Jawaban Anda:</span>
                      <span className={`result-answer-text ${a.is_correct === false ? 'wrong' : ''}`}>
                        {stripHtml(a.user_answer) || '(tidak dijawab)'}
                      </span>
                    </p>
                    {a.correct_answer && (
                      <p>
                        <span className="result-label">Jawaban Benar:</span>
                        <span className="result-answer-text correct">{stripHtml(a.correct_answer)}</span>
                      </p>
                    )}
                  </div>
                </div>
              ))}
            </div>

            <button className="modal-btn-primary" onClick={() => navigate('/dashboard')}>
              Kembali ke Dashboard
            </button>
          </div>
        </main>
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
          <div className="form-fill-logo-wrap" onClick={() => navigate('/dashboard')} style={{ cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '10px' }} role="button" tabIndex={0} aria-label="Ke dashboard">
            <img src={logoForm4x} alt="Form4x logo" className="form-fill-logo-img" />
            <h1 className="form-fill-logo">Form4x</h1>
          </div>
          <div className="form-fill-header-right">
            <ThemeToggle />
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
          <p style={{ color: '#64748B', fontSize: '15px', lineHeight: '1.6', marginBottom: '20px' }}>
            Terima kasih telah mengisi <strong dangerouslySetInnerHTML={richHtml(form?.title)} />. Jawaban Anda telah tersimpan dengan aman di sistem.
          </p>

          {cheated && (
            <div className="cheated-banner" style={{ marginBottom: '20px' }}>
              <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
              Submission Anda ditandai curang karena keluar dari mode full screen.
            </div>
          )}

          <div style={{ display: 'flex', gap: '12px', justifyContent: 'center', flexWrap: 'wrap' }}>
            {form?.allow_see_result && submissionId && (
              <button
                className="modal-btn-primary"
                onClick={handleViewResult}
                disabled={resultLoading}
                style={{ background: '#2563EB', borderColor: '#2563EB' }}
              >
                {resultLoading ? 'Mengambil hasil...' : 'Lihat Hasil'}
              </button>
            )}
            <button
              className="modal-btn-primary"
              onClick={() => navigate('/dashboard')}
              style={{ background: '#475569', borderColor: '#475569' }}
            >
              Kembali ke Dashboard
            </button>
          </div>
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
        <div className="form-fill-logo-wrap" onClick={() => navigate('/dashboard')} style={{ cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '10px' }} role="button" tabIndex={0} aria-label="Ke dashboard">
          <img src={logoForm4x} alt="Form4x logo" className="form-fill-logo-img" />
          <h1 className="form-fill-logo">Form4x</h1>
        </div>
        <div className="form-fill-header-right">
          {/* Zoom Controls (perbesar / perkecil teks pertanyaan didalam card) */}
          <div className="zoom-controls">
            <button
              className="zoom-btn"
              onClick={handleZoomOut}
              disabled={zoomLevel <= ZOOM_MIN}
              title="Perkecil teks pertanyaan"
              aria-label="Perkecil teks pertanyaan"
            >
              <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M20 12H4" />
              </svg>
            </button>
            <button
              className="zoom-level-label"
              onClick={handleZoomReset}
              title="Reset ukuran teks ke 100%"
            >
              {zoomLevel}%
            </button>
            <button
              className="zoom-btn"
              onClick={handleZoomIn}
              disabled={zoomLevel >= ZOOM_MAX}
              title="Perbesar teks pertanyaan"
              aria-label="Perbesar teks pertanyaan"
            >
              <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M12 4v16m8-8H4" />
              </svg>
            </button>
          </div>

          {timeLeft !== null && (
            <div className={`form-fill-timer ${timeLeft <= 60 ? 'urgent' : ''}`}>
              <svg className="form-fill-timer-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <span>{formatTimer(timeLeft)}</span>
            </div>
          )}

          <ThemeToggle />
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
              const isBm = bookmarked.has(q.id);
              const qPage = Math.floor(idx / QUESTIONS_PER_PAGE);
              const isCurrentPage = qPage === currentPage;
              let boxState = 'unanswered';
              if (isBm && !isAns) boxState = 'bookmarked';
              else if (isAns) boxState = 'answered';
              const bmClass = isBm && isAns ? ' bookmarked' : isBm && !isAns ? '' : '';
              // untuk sudah diisi+bookmark: tetap biru tapi tambah strip kuning via ::after
              const finalClass = `navigator-box ${boxState}${bmClass} ${isCurrentPage ? 'current-page' : ''}`;
              return (
                <div
                  key={q.id}
                  className={finalClass}
                  onClick={() => {
                    setCurrentPage(qPage);
                    window.scrollTo({ top: 0, behavior: 'smooth' });
                  }}
                  title={`Soal #${idx + 1} (${isAns ? 'Sudah Diisi' : 'Belum Diisi'}${isBm ? ' • Ditandai' : ''})`}
                >
                  {idx + 1}
                </div>
              );
            })}
          </div>
        </aside>

        {/* Right Column: Questions Form Content */}
        <section
          className="form-content-area"
          style={{ zoom: zoomLevel / 100, '--q-scale': zoomLevel / 100 }}
          onClick={handleContentImageClick}
        >
          {form?.banner_url && (
            <div className="form-fill-banner">
              <NgrokImage src={form.banner_url} alt="Banner form" className="form-fill-banner-img" />
            </div>
          )}
          <div className="form-header-details">
            <h2 className="form-title" dangerouslySetInnerHTML={richHtml(form?.title)} />
            {form?.description && <FormDescriptionWithAudio html={form.description} />}
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

            const isReqError = q.is_required && validationErrors.has(q.id);
            return (
              <div key={q.id} className={`question-card ${isReqError ? 'required-error' : ''}`} id={`q-${q.id}`}>
                <div className="question-card-header">
                  <div className="question-label">
                    <span className="question-number">{globalNumber}.</span>
                    <QuestionLabelWithAudio html={q.label} />
                    {q.is_required && <span className="required-star" title="Wajib diisi">*</span>}
                  </div>
                  <div className="question-header-right">
                    <button
                      className={`q-bookmark-btn ${bookmarked.has(q.id) ? 'active' : ''}`}
                      onClick={() => toggleBookmark(q.id)}
                      title={bookmarked.has(q.id) ? 'Hapus tanda' : 'Tandai'}
                      aria-label={bookmarked.has(q.id) ? 'Hapus tanda bookmark' : 'Tandai soal'}
                      type="button"
                    >
                      <svg width="16" height="16" viewBox="0 0 24 24" fill={bookmarked.has(q.id) ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth={1.9} strokeLinecap="round" strokeLinejoin="round">
                        <path d="M19 21l-7-5-7 5V5a2 2 0 012-2h10a2 2 0 012 2z" />
                      </svg>
                    </button>
                    <span className="question-type-tag">{getTypeLabel(q.type)}</span>
                    {points !== null && <span className="points-badge">{points} poin</span>}
                  </div>
                </div>

                {/* Context Box if available (e.g. reading passage box from design mock) */}
                {contextText && <div className="question-context-box">{contextText}</div>}

                {/* Render question input based on type */}
                {renderQuestionInput(q, currentAnswer)}
                {q.is_required && validationErrors.has(q.id) && (
                  <p className="required-error-msg">* Pertanyaan wajib diisi</p>
                )}
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

            <button className="btn-submit-final" onClick={() => {
              const miss = getMissingRequired();
              if (miss.length > 0) {
                setValidationErrors(new Set(miss.map((q) => q.id)));
                const idx = (form?.questions || []).findIndex((q) => q.id === miss[0].id);
                if (idx >= 0) {
                  const page = Math.floor(idx / QUESTIONS_PER_PAGE);
                  setCurrentPage(page);
                  setTimeout(() => document.getElementById(`q-${miss[0].id}`)?.scrollIntoView({ behavior: 'smooth', block: 'center' }), 150);
                }
              }
              setShowSubmitModal(true);
            }}>
              <span>Kirim Jawaban</span>
              <span>»</span>
            </button>
          </div>
        </section>
      </main>

      {/* Confirmation Submit Modal */}
      {showSubmitModal && (() => {
        const missingInModal = getMissingRequired();
        const canSubmit = missingInModal.length === 0;
        return (
        <div className="modal-overlay">
          <div className="modal-card">
            <h2 className="modal-title">Kirim Jawaban Form?</h2>
            <p className="modal-desc">
              Anda telah menjawab {answeredCount} dari {totalQuestions} pertanyaan. Setelah dikirim, jawaban tidak dapat diubah lagi.
            </p>
            {missingInModal.length > 0 && (
              <div className="required-modal-warn">
                <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z" /></svg>
                <span>Masih ada {missingInModal.length} pertanyaan wajib yang belum dijawab. Lengkapi dulu sebelum mengirim.</span>
              </div>
            )}
            <div className="modal-actions">
              <button className="modal-btn-secondary" onClick={() => setShowSubmitModal(false)} disabled={isSubmitting}>
                Periksa Kembali
              </button>
              <button className="modal-btn-primary" onClick={() => handleFinalSubmit()} disabled={isSubmitting || !canSubmit} title={!canSubmit ? `Lengkapi ${missingInModal.length} soal wajib dulu` : ''}>
                {isSubmitting ? 'Mengirim...' : 'Ya, Kirim Sekarang'}
              </button>
            </div>
          </div>
        </div>
        );
      })()}

      {/* Fullscreen Intro Overlay (wajib fullscreen) */}
      {form?.require_fullscreen && !isSubmitted && showFullscreenIntro && !fullscreenStarted && (
        <div className="ff-overlay">
          <div className="ff-overlay-card">
            <div className="ff-overlay-icon">
              <svg width="36" height="36" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M4 8V6a2 2 0 012-2h2M16 4h2a2 2 0 012 2v2M20 16v2a2 2 0 01-2 2h-2M8 20H6a2 2 0 01-2-2v-2" />
              </svg>
            </div>
            <h2 className="ff-overlay-title">Mode Full Screen Diwajibkan</h2>
            <p className="ff-overlay-desc">
              Form ini wajib dikerjakan di mode full screen. Jika Anda keluar dari mode full screen atau berpindah tab,
              submission Anda akan <strong>ditandai sebagai curang</strong> oleh sistem.
            </p>
            <button className="modal-btn-primary" onClick={enterFullscreen}>
              Masuk Full Screen &amp; Mulai
            </button>
          </div>
        </div>
      )}

      {/* Fullscreen Warning Overlay (keluar dari fullscreen) */}
      {showFullscreenWarning && !isSubmitted && (
        <div className="ff-overlay warning">
          <div className="ff-overlay-card">
            <div className="ff-overlay-icon danger">
              <svg width="32" height="32" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
            </div>
            <h2 className="ff-overlay-title">Anda Keluar dari Mode Full Screen</h2>
            <p className="ff-overlay-desc">
              Submission Anda telah <strong>ditandai sebagai curang</strong> oleh sistem. Anda tetap bisa melanjutkan,
              namun tanda ini akan tercatat di hasil Anda.
            </p>
            <div style={{ display: 'flex', gap: '12px', justifyContent: 'center', flexWrap: 'wrap' }}>
              <button className="modal-btn-primary" onClick={enterFullscreen}>
                Kembali ke Full Screen
              </button>
              <button
                className="modal-btn-secondary"
                onClick={() => setShowFullscreenWarning(false)}
              >
                Lanjutkan Mengisi
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Image Zoom Lightbox Overlay */}
      {modalImage && (
        <div
          className="img-lightbox-overlay"
          onClick={() => setModalImage(null)}
          role="dialog"
          aria-modal="true"
          aria-label="Preview Gambar"
        >
          <div className="img-lightbox-container" onClick={(e) => e.stopPropagation()}>
            <div className="img-lightbox-header">
              <div className="img-lightbox-title-wrap">
                <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM10 7v6m3-3H7" />
                </svg>
                <span className="img-lightbox-title">{modalImage.alt || 'Detail Gambar'}</span>
              </div>
              <div className="img-lightbox-controls">
                <button
                  type="button"
                  className="lightbox-btn"
                  onClick={() => setImgModalZoom((z) => Math.max(0.5, +(z - 0.25).toFixed(2)))}
                  disabled={imgModalZoom <= 0.5}
                  title="Perkecil Gambar"
                >
                  <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M20 12H4" />
                  </svg>
                </button>
                <span
                  className="lightbox-zoom-val"
                  onClick={() => setImgModalZoom(1)}
                  title="Klik untuk reset ke 100%"
                >
                  {Math.round(imgModalZoom * 100)}%
                </span>
                <button
                  type="button"
                  className="lightbox-btn"
                  onClick={() => setImgModalZoom((z) => Math.min(3, +(z + 0.25).toFixed(2)))}
                  disabled={imgModalZoom >= 3}
                  title="Perbesar Gambar"
                >
                  <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M12 4v16m8-8H4" />
                  </svg>
                </button>
                <div className="lightbox-divider" />
                <button
                  type="button"
                  className="lightbox-close-btn"
                  onClick={() => setModalImage(null)}
                  title="Tutup (Esc)"
                  aria-label="Tutup"
                >
                  <svg width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
            </div>
            <div className="img-lightbox-body">
              <div className="img-lightbox-stage" style={{ transform: `scale(${imgModalZoom})` }}>
                <img src={modalImage.src} alt={modalImage.alt || 'Preview Gambar'} className="img-lightbox-img" />
              </div>
            </div>
            <p className="img-lightbox-hint">Klik di luar atau tekan <kbd>Esc</kbd> untuk menutup</p>
          </div>
        </div>
      )}
    </div>
  );
}

function FormDescriptionWithAudio({ html }) {
  const ref = useRef(null);
  useNgrokAudioFix(ref, html);
  return <div ref={ref} className="form-description" dangerouslySetInnerHTML={richHtml(html)} />;
}

function QuestionLabelWithAudio({ html }) {
  const ref = useRef(null);
  useNgrokAudioFix(ref, html);
  return <div ref={ref} className="question-label-content" dangerouslySetInnerHTML={richHtml(html)} />;
}
