import * as React from 'react';
import { withAuth } from '../../libs/withAuth';
import { Box, Button, Paper, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Typography } from '@mui/material';

// Backend for users CRUD not yet implemented; this screen is a placeholder.

function Users() {
  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display:'flex', alignItems:'center', justifyContent:'space-between', mb: 2 }}>
        <Typography variant="h5">Users</Typography>
        <Button variant="contained" href="/users/new">New User</Button>
      </Box>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Users management is pending backend `/v1/users` API. This page will render once the backend lands.
      </Typography>
      <TableContainer component={Paper}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>ID</TableCell>
              <TableCell>Name</TableCell>
              <TableCell>Role</TableCell>
              <TableCell>Store</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            <TableRow>
              <TableCell colSpan={4} align="center">Pending backend</TableCell>
            </TableRow>
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  );
}

export default withAuth(Users);

