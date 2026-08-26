import { BrowserRouter, Routes, Route, Navigate, useLocation } from 'react-router-dom';
import HomePage from './pages/HomePage';
import TentangPage from './pages/TentangPage';
import CaraPakaiPage from './pages/CaraPakaiPage';
import AuthPage from './pages/AuthPage';
import DashboardPage from './pages/DashboardPage';
import FormBuilderPage from './pages/FormBuilderPage';
import FormFillPage from './pages/FormFillPage';
import ProfilePage from './pages/ProfilePage';

function PrivateRoute({ children }) {
  const token = localStorage.getItem('token');
  const location = useLocation();

  if (!token) {
    const redirectUrl = encodeURIComponent(location.pathname + location.search);
    return <Navigate to={`/auth?redirect=${redirectUrl}`} replace />;
  }

  return children;
}

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route path="/tentang" element={<TentangPage />} />
        <Route path="/cara-pakai" element={<CaraPakaiPage />} />
        <Route path="/auth" element={<AuthPage />} />
        <Route
          path="/profile"
          element={
            <PrivateRoute>
              <ProfilePage />
            </PrivateRoute>
          }
        />
        <Route
          path="/dashboard"
          element={
            <PrivateRoute>
              <DashboardPage />
            </PrivateRoute>
          }
        />
        <Route
          path="/form-builder"
          element={
            <PrivateRoute>
              <FormBuilderPage />
            </PrivateRoute>
          }
        />
        <Route
          path="/form-builder/:formId"
          element={
            <PrivateRoute>
              <FormBuilderPage />
            </PrivateRoute>
          }
        />
        {/* Public Form Filler Routes */}
        <Route
          path="/f/:slug"
          element={
            <PrivateRoute>
              <FormFillPage />
            </PrivateRoute>
          }
        />
        <Route
          path="/forms/public/:slug"
          element={
            <PrivateRoute>
              <FormFillPage />
            </PrivateRoute>
          }
        />
        {/* Fallback */}
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
