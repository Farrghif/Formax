import { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { login, signup, sendOtp } from '../api/auth';
import logoForm4x from '../assets/logo_form4x.png';
import ThemeToggle from '../components/ThemeToggle';
import '../styles/auth.css';

export default function AuthPage() {
  const navigate = useNavigate();
  const [tab, setTab] = useState('login');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [showPass, setShowPass] = useState(false);
  const [otpStep, setOtpStep] = useState(false);
  
  // OTP state
  const [otpInputs, setOtpInputs] = useState(['', '', '', '', '', '']);
  const [timer, setTimer] = useState(300); // 5 minutes
  const inputRefs = useRef([]);

  // Login state
  const [loginData, setLoginData] = useState({ email: '', password: '', remember: false });

  // Register state
  const [registerData, setRegisterData] = useState({
    full_name: '',
    email: '',
    password: '',
    remember: false,
  });

  // Timer effect
  useEffect(() => {
    let interval = null;
    if (otpStep && timer > 0) {
      interval = setInterval(() => {
        setTimer((prev) => prev - 1);
      }, 1000);
    } else if (timer === 0) {
      clearInterval(interval);
    }
    return () => clearInterval(interval);
  }, [otpStep, timer]);

  const formatTime = (seconds) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  const handleLogin = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const res = await login({ email: loginData.email, password: loginData.password });
      localStorage.setItem('token', res.access_token);
      const params = new URLSearchParams(window.location.search);
      const redirectPath = params.get('redirect');
      navigate(redirectPath ? decodeURIComponent(redirectPath) : '/dashboard');
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleRegister = async (e) => {
    e.preventDefault();
    setError('');
    if (registerData.password.length < 6) {
      setError('Password minimal 6 karakter');
      return;
    }

    setLoading(true);
    try {
      // Step 1: kirim OTP ke email
      await sendOtp(registerData.email);
      setOtpStep(true);
      setTimer(300);
      setOtpInputs(['', '', '', '', '', '']);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleConfirmOtp = async (e) => {
    if (e) e.preventDefault();
    const otpCode = otpInputs.join('');
    if (otpCode.length < 6) {
      setError('Masukkan 6 digit kode OTP');
      return;
    }

    setLoading(true);
    setError('');
    try {
      const res = await signup({
        full_name: registerData.full_name,
        email: registerData.email,
        password: registerData.password,
        otp: otpCode,
      });
      localStorage.setItem('token', res.access_token);
      const params = new URLSearchParams(window.location.search);
      const redirectPath = params.get('redirect');
      navigate(redirectPath ? decodeURIComponent(redirectPath) : '/dashboard');
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleResendOtp = async () => {
    if (timer > 0) return;
    setLoading(true);
    setError('');
    try {
      await sendOtp(registerData.email);
      setTimer(300);
      setOtpInputs(['', '', '', '', '', '']);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleOtpChange = (index, value) => {
    if (!/^\d*$/.test(value)) return;
    
    const newOtp = [...otpInputs];
    newOtp[index] = value.slice(-1);
    setOtpInputs(newOtp);

    // Auto focus next
    if (value && index < 5) {
      inputRefs.current[index + 1].focus();
    }
  };

  const handleOtpPaste = (e) => {
    const text = (e.clipboardData?.getData('text') || '').replace(/\D/g, '').slice(0, 6);
    if (!text) return;
    e.preventDefault();
    const next = Array.from({ length: 6 }, (_, i) => text[i] || '');
    setOtpInputs(next);
    const last = Math.min(text.length, 6) - 1;
    if (last >= 0) inputRefs.current[last]?.focus();
    // auto submit when 6 digits pasted
    if (text.length === 6) {
      setTimeout(() => handleConfirmOtp(), 120);
    }
  };

  const handleOtpKeyDown = (index, e) => {
    if (e.key === 'Backspace' && !otpInputs[index] && index > 0) {
      inputRefs.current[index - 1].focus();
    }
    if (e.key === 'ArrowLeft' && index > 0) inputRefs.current[index - 1].focus();
    if (e.key === 'ArrowRight' && index < 5) inputRefs.current[index + 1].focus();
  };

  const switchTab = (t) => {
    setTab(t);
    setError('');
    setShowPass(false);
    setOtpStep(false);
    setOtpInputs(['', '', '', '', '', '']);
  };

  return (
    <div className="auth-bg">
      <div style={{ position: 'absolute', top: 16, right: 16, zIndex: 5 }}>
        <ThemeToggle />
      </div>
      {/* Wave image top */}
      <img
        src="/images/auth-wave-top.png"
        alt=""
        className="wave wave-top"
        draggable="false"
      />

      {/* Wave image bottom */}
      <img
        src="/images/auth-wave-bottom.png"
        alt=""
        className="wave wave-bottom"
        draggable="false"
      />

      {/* Card */}
      <div className={`auth-card ${otpStep ? 'otp-card' : ''}`}>
        {/* Header */}
        <div className="auth-header">
          <img src={logoForm4x} alt="Form4x" className="auth-logo" draggable="false" />
        </div>

        {!otpStep && (
          <>
            {/* Tab switcher */}
            <div className="auth-tabs">
              <button
                id="tab-login"
                className={`auth-tab ${tab === 'login' ? 'active' : ''}`}
                onClick={() => switchTab('login')}
              >
                Login
              </button>
              <button
                id="tab-register"
                className={`auth-tab ${tab === 'register' ? 'active' : ''}`}
                onClick={() => switchTab('register')}
              >
                Register
              </button>
            </div>

            {/* Error alert */}
            {error && (
              <div className="auth-error" role="alert">
                <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <circle cx="12" cy="12" r="10" />
                  <line x1="12" y1="8" x2="12" y2="12" />
                  <line x1="12" y1="16" x2="12.01" y2="16" />
                </svg>
                {error}
              </div>
            )}

            {/* Login Form */}
            {tab === 'login' && (
              <form id="form-login" className="auth-form" onSubmit={handleLogin} noValidate>
                <div className="form-group">
                  <label htmlFor="login-email">Email Address<span className="required">*</span></label>
                  <input
                    id="login-email"
                    type="email"
                    placeholder="Enter your email address"
                    value={loginData.email}
                    onChange={(e) => setLoginData({ ...loginData, email: e.target.value })}
                    required
                    autoComplete="email"
                  />
                </div>
                <div className="form-group">
                  <label htmlFor="login-password">Password<span className="required">*</span></label>
                  <div className="input-password-wrap">
                    <input
                      id="login-password"
                      type={showPass ? 'text' : 'password'}
                      placeholder="Enter your password"
                      value={loginData.password}
                      onChange={(e) => setLoginData({ ...loginData, password: e.target.value })}
                      required
                      autoComplete="current-password"
                    />
                    <button type="button" className="eye-btn" onClick={() => setShowPass(!showPass)} aria-label="Toggle password">
                      {showPass ? (
                        <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <path d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94" />
                          <path d="M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19" />
                          <line x1="1" y1="1" x2="23" y2="23" />
                        </svg>
                      ) : (
                        <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <path d="M1 12S5 4 12 4s11 8 11 8-4 8-11 8S1 12 1 12z" />
                          <circle cx="12" cy="12" r="3" />
                        </svg>
                      )}
                    </button>
                  </div>
                </div>
                <div className="form-check">
                  <input
                    id="login-remember"
                    type="checkbox"
                    checked={loginData.remember}
                    onChange={(e) => setLoginData({ ...loginData, remember: e.target.checked })}
                  />
                  <label htmlFor="login-remember">Remember me</label>
                </div>
                <button id="btn-login" type="submit" className="auth-btn" disabled={loading}>
                  {loading ? <span className="spinner" /> : 'Login'}
                </button>
                <p className="auth-footer">
                  No account?{' '}
                  <button type="button" className="auth-link" onClick={() => switchTab('register')}>
                    Register
                  </button>
                </p>
              </form>
            )}

            {/* Register Form */}
            {tab === 'register' && (
              <form id="form-register" className="auth-form" onSubmit={handleRegister} noValidate>
                <div className="form-group">
                  <label htmlFor="reg-fullname">Full Name<span className="required">*</span></label>
                  <input
                    id="reg-fullname"
                    type="text"
                    placeholder="Enter your full name"
                    value={registerData.full_name}
                    onChange={(e) => setRegisterData({ ...registerData, full_name: e.target.value })}
                    required
                    autoComplete="name"
                  />
                </div>
                <div className="form-group">
                  <label htmlFor="reg-email">Email Address<span className="required">*</span></label>
                  <input
                    id="reg-email"
                    type="email"
                    placeholder="Enter your email address"
                    value={registerData.email}
                    onChange={(e) => setRegisterData({ ...registerData, email: e.target.value })}
                    required
                    autoComplete="email"
                  />
                </div>
                <div className="form-group">
                  <label htmlFor="reg-password">Password<span className="required">*</span></label>
                  <div className="input-password-wrap">
                    <input
                      id="reg-password"
                      type={showPass ? 'text' : 'password'}
                      placeholder="Enter your password"
                      value={registerData.password}
                      onChange={(e) => setRegisterData({ ...registerData, password: e.target.value })}
                      required
                      autoComplete="new-password"
                    />
                    <button type="button" className="eye-btn" onClick={() => setShowPass(!showPass)} aria-label="Toggle password">
                      {showPass ? (
                        <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <path d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94" />
                          <path d="M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19" />
                          <line x1="1" y1="1" x2="23" y2="23" />
                        </svg>
                      ) : (
                        <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <path d="M1 12S5 4 12 4s11 8 11 8-4 8-11 8S1 12 1 12z" />
                          <circle cx="12" cy="12" r="3" />
                        </svg>
                      )}
                    </button>
                  </div>
                </div>
                <div className="form-check">
                  <input
                    id="reg-remember"
                    type="checkbox"
                    checked={registerData.remember}
                    onChange={(e) => setRegisterData({ ...registerData, remember: e.target.checked })}
                  />
                  <label htmlFor="reg-remember">Remember me</label>
                </div>
                <button id="btn-register" type="submit" className="auth-btn" disabled={loading}>
                  {loading ? <span className="spinner" /> : 'Kirim OTP'}
                </button>
                <p className="auth-footer">
                  Already have an account?{' '}
                  <button type="button" className="auth-link" onClick={() => switchTab('login')}>
                    Login
                  </button>
                </p>
              </form>
            )}
          </>
        )}

        {/* OTP Verification View — redesigned Gen Z, gradasi, no emoji */}
        {otpStep && (
          <div className="otp-container">
            <div className="otp-back-row">
              <button className="back-btn" onClick={() => setOtpStep(false)} aria-label="Kembali">
                <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
                </svg>
              </button>
              <span className="back-label">Kembali</span>
              <div className="otp-stepper" style={{ marginLeft: 'auto' }}>
                <span className="otp-stepper-dot done">1</span>
                <span className="otp-stepper-line filled" />
                <span className="otp-stepper-dot active">2</span>
                <span className="otp-stepper-text">Verifikasi</span>
              </div>
            </div>

            <div className="otp-header">
              <h2>Verifikasi OTP</h2>
              <p>Kode 6 digit telah dikirim ke email kamu. Masukkan di bawah untuk lanjut.</p>
              <span className="recipient-email" title={registerData.email}>{registerData.email}</span>
            </div>

            <div className="otp-content">
              <div className="otp-illustration" aria-hidden="true">
                {/* Modern envelope + shield — gradasi dominan biru, tanpa emoji */}
                <svg width="86" height="86" viewBox="0 0 86 86" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <rect x="14" y="22" width="58" height="40" rx="12" fill="url(#otpGrad)" stroke="#BFDBFE" strokeWidth="1.2"/>
                  <path d="M14 26L43 44L72 26" stroke="#2563EB" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" opacity="0.95"/>
                  <circle cx="43" cy="39" r="10" fill="white" stroke="#2563EB" strokeWidth="1.6"/>
                  <path d="M38.5 39.5L41.2 42.2L47.8 36.6" stroke="#2563EB" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
                  <defs>
                    <linearGradient id="otpGrad" x1="14" y1="22" x2="72" y2="62" gradientUnits="userSpaceOnUse">
                      <stop stopColor="#EFF6FF"/><stop offset="1" stopColor="#DBEAFE"/>
                    </linearGradient>
                  </defs>
                </svg>
              </div>

              <div className="otp-progress-dots" aria-hidden="true">
                {Array.from({ length: 6 }).map((_, i) => (
                  <span key={i} className={`otp-progress-dot ${otpInputs[i] ? 'filled' : ''}`} />
                ))}
              </div>

              <div className={`otp-inputs ${error ? 'shake' : ''}`} onPaste={handleOtpPaste}>
                {otpInputs.map((digit, idx) => (
                  <input
                    key={idx}
                    ref={(el) => (inputRefs.current[idx] = el)}
                    type="text"
                    inputMode="numeric"
                    autoComplete={idx===0 ? "one-time-code" : "off"}
                    maxLength={1}
                    value={digit}
                    onChange={(e) => handleOtpChange(idx, e.target.value)}
                    onKeyDown={(e) => handleOtpKeyDown(idx, e)}
                    onPaste={idx===0 ? handleOtpPaste : undefined}
                    className={`otp-input-box ${digit ? 'filled' : ''}`}
                    aria-label={`Digit ${idx+1}`}
                  />
                ))}
              </div>
              <p className="otp-help">Tempel kode dari email — otomatis terisi</p>

              <div className="otp-timer-row">
                <div className="resend-text">
                  Belum dapat kode?
                  <button 
                    className={`resend-btn ${timer > 0 ? 'disabled' : ''}`} 
                    onClick={handleResendOtp}
                    disabled={timer > 0 || loading}
                  >
                    Kirim ulang
                  </button>
                </div>
                <div className={`timer-display ${timer < 60 ? 'warning' : ''}`} aria-live="polite">
                  {formatTime(timer)}
                </div>
              </div>

              {error && (
                <div className="auth-error otp-error" role="alert">
                  <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} style={{flexShrink:0}}><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
                  <span>{error}</span>
                </div>
              )}

              <button className="auth-btn confirm-btn" onClick={handleConfirmOtp} disabled={loading || otpInputs.join('').length < 6}>
                {loading ? <span className="spinner" /> : 'Konfirmasi & Buat Akun'}
              </button>
              <div className="otp-security-note">
                <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}><path d="M12 2l7 4v5c0 5-3.5 8.5-7 9.5C9.5 19.5 6 16 6 11V6l6-4z"/><path d="M9 12l2 2 4-4"/></svg>
                Kode berlaku 5 menit · jaga kerahasiaan kode
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
