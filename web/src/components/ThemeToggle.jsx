import { useRef } from 'react';
import { useTheme } from '../hooks/useTheme';

export default function ThemeToggle({ className = '', size = 'default', title }) {
  const { theme, toggle } = useTheme();
  const isDark = theme === 'dark';
  const variantClass = size === 'sm' ? 'theme-toggle--sm' : size === 'sidebar' ? 'theme-toggle--sidebar' : '';
  const animatingRef = useRef(false);

  const triggerRipple = () => {
    if (animatingRef.current) return;
    // hormati preferensi reduce motion
    const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (prefersReduced) {
      toggle();
      return;
    }
    animatingRef.current = true;
    const targetIsDark = !isDark;

    const ripple = document.createElement('div');
    ripple.className = 'theme-ripple';
    // warna tetesan = warna bg target — radial halus, tapi ringan (tanpa 1200px blur berat)
    ripple.style.background = targetIsDark
      ? 'radial-gradient(circle at 100% 0%, #2a2a4e 0%, #1a1a2e 58%)'
      : 'radial-gradient(circle at 100% 0%, #ffffff 0%, #e8eef6 62%)';
    document.body.appendChild(ripple);
    // force reflow + double rAF biar transisi GPU ke-trigger tanpa jank
    void ripple.offsetWidth;
    requestAnimationFrame(() => {
      requestAnimationFrame(() => ripple.classList.add('expand'));
    });

    // ganti tema di tengah animasi (ketika layar udah ketutup ~65% — biar tidak keliatan flash)
    const toggleDelay = 280;
    const totalDuration = 650;
    setTimeout(() => toggle(), toggleDelay);

    const cleanup = () => {
      // fade tipis saja, jangan transisi clip-path lagi biar ringan
      ripple.style.transition = 'opacity 0.28s ease';
      ripple.style.opacity = '0';
      setTimeout(() => {
        ripple.remove();
        animatingRef.current = false;
      }, 300);
    };
    // setelah expand selesai (650ms + buffer)
    setTimeout(cleanup, totalDuration + 40);
  };

  return (
    <button
      type="button"
      aria-label={isDark ? 'Ganti ke light mode' : 'Ganti ke dark mode'}
      title={title || (isDark ? 'Light mode' : 'Dark mode')}
      onClick={triggerRipple}
      className={`theme-toggle ${variantClass} ${className}`.trim()}
    >
      {isDark ? (
        // Sun icon — light mode
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <circle cx="12" cy="12" r="4" />
          <path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41" />
        </svg>
      ) : (
        // Moon icon — dark mode
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
        </svg>
      )}
    </button>
  );
}
