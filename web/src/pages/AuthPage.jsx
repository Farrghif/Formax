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

  const handleOtpKeyDown = (index, e) => {
    if (e.key === 'Backspace' && !otpInputs[index] && index > 0) {
      inputRefs.current[index - 1].focus();
    }
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

        {/* OTP Verification View */}
        {otpStep && (
          <div className="otp-container">
            <button className="back-btn" onClick={() => setOtpStep(false)}>
              <svg width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                <path d="M15 19l-7-7 7-7" />
              </svg>
            </button>
            
            <div className="otp-header">
              <h2>OTP Verification</h2>
              <p>Enter the 6-digit code we sent to your email.</p>
              <span className="recipient-email">{registerData.email}</span>
            </div>

            <div className="otp-content">
              <div className="otp-illustration">
                {/* SVG Illustration based on screenshot */}
                <svg width="100" height="100" viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <rect x="20" y="30" width="60" height="40" rx="4" fill="#E0F2FE" />
                  <path d="M20 34L50 54L80 34" stroke="#3B82F6" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                  <circle cx="50" cy="40" r="8" fill="#3B82F6" opacity="0.2" />
                  <path d="M46 40C46 37.7909 47.7909 36 50 36C52.2091 36 54 37.7909 54 40" stroke="#3B82F6" strokeWidth="1.5" strokeLinecap="round" />
                  <circle cx="50" cy="42" r="3" fill="#3B82F6" />
                  <circle cx="75" cy="65" r="12" fill="white" stroke="#3B82F6" strokeWidth="2" />
                  <path d="M70 65L73.5 68.5L80 62" stroke="#3B82F6" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </div>

              <div className="otp-inputs">
                {otpInputs.map((digit, idx) => (
                  <input
                    key={idx}
                    ref={(el) => (inputRefs.current[idx] = el)}
                    type="text"
                    inputMode="numeric"
                    maxLength={1}
                    value={digit}
                    onChange={(e) => handleOtpChange(idx, e.target.value)}
                    onKeyDown={(e) => handleOtpKeyDown(idx, e)}
                    className="otp-input-box"
                  />
                ))}
              </div>

              <div className="otp-timer-row">
                <div className="resend-text">
                  Don't have a code?{' '}
                  <button 
                    className={`resend-btn ${timer > 0 ? 'disabled' : ''}`} 
                    onClick={handleResendOtp}
                    disabled={timer > 0 || loading}
                  >
                    Re-Send
                  </button>
                </div>
                <div className={`timer-display ${timer < 60 ? 'warning' : ''}`}>
                  {formatTime(timer)}
                </div>
              </div>

              {error && (
                <div className="auth-error otp-error">
                  {error}
                </div>
              )}

              <button className="auth-btn confirm-btn" onClick={handleConfirmOtp} disabled={loading || otpInputs.join('').length < 6}>
                {loading ? <span className="spinner" /> : 'Confirm'}
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
