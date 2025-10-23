import * as React from 'react';
import {
  Box,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControlLabel,
  LinearProgress,
  List,
  ListItem,
  ListItemButton,
  ListItemText,
  Switch,
  Typography,
} from '@mui/material';
import { CourierInfo, getCouriers } from '../../libs/api';

export type AssignCourierDialogProps = {
  open: boolean;
  onClose: () => void;
  onSelect: (courierId: number) => void;
};

function colorForUsage(load: number, cap: number) {
  if (cap <= 0) return 'text.secondary';
  const used = load;
  if (used >= cap) return 'error.main';
  if (used >= cap - 3) return 'warning.main';
  return 'success.main';
}

export default function AssignCourierDialog({ open, onClose, onSelect }: AssignCourierDialogProps) {
  const [couriers, setCouriers] = React.useState<CourierInfo[]>([]);
  const [loading, setLoading] = React.useState(false);
  const [availableOnly, setAvailableOnly] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  const load = React.useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await getCouriers(availableOnly);
      setCouriers(data);
    } catch (e) {
      setError('Failed to load couriers');
    } finally {
      setLoading(false);
    }
  }, [availableOnly]);

  React.useEffect(() => {
    if (open) load();
  }, [open, load]);

  return (
    <Dialog open={open} onClose={onClose} fullWidth maxWidth="sm">
      <DialogTitle>Select Courier</DialogTitle>
      <DialogContent>
        <Box sx={{ display:'flex', alignItems:'center', justifyContent:'space-between', mb: 1 }}>
          <FormControlLabel
            control={<Switch checked={availableOnly} onChange={(e)=>setAvailableOnly(e.target.checked)} />}
            label="Available only"
          />
          <Button size="small" onClick={load}>Refresh</Button>
        </Box>
        {loading && <LinearProgress />}
        {error && <Typography color="error" variant="body2" sx={{ mt: 1 }}>{error}</Typography>}
        <List>
          {couriers.map(c => {
            const disabled = c.available_boxes <= 0;
            return (
              <ListItem key={c.id} disablePadding>
                <ListItemButton disabled={disabled} onClick={() => onSelect(c.id)}>
                  <ListItemText
                    primary={`#${c.id} ${c.name || `Courier ${c.id}`}`}
                    secondary={
                      <Box sx={{ display:'flex', alignItems:'center', gap: 1 }}>
                        <Box sx={{ width: 120 }}>
                          <LinearProgress
                            variant="determinate"
                            value={Math.min(100, (c.load_boxes / (c.capacity_boxes || 1)) * 100)}
                            sx={{ height: 8, borderRadius: 5 }}
                          />
                        </Box>
                        <Typography variant="body2" sx={{ color: colorForUsage(c.load_boxes, c.capacity_boxes) }}>
                          {`${c.load_boxes}/${c.capacity_boxes} used`}
                        </Typography>
                        {disabled && <Typography variant="body2" color="text.secondary">Full</Typography>}
                      </Box>
                    }
                  />
                </ListItemButton>
              </ListItem>
            );
          })}
        </List>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Close</Button>
      </DialogActions>
    </Dialog>
  );
}
