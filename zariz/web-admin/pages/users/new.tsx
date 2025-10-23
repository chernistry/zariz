import * as React from 'react';
import { withAuth } from '../../libs/withAuth';
import { Box, Button, MenuItem, Paper, Stack, TextField, Typography } from '@mui/material';

function NewUser() {
  const [name, setName] = React.useState('');
  const [phone, setPhone] = React.useState('');
  const [role, setRole] = React.useState<'store' | 'courier' | 'admin'>('courier');
  const [storeId, setStoreId] = React.useState('');

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    alert('Backend /v1/users not implemented yet. This form will be wired once API exists.');
  };

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h5" sx={{ mb: 2 }}>New User</Typography>
      <Paper sx={{ p: 2, maxWidth: 480 }}>
        <form onSubmit={submit}>
          <Stack spacing={2}>
            <TextField label="Name" value={name} onChange={(e)=>setName(e.target.value)} required />
            <TextField label="Phone" value={phone} onChange={(e)=>setPhone(e.target.value)} required />
            <TextField select label="Role" value={role} onChange={(e)=>setRole(e.target.value as any)}>
              <MenuItem value="courier">Courier</MenuItem>
              <MenuItem value="store">Store</MenuItem>
              <MenuItem value="admin">Admin</MenuItem>
            </TextField>
            {role === 'store' && (
              <TextField label="Store ID" value={storeId} onChange={(e)=>setStoreId(e.target.value)} />
            )}
            <Box sx={{ display:'flex', gap: 1, justifyContent:'flex-end' }}>
              <Button variant="outlined" href="/users">Cancel</Button>
              <Button variant="contained" type="submit">Create</Button>
            </Box>
          </Stack>
        </form>
      </Paper>
    </Box>
  );
}

export default withAuth(NewUser);

