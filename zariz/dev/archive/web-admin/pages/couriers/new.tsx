import * as React from 'react'
import { withAuth } from '../../libs/withAuth'
import { Box, Typography } from '@mui/material'
import CourierForm from '../../components/forms/CourierForm'
import { createCourier, type CourierDTO } from '../../libs/api'
import { useRouter } from 'next/router'

function NewCourierPage() {
  const router = useRouter()
  const [value, setValue] = React.useState<CourierDTO>({ name: '', status: 'active', capacity_boxes: 8 })
  const [pending, setPending] = React.useState(false)
  const [error, setError] = React.useState<string|null>(null)

  async function submit() {
    setPending(true); setError(null)
    try {
      const r = await createCourier(value)
      router.replace(`/couriers/${r.id}`)
    } catch {
      setError('Failed to create courier')
    } finally { setPending(false) }
  }

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h5" gutterBottom>New Courier</Typography>
      {error && <Typography color="error" variant="body2">{error}</Typography>}
      <CourierForm value={value} onChange={setValue} onSubmit={submit} pending={pending} />
    </Box>
  )
}

export default withAuth(NewCourierPage)

