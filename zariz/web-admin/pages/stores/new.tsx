import * as React from 'react'
import { withAuth } from '../../libs/withAuth'
import { Box, Typography } from '@mui/material'
import StoreForm from '../../components/forms/StoreForm'
import { createStore, type StoreDTO } from '../../libs/api'
import { useRouter } from 'next/router'

function NewStorePage() {
  const router = useRouter()
  const [value, setValue] = React.useState<StoreDTO>({ name: '', status: 'active' })
  const [pending, setPending] = React.useState(false)
  const [error, setError] = React.useState<string|null>(null)

  async function submit() {
    setPending(true); setError(null)
    try {
      const r = await createStore(value)
      router.replace(`/stores/${r.id}`)
    } catch (e:any) {
      setError('Failed to create store')
    } finally { setPending(false) }
  }

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h5" gutterBottom>New Store</Typography>
      {error && <Typography color="error" variant="body2">{error}</Typography>}
      <StoreForm value={value} onChange={setValue} onSubmit={submit} pending={pending} />
    </Box>
  )
}

export default withAuth(NewStorePage)

