import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import AuthPage from './pages/AuthPage';
import DashboardPage from './pages/DashboardPage';
import FormBuilderPage from './pages/FormBuilderPage';

function PrivateRoute({ children }) {
  const token = localStorage.getItem('token');
  return token ? children : <Navigate to="/auth" replace />;
}

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Navigate to="/auth" replace />} />
        <Route path="/auth" element={<AuthPage />} />
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
        {/* Fallback */}
        <Route path="*" element={<Navigate to="/auth" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
