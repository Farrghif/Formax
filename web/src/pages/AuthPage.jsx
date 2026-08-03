import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { login, signup } from '../api/auth';
import '../styles/auth.css';

export default function AuthPage() {
  const navigate = useNavigate();
  const [tab, setTab] = useState('login');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [showPass, setShowPass] = useState(false);

  // Login state
  const [loginData, setLoginData] = useState({ email: '', password: '', remember: false });

  // Register state
  const [registerData, setRegisterData] = useState({
    full_name: '',
    email: '',
    password: '',
    remember: false,
  });

  const handleLogin = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const res = await login({ email: loginData.email, password: loginData.password });
      localStorage.setItem('token', res.access_token);
      navigate('/dashboard');
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
      const res = await signup({
        full_name: registerData.full_name,
        email: registerData.email,
        password: registerData.password,
      });
      localStorage.setItem('token', res.access_token);
      navigate('/dashboard');
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const switchTab = (t) => {
    setTab(t);
    setError('');
    setShowPass(false);
  };

  return (
    <div className="auth-bg">
      {/* Wave SVG top */}
      <svg className="wave wave-top" viewBox="0 0 1440 200" preserveAspectRatio="none" xmlns="http://www.w3.org/2000/svg">
        <path fill="#1d4ed8" d="M0,80 C360,160 1080,0 1440,80 L1440,0 L0,0 Z" />
        <path fill="#3b82f6" opacity="0.6" d="M0,100 C400,20 1000,180 1440,60 L1440,0 L0,0 Z" />
        <path fill="#93c5fd" opacity="0.35" d="M0,60 C500,140 900,20 1440,100 L1440,0 L0,0 Z" />
      </svg>

      {/* Wave SVG bottom */}
      <svg className="wave wave-bottom" viewBox="0 0 1440 200" preserveAspectRatio="none" xmlns="http://www.w3.org/2000/svg">
        <path fill="#1d4ed8" d="M0,120 C360,40 1080,200 1440,120 L1440,200 L0,200 Z" />
        <path fill="#3b82f6" opacity="0.6" d="M0,100 C400,180 1000,20 1440,140 L1440,200 L0,200 Z" />
        <path fill="#93c5fd" opacity="0.35" d="M0,140 C500,60 900,180 1440,100 L1440,200 L0,200 Z" />
      </svg>

      {/* Card */}
      <div className="auth-card">
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
              {loading ? <span className="spinner" /> : 'Register'}
            </button>
            <p className="auth-footer">
              Already have an account?{' '}
              <button type="button" className="auth-link" onClick={() => switchTab('login')}>
                Login
              </button>
            </p>
          </form>
        )}
      </div>
    </div>
  );
}
