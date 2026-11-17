import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, x-client-info, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (request.method !== 'POST') return json({ error: 'Method not allowed.' }, 405)

  const authorization = request.headers.get('Authorization')
  const token = authorization?.replace(/^Bearer\s+/i, '').trim()
  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!token || !supabaseUrl || !serviceRoleKey) {
    return json({ error: 'Authentication is required.' }, 401)
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  const { data: authData, error: authError } = await admin.auth.getUser(token)
  const caller = authData.user
  if (authError || !caller) return json({ error: 'Authentication is required.' }, 401)

  const { data: callerProfile, error: profileError } = await admin
    .from('profiles')
    .select('role')
    .eq('id', caller.id)
    .maybeSingle()

  if (profileError || !callerProfile) {
    return json({ error: 'Profile not found.' }, 403)
  }

  const isAdmin = callerProfile.role === 'admin'

  let body: Record<string, unknown>
  try {
    body = await request.json()
  } catch {
    return json({ error: 'Invalid request body.' }, 400)
  }

  const action = body.action
  const userId = typeof body.userId === 'string' ? body.userId.trim() : ''
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(userId)) {
    return json({ error: 'A valid user ID is required.' }, 400)
  }

  if (action === 'delete') {
    if (!isAdmin && userId !== caller.id) {
      return json(
        { error: 'You can only delete your own account.' },
        403
      )
    }
    const { data: target, error: targetError } = await admin.auth.admin.getUserById(userId)
    if (targetError || !target.user) return json({ error: 'User not found.' }, 404)

    const { error } = await admin.auth.admin.deleteUser(userId)
    if (error) return json({ error: 'Could not delete this user.' }, 500)
    return json({ ok: true })
  }

  if (action !== 'update') return json({ error: 'Unsupported action.' }, 400)

  const displayName = typeof body.displayName === 'string' ? body.displayName.trim() : ''
  const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : ''
  if (displayName.length < 2 || displayName.length > 80) {
    return json({ error: 'Name must be between 2 and 80 characters.' }, 400)
  }
  if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return json({ error: 'Enter a valid email address.' }, 400)
  }

  const { data: target, error: targetError } = await admin.auth.admin.getUserById(userId)
  if (targetError || !target.user) return json({ error: 'User not found.' }, 404)

  const previousEmail = target.user.email ?? ''
  const previousMetadata = target.user.user_metadata ?? {}
  const { error: authUpdateError } = await admin.auth.admin.updateUserById(userId, {
    email,
    email_confirm: true,
    user_metadata: { ...previousMetadata, display_name: displayName },
  })
  if (authUpdateError) return json({ error: 'Could not update the user account.' }, 400)

  const { data: updatedProfile, error: profileUpdateError } = await admin
    .from('profiles')
    .update({ email, display_name: displayName, updated_at: new Date().toISOString() })
    .eq('id', userId)
    .select('id')
    .maybeSingle()
  if (profileUpdateError || !updatedProfile) {
    const { error: rollbackError } = await admin.auth.admin.updateUserById(userId, {
      email: previousEmail,
      email_confirm: true,
      user_metadata: previousMetadata,
    })
    return json({
      error: rollbackError
        ? 'The profile update was incomplete. Contact an administrator before retrying.'
        : 'Could not save the user profile. No changes were kept.',
    }, 500)
  }

  return json({ ok: true })
})
