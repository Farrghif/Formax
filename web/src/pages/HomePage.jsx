import { Link } from 'react-router-dom';
import logoForm4x from '../assets/logo_form4x.png';
import '../styles/landing.css';

/* ─── Feature Card Component ─── */
function FeatureCard({ icon, title, desc }) {
  return (
    <div className="hp-feat-card">
      <div className="hp-feat-icon">{icon}</div>
      <h3 className="hp-feat-title">{title}</h3>
      <p className="hp-feat-desc">{desc}</p>
    </div>
  );
}

/* ─── Main HomePage ─── */
const HomePage = () => {
  const features = [
    {
      icon: (
        <svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <circle cx="12" cy="12" r="10" />
          <path d="M8 14s1.5 2 4 2 4-2 4-2" />
          <line x1="9" y1="9" x2="9.01" y2="9" />
          <line x1="15" y1="9" x2="15.01" y2="9" />
        </svg>
      ),
      title: 'Tema Menarik',
      desc: 'Sesuaikan tampilan form Anda dengan berbagai pilihan tema profesional.',
    },
    {
      icon: (
        <svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <rect x="2" y="3" width="20" height="14" rx="2" />
          <path d="M8 21h8M12 17v4" />
        </svg>
      ),
      title: 'Multi-Platform',
      desc: 'Akses dan isi form dari browser web atau perangkat seluler dengan mudah.',
    },
    {
      icon: (
        <svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path d="M21.5 2v6h-6M2.5 22v-6h6M2 11.5a10 10 0 0 1 18.8-4.3M22 12.5a10 10 0 0 1-18.8 4.2" />
        </svg>
      ),
      title: 'Sinkronisasi Otomatis',
      desc: 'Data respons langsung tersinkronisasi ke spreadsheet secara real-time.',
    },
    {
      icon: (
        <svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z" />
        </svg>
      ),
      title: 'Cepat & Andal',
      desc: 'Infrastruktur yang dibangun untuk kecepatan dan keandalan maksimal tanpa waktu henti.',
    },
    {
      icon: (
        <svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <circle cx="12" cy="12" r="10" />
          <polyline points="12 6 12 12 16 14" />
        </svg>
      ),
      title: 'Timer Real-time',
      desc: 'Batasi waktu pengerjaan form dengan timer akurat, cocok untuk ujian atau kuis online.',
    },
    {
      icon: (
        <svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <circle cx="12" cy="12" r="10" />
          <line x1="2" y1="12" x2="22" y2="12" />
          <path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" />
        </svg>
      ),
      title: 'Gratis & Terbuka',
      desc: 'Nikmati fitur dasar secara gratis dan kembangkan form tanpa batasan rutin.',
    },
  ];

  return (
    <div className="hp-root">
      {/* ── NAVBAR ── */}
      <header className="hp-header">
        <div className="hp-header-inner">
          <Link to="/" className="hp-brand">
            <img src={logoForm4x} alt="Form4x Logo" className="hp-brand-logo" />
            <span className="hp-brand-text">Form4x</span>
          </Link>
          <nav className="hp-nav">
            <Link to="/" className="hp-nav-link hp-nav-active">Beranda</Link>
            <Link to="/tentang" className="hp-nav-link">Tentang</Link>
            <Link to="/cara-pakai" className="hp-nav-link">Cara Pakai</Link>
          </nav>
          <div className="hp-header-actions">
            <Link to="/auth" className="hp-btn-login">Login</Link>
            <Link to="/auth" className="hp-btn-register">Daftar</Link>
          </div>
        </div>
      </header>

      {/* ── HERO ── */}
      <section id="beranda" className="hp-hero">
        <div className="hp-hero-inner">
          <h1 className="hp-hero-title">
            Buat Form Anda <span className="hp-hero-accent">dengan Mudah</span>
          </h1>
          <p className="hp-hero-sub">
            Tingkatkan produktivitas dengan platform pembuatan form profesional.
            Dilengkapi dengan timer terintegrasi, pembuatan kode QR instan, dan
            sinkronisasi otomatis ke spreadsheet.
          </p>
          <div className="hp-hero-actions">
            <Link to="/auth" id="btn-daftar-gratis" className="hp-btn-primary">
              Daftar Gratis
            </Link>
            <Link to="/tentang" className="hp-btn-outline">
              Pelajari Lebih Lanjut
            </Link>
          </div>

          {/* App Preview Mockup Container */}
          <div className="hp-mockup-wrap">
            <div className="hp-mockup-bar">
              <div className="hp-mockup-dots">
                <span className="hp-dot red" />
                <span className="hp-dot yellow" />
                <span className="hp-dot green" />
              </div>
              <div className="hp-mockup-address">https://form4x.app/dashboard</div>
            </div>
            <img
              src="/images/Dashboard.png"
              alt="Form4x Dashboard Preview"
              className="hp-mockup-img"
            />
          </div>
        </div>
      </section>

      {/* ── FEATURES ── */}
      <section id="fitur" className="hp-features">
        <div className="hp-section-inner">
          <div className="hp-section-header">
            <span className="hp-section-tag">KEUNGGULAN UTAMA</span>
            <h2 className="hp-section-title">Fitur Canggih</h2>
            <p className="hp-section-desc">
              Didesain khusus untuk memenuhi kebutuhan survei, ujian online, pendaftaran event, dan pengumpulan data secara real-time.
            </p>
          </div>
          <div className="hp-feat-grid">
            {features.map((f, i) => (
              <FeatureCard key={i} {...f} />
            ))}
          </div>
        </div>
      </section>

      {/* ── PLATFORMS ── */}
      <section id="tentang" className="hp-platforms">
        <div className="hp-section-inner">
          <div className="hp-section-header">
            <span className="hp-section-tag">LINTAS PERANGKAT</span>
            <h2 className="hp-section-title">Tersedia Di Mana Saja</h2>
            <p className="hp-section-desc">
              Akses borang dan kelola respons Anda kapan saja dari perangkat apa pun.
            </p>
          </div>
          <div className="hp-platform-row">
            <div className="hp-platform-card">
              <div className="hp-platform-icon">
                <svg width="32" height="32" fill="none" viewBox="0 0 24 24" stroke="#2563eb" strokeWidth={1.8}>
                  <circle cx="12" cy="12" r="10" />
                  <line x1="2" y1="12" x2="22" y2="12" />
                  <path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" />
                </svg>
              </div>
              <h3 className="hp-platform-name">Web Browser</h3>
              <p className="hp-platform-desc">Akses langsung dari semua browser tanpa perlu instalasi aplikasi tambahan.</p>
              <span className="hp-platform-badge hp-badge-outline-blue">Instant Access</span>
            </div>
            <div className="hp-platform-card">
              <div className="hp-platform-icon">
                <svg width="32" height="32" fill="none" viewBox="0 0 24 24" stroke="#2563eb" strokeWidth={1.8}>
                  <rect x="5" y="2" width="14" height="20" rx="2" />
                  <line x1="12" y1="18" x2="12.01" y2="18" />
                </svg>
              </div>
              <h3 className="hp-platform-name">Android & Mobile</h3>
              <p className="hp-platform-desc">Pengalaman pengisian form yang cepat, nyaman, dan responsif pada smartphone.</p>
              <span className="hp-platform-badge hp-badge-outline-blue">Mobile Friendly</span>
            </div>
          </div>
        </div>
      </section>

      {/* ── CTA ── */}
      <section id="cara-pakai" className="hp-cta">
        <div className="hp-cta-inner">
          <h2 className="hp-cta-title">Siap Memulai Form Pertama Anda?</h2>
          <p className="hp-cta-sub">
            Bergabunglah sekarang dan rasakan kemudahan membuat form & ujian interaktif secara gratis.
          </p>
          <Link to="/auth" id="btn-cta-daftar" className="hp-btn-cta">
            Daftar Sekarang - Gratis
          </Link>
        </div>
      </section>

      {/* ── FOOTER ── */}
      <footer className="hp-footer">
        <div className="hp-footer-inner">
          <div className="hp-footer-top">
            <div className="hp-footer-brand-wrap">
              <span className="hp-footer-brand">Form4x</span>
              <p className="hp-footer-tagline">Tempat membuat Form Terlengkap & Terpercaya.</p>
            </div>
            <div className="hp-footer-links">
              <Link to="/">Beranda</Link>
              <Link to="/tentang">Tentang</Link>
              <Link to="/cara-pakai">Cara Pakai</Link>
              <Link to="/auth">Login</Link>
            </div>
          </div>
          <div className="hp-footer-divider" />
          <p className="hp-footer-copy">© 2026 Form4x. All rights reserved.</p>
        </div>
      </footer>
    </div>
  );
};

export default HomePage;