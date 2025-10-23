import '../styles/globals.css'
import type { AppProps } from 'next/app'
import { useRouter } from 'next/router'
import { ThemeProvider } from '@mui/material/styles'
import { CssBaseline } from '@mui/material'
import { theme } from '../libs/theme'
import AdminLayout from '../components/layout/AdminLayout'
import { Provider as AppContextProvider } from '../contexts/app'
import { Provider as AuthContextProvider } from '../contexts/auth'

function MyApp({ Component, pageProps }: AppProps) {
  const router = useRouter();
  const noLayout = router.pathname === '/login';
  const content = noLayout ? (
    <Component {...pageProps} />
  ) : (
    <AdminLayout>
      <Component {...pageProps} />
    </AdminLayout>
  );
  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <AuthContextProvider>
        <AppContextProvider>
          {content}
        </AppContextProvider>
      </AuthContextProvider>
    </ThemeProvider>
  );
}

export default MyApp
