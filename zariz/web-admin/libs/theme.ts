import { createTheme } from '@mui/material/styles';

export const theme = createTheme({
  palette: {
    mode: 'light',
    primary: { main: '#1976d2' },
    secondary: { main: '#556cd6' },
    background: { default: '#f7f9fc' },
  },
  shape: { borderRadius: 8 },
});

