import { Link } from 'react-router-dom'
import '../styles/landing.css'
import logoForm4x from '../assets/logo_form4x.png';
import ThemeToggle from '../components/ThemeToggle';
import InteractiveCubeBackground from '../components/InteractiveCubeBackground';

/* ─── Shared Navbar ─── */
function LandingNav({ active = 'beranda' }) {
  return (
    <header className="hp-header">
      <div className="hp-header-inner">
        <div className="hp-brand">
          <Link to="/" className="hp-brand">
            <img src={logoForm4x} alt="Form4x Logo" className="hp-brand-logo" />
            <span className="hp-brand-text">Form4x</span>
          </Link>
        </div>
        <nav className="hp-nav">
          <Link to="/" className={`hp-nav-link${active === 'beranda' ? ' hp-nav-active' : ''}`}>Beranda</Link>
          <Link to="/tentang" className={`hp-nav-link${active === 'tentang' ? ' hp-nav-active' : ''}`}>Tentang</Link>
          <Link to="/cara-pakai" className={`hp-nav-link${active === 'cara-pakai' ? ' hp-nav-active' : ''}`}>Cara Pakai</Link>
        </nav>
        <div className="hp-header-actions">
          <ThemeToggle />
          <Link to="/auth" className="hp-btn-login">Login</Link>
          <Link to="/auth" className="hp-btn-register">Register</Link>
        </div>
      </div>
    </header>
  )
}

/* ─── TentangPage ─── */
const TentangPage = () => {
  const features = [
    { title: 'Pembuatan Form Fleksibel', desc: 'Teks, pilihan ganda, checkbox, dropdown, tanggal, dan upload file dengan editor kaya, validasi, serta pengaturan poin.', icon: 'M9 12h6M12 8v8' },
    { title: 'Import Soal Word', desc: 'Upload file .docx, preview otomatis, dan impor puluhan soal sekaligus tanpa input manual satu per satu.', icon: 'M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z M14 2v6h6' },
    { title: 'Penilaian Otomatis', desc: 'Kunci jawaban, skor real-time, dan rekap nilai per responden dengan visualisasi distribusi jawaban.', icon: 'M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z' },
    { title: 'Keamanan & Kontrol', desc: 'Mode fullscreen wajib, deteksi keluar tab sebagai curang, batas pengisian, dan jadwal buka-tutup.', icon: 'M12 15a3 3 0 100-6 3 3 0 000 6z M19 10V9a2 2 0 00-2-2h-1V6a5 5 0 00-10 0v1H5a2 2 0 00-2 2v1' },
    { title: 'QR & Berbagi Cepat', desc: 'Generate tautan dan QR code unik per form, bagikan via link tanpa instalasi tambahan bagi responden.', icon: 'M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-2l-2-2H9L7 7H5z M8 11h8 M12 11v6' },
    { title: 'Riwayat & Analitik', desc: 'Dasbor riwayat, ekspor Excel, dan ringkasan visual per pertanyaan untuk evaluasi pembelajaran.', icon: 'M3 3v18h18 M7 16l3-3 3 3 5-5' },
  ]

  const values = [
    { title: 'Sederhana', desc: 'Antarmuka bersih dan langkah yang jelas, fokus pada isi bukan pengaturan rumit.' },
    { title: 'Andal', desc: 'Dibangun di atas FastAPI dan PostgreSQL dengan autentikasi aman dan penyimpanan terstruktur.' },
    { title: 'Inklusif', desc: 'Dapat diisi dengan atau tanpa akun, mendukung alur anonim via identitas per-browser.' },
    { title: 'Transparan', desc: 'Responden dapat melihat hasil dan kunci jawaban sesuai pengaturan pengajar.' },
  ]

  const team = [
    { name: 'Fathin Jamaluddin', role: 'Project Manager', initials: 'FJ' },
    { name: 'Gita Nur Amalia', role: 'Database Engineer', initials: 'GN' },
    { name: 'Andhika Khairul Fahmi', role: 'UI/UX Designer — Web Dev', initials: 'AK' },
    { name: 'Fajriah Salsabilla', role: 'UI/UX Designer — Web Dev', initials: 'FS' },
    { name: 'Farrel Ghifari', role: 'Android Dev', initials: 'FG' },
    { name: 'Raka Julio Same', role: 'Android Dev', initials: 'RJ' },
  ]

  return (
    <div className="hp-root" style={{ position: 'relative' }}>
      <InteractiveCubeBackground />
      <LandingNav active="tentang" />

      {/* HERO — simetris, clean */}
      <section className="tp-hero tp-hero--about">
        <div className="tp-hero-inner">
          <span className="tp-kicker">Tentang Form4x</span>
          <h1 className="tp-hero-title">Platform Pembuatan Formulir<br />yang Rapi, Cepat, dan Terukur</h1>
          <p className="tp-hero-sub">
            Form4x membantu pendidik, organisasi, dan tim menyusun formulir, kuis, serta survei yang terstruktur dengan alur yang konsisten — dari pembuatan hingga analisis hasil.
          </p>
          <div className="tp-hero-actions">
            <Link to="/auth" className="tp-btn-cta">Mulai Membuat Form</Link>
            <Link to="/cara-pakai" className="tp-btn-ghost">Pelajari Cara Pakai</Link>
          </div>
          <div className="tp-hero-stats">
            <div className="tp-stat"><strong>6+</strong><span>Jenis Pertanyaan</span></div>
            <div className="tp-stat-dot" />
            <div className="tp-stat"><strong>Import</strong><span>.docx Sekaligus</span></div>
            <div className="tp-stat-dot" />
            <div className="tp-stat"><strong>Real-time</strong><span>Skor & Rekap</span></div>
          </div>
        </div>
      </section>

      {/* TENTANG SINGKAT — simetris 2 kolom */}
      <section className="tp-about">
        <div className="tp-section-inner">
          <div className="tp-about-grid">
            <div className="tp-about-text">
              <span className="tp-section-kicker">Apa itu Form4x</span>
              <h2 className="tp-section-title">Dirancang untuk Kebutuhan Formulir yang Sesungguhnya</h2>
              <p className="tp-section-desc">
                Form4x berfokus pada kejelasan alur dan keandalan data. Anda dapat menyusun form dari kosong, menggunakan template, atau mengimpor soal dari Word, lalu membagikannya melalui tautan atau QR code tanpa langkah tambahan bagi responden.
              </p>
              <p className="tp-section-desc">
                Sistem mendukung penilaian otomatis, kontrol akses berbasis token, batas pengisian, jadwal, serta mode fullscreen untuk integritas ujian. Hasil tersaji dalam rekap yang dapat diekspor dan divisualisasikan per pertanyaan.
              </p>
              <ul className="tp-checklist">
                <li>Cocok untuk pendidikan, pelatihan, survei internal, dan pendataan</li>
                <li>Tidak memerlukan instalasi di sisi responden</li>
                <li>Data tersimpan terstruktur dan siap dianalisis</li>
              </ul>
            </div>
            <div className="tp-about-card">
              <div className="tp-about-card-inner">
                <div className="tp-about-card-head">
                  <span className="tp-about-card-dot" />
                  <span className="tp-about-card-title">Alur Form4x</span>
                </div>
                <ol className="tp-about-steps">
                  <li><strong>Susun</strong><span>Tambah pertanyaan, atur tipe, dan tetapkan kunci jawaban</span></li>
                  <li><strong>Atur</strong><span>Kelola status, jadwal, dan kontrol pengisian di Setelan</span></li>
                  <li><strong>Bagikan</strong><span>Sebarkan tautan atau QR, responden dapat mengisi tanpa akun</span></li>
                  <li><strong>Analisis</strong><span>Pantau skor, durasi, dan distribusi jawaban secara real-time</span></li>
                </ol>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* FITUR — simetris 3x2 */}
      <section className="tp-features">
        <div className="tp-section-inner">
          <div className="tp-section-header">
            <span className="tp-section-kicker">Fitur Utama</span>
            <h2 className="tp-section-title">Fungsionalitas Lengkap dalam Satu Tempat</h2>
            <p className="tp-section-desc">Setiap fitur disusun agar saling melengkapi, tanpa elemen berlebihan.</p>
          </div>
          <div className="tp-features-grid">
            {features.map((f, i) => (
              <div key={i} className="tp-feature-card">
                <div className="tp-feature-icon">
                  <svg width="22" height="22" fill="none" viewBox="0 0 24 24" stroke="#0B76D4" strokeWidth={1.9}><path strokeLinecap="round" strokeLinejoin="round" d={f.icon} /></svg>
                </div>
                <h3 className="tp-feature-title">{f.title}</h3>
                <p className="tp-feature-desc">{f.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* NILAI — simetris 4 kolom */}
      <section className="tp-values">
        <div className="tp-section-inner">
          <div className="tp-values-grid">
            {values.map((v, i) => (
              <div key={i} className="tp-value-card">
                <h3 className="tp-value-title">{v.title}</h3>
                <p className="tp-value-desc">{v.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* TIM PENGEMBANG — simetris 3x2, clean */}
      <section className="tp-team">
        <div className="tp-section-inner">
          <div className="tp-section-header">
            <span className="tp-section-kicker">Tim Pengembang</span>
            <h2 className="tp-section-title">Dikembangkan oleh Tim Form4x</h2>
            <p className="tp-section-desc">Setiap peran berkontribusi pada keseluruhan pengalaman aplikasi.</p>
          </div>
          <div className="tp-team-grid">
            {team.map((m, i) => (
              <div key={i} className="tp-team-card">
                <div className="tp-team-avatar">{m.initials}</div>
                <h3 className="tp-team-name">{m.name}</h3>
                <p className="tp-team-role">{m.role}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA — simetris */}
      <section className="tp-cta">
        <div className="tp-cta-inner">
          <h2 className="tp-cta-title">Siap Membuat Formulir Pertama Anda?</h2>
          <p className="tp-cta-sub">Mulai dari template atau impor Word, bagikan dalam hitungan menit.</p>
          <Link to="/auth" className="tp-btn-cta">Buat Form Sekarang</Link>
        </div>
      </section>

      <footer className="hp-footer">
        <div className="hp-footer-inner">
          <div className="hp-footer-brand">Form4x</div>
          <p className="hp-footer-copy">© 2026 Form4x. All rights reserved.</p>
        </div>
      </footer>
    </div>
  )
}

export default TentangPage
