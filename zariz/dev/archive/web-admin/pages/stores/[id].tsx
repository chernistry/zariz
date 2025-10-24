import * as React from 'react'
import { withAuth } from '../../libs/withAuth'
import { Box, Button, Typography } from '@mui/material'
import StoreForm from '../../components/forms/StoreForm'
import CredentialsBlock, { type Creds } from '../../components/forms/CredentialsBlock'
import { useRouter } from 'next/router'
import { getStore, updateStore, type StoreDTO, changeStoreCredentials } from '../../libs/api'

function StoreDetailPage() {
  const router = useRouter()
  const id = Number(router.query.id)
  const [value, setValue] = React.useState<StoreDTO>({ name: '' })
  const [creds, setCreds] = React.useState<Creds>({})
  const [loading, setLoading] = React.useState(true)
  const [pending, setPending] = React.useState(false)
  const [message, setMessage] = React.useState<string|undefined>()
  const [error, setError] = React.useState<string|undefined>()

  React.useEffect(() => {
    if (!id) return
    setLoading(true)
    getStore(id).then((s) => {
      setValue({ name: s.name })
    }).catch(()=>setError('Failed to load')).finally(()=>setLoading(false))
  }, [id])

  async function save() {
    if (!id) return
    setPending(true); setError(undefined); setMessage(undefined)
    try { await updateStore(id, value); setMessage('Saved') } catch { setError('Failed to save') } finally { setPending(false) }
  }

  async function saveCreds() {
    if (!id) return
    setPending(true); setError(undefined); setMessage(undefined)
    try { await changeStoreCredentials(id, { email: creds.email ?? null, phone: creds.phone ?? null, password: creds.password })
      setMessage('Credentials updated')
    } catch { setError('Failed to update credentials') } finally { setPending(false) }
  }

  if (loading) return <Box sx={{ p:3 }}><Typography>Loading…</Typography></Box>

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h5" gutterBottom>Store #{id}</Typography>
      {message && <Typography color="success.main" variant="body2">{message}</Typography>}
      {error && <Typography color="error" variant="body2">{error}</Typography>}
      <StoreForm value={value} onChange={setValue} onSubmit={save} pending={pending} />
      <CredentialsBlock value={creds} onChange={setCreds} onSubmit={saveCreds} pending={pending} />
      <Button sx={{ mt: 2 }} onClick={()=>router.push('/stores')}>Back</Button>
    </Box>
  )
}

export default withAuth(StoreDetailPage)

