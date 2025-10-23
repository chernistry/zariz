import * as React from 'react';
import { withAuth } from '../libs/withAuth';
import { CourierInfo, getCouriers } from '../libs/api';
import { Box, FormControlLabel, Paper, Switch, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Typography } from '@mui/material';

function Couriers() {
  const [rows, setRows] = React.useState<CourierInfo[]>([]);
  const [availableOnly, setAvailableOnly] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  const load = React.useCallback(async () => {
    try {
      setError(null);
      const data = await getCouriers(availableOnly);
      setRows(data);
    } catch (e) {
      setError('Failed to load couriers');
    }
  }, [availableOnly]);

  React.useEffect(() => { load(); }, [load]);

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display:'flex', alignItems:'center', justifyContent:'space-between', mb: 2 }}>
        <Typography variant="h5">Couriers</Typography>
        <FormControlLabel control={<Switch checked={availableOnly} onChange={(e)=>setAvailableOnly(e.target.checked)} />} label="Available only" />
      </Box>
      {error && <Typography color="error" variant="body2" sx={{ mb: 1 }}>{error}</Typography>}
      <TableContainer component={Paper}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>ID</TableCell>
              <TableCell>Name</TableCell>
              <TableCell align="right">Load</TableCell>
              <TableCell align="right">Capacity</TableCell>
              <TableCell align="right">Available</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {rows.map((r) => (
              <TableRow key={r.id}>
                <TableCell>#{r.id}</TableCell>
                <TableCell>{r.name}</TableCell>
                <TableCell align="right">{r.load_boxes}</TableCell>
                <TableCell align="right">{r.capacity_boxes}</TableCell>
                <TableCell align="right">{r.available_boxes}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  );
}

export default withAuth(Couriers);
