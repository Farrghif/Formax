import { useEffect, useState, useCallback } from 'react';

const STORAGE_KEY = 'theme'; // 'light' | 'dark'

function getSystemPref() {
  if (typeof window === 'undefined') return 'light';
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function getInitialTheme() {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored === 'light' || stored === 'dark') return stored;
  } catch {
    // ignore storage access error
  }
  return getSystemPref();
}

export function useTheme() {
  const [theme, setTheme] = useState(getInitialTheme);

  // Apply to <html> + persist
  useEffect(() => {
    const root = document.documentElement;
    root.setAttribute('data-theme', theme);
    // juga set color-scheme biar scrollbar & form control ikut
    root.style.colorScheme = theme;
    try {
      localStorage.setItem(STORAGE_KEY, theme);
    } catch {
      // ignore
    }
  }, [theme]);

  // Kalau user BELUM pernah pilih manual, ikuti perubahan OS
  useEffect(() => {
    const media = window.matchMedia('(prefers-color-scheme: dark)');
    const handler = (e) => {
      try {
        const stored = localStorage.getItem(STORAGE_KEY);
        if (stored === 'light' || stored === 'dark') return; // sudah manual -> jangan auto
      } catch {
        // ignore
      }
      setTheme(e.matches ? 'dark' : 'light');
    };
    // Safari <14 pakai addListener
    if (media.addEventListener) media.addEventListener('change', handler);
    else media.addListener(handler);
    return () => {
      if (media.removeEventListener) media.removeEventListener('change', handler);
      else media.removeListener(handler);
    };
  }, []);

  const toggle = useCallback(() => {
    setTheme((prev) => (prev === 'dark' ? 'light' : 'dark'));
  }, []);

  return { theme, setTheme, toggle, isDark: theme === 'dark' };
}
