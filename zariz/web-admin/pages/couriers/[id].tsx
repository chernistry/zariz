import * as React from 'react'
import { withAuth } from '../../libs/withAuth'
import { Box, Button, Typography } from '@mui/material'
import CourierForm from '../../components/forms/CourierForm'
import CredentialsBlock, { type Creds } from '../../components/forms/CredentialsBlock'
import { useRouter } from 'next/router'
import { getCourier, updateCourier, type CourierDTO, changeCourierCredentials } from '../../libs/api'

function CourierDetailPage() {
  const router = useRouter()
  const id = Number(router.query.id)
  const [value, setValue] = React.useState<CourierDTO>({ name: '', status: 'active' })
  const [creds, setCreds] = React.useState<Creds>({})
  const [loading, setLoading] = React.useState(true)
  const [pending, setPending] = React.useState(false)
  const [message, setMessage] = React.useState<string|undefined>()
  const [error, setError] = React.useState<string|undefined>()

  React.useEffect(() => {
    if (!id) return
    setLoading(true)
    getCourier(id).then((c) => {
      setValue({ name: c.name })
    }).catch(()=>setError('Failed to load')).finally(()=>setLoading(false))
  }, [id])

  async function save() {
    if (!id) return
    setPending(true); setError(undefined); setMessage(undefined)
    try { await updateCourier(id, value); setMessage('Saved') } catch { setError('Failed to save') } finally { setPending(false) }
  }

  async function saveCreds() {
    if (!id) return
    setPending(true); setError(undefined); setMessage(undefined)
    try { await changeCourierCredentials(id, { email: creds.email, phone: creds.phone, password: creds.password })
      setMessage('Credentials updated')
    } catch { setError('Failed to update credentials') } finally { setPending(false) }
  }

  if (loading) return <Box sx={{ p:3 }}><Typography>Loading…</Typography></Box>

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h5" gutterBottom>Courier #{id}</Typography>
      {message && <Typography color="success.main" variant="body2">{message}</Typography>}
      {error && <Typography color="error" variant="body2">{error}</Typography>}
      <CourierForm value={value} onChange={setValue} onSubmit={save} pending={pending} />
      <CredentialsBlock value={creds} onChange={setCreds} onSubmit={saveCreds} pending={pending} />
      <Button sx={{ mt: 2 }} onClick={()=>router.push('/couriers')}>Back</Button>
    </Box>
  )
}

export default withAuth(CourierDetailPage)

