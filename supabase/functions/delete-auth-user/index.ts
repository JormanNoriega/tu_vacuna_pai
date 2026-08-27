import { createClient } from 'jsr:@supabase/supabase-js@2'

// Edge Function: delete-auth-user
//
// Elimina un usuario de auth.users (compensacion) usando el Admin API
// (service role). El service role JAMAS llega al cliente.
//
// Autorizacion: igual que create-auth-user, verifica en DB que el JWT del
// llamador corresponda a un usuario ACTIVE con INSTITUTION_WRITE o
// USER_MANAGE, via RPC public.is_permission_granted (las tablas de negocio
// viven en app, esquema NO expuesto a PostgREST por seguridad).

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'DELETE, OPTIONS',
}

const ALLOWED_PERMISSIONS = ['INSTITUTION_WRITE', 'USER_MANAGE']

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'DELETE') {
    return json({ error: 'METHOD_NOT_ALLOWED', message: 'Metodo no permitido.' }, 405)
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return json({ error: 'UNAUTHORIZED', message: 'Token de acceso ausente.' }, 401)
  }
  const accessToken = authHeader.slice('Bearer '.length)

  const userClient = createClient(supabaseUrl, serviceRoleKey, {
    global: { headers: { Authorization: `Bearer ${accessToken}` } },
    auth: { autoRefreshToken: false, persistSession: false },
  })

  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser(accessToken)
  if (userError || !user) {
    return json({ error: 'UNAUTHORIZED', message: 'Token de acceso invalido o expirado.' }, 401)
  }

  const authz = await authorizeProvisioning(userClient, user.id)
  if (authz.error) {
    return authz.error
  }

  // Extraer el id del path: /delete-auth-user/{id}
  const url = new URL(req.url)
  const segments = url.pathname.split('/').filter(Boolean)
  const id = segments[segments.length - 1]
  if (!id || !/^[0-9a-fA-F-]{36}$/.test(id)) {
    return json({ error: 'BAD_REQUEST', message: 'Id de usuario invalido.' }, 400)
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
  const { error: deleteError } = await adminClient.auth.admin.deleteUser(id)
  if (deleteError) {
    // Idempotencia: si el usuario ya no existe, la compensacion fue exitosa.
    const notFound = deleteError.status === 404 ||
      (deleteError.message ?? '').toLowerCase().includes('not found')
    if (notFound) {
      return json({ id }, 200)
    }
    console.error('delete-auth-user: error eliminando usuario', deleteError.message)
    return json({ error: 'INTERNAL', message: 'No se pudo eliminar el usuario.' }, 500)
  }

  return json({ id }, 200)
})

// Verifica que el usuario este ACTIVE en app.users y tenga alguno de los
// permisos de aprovisionamiento, via RPC (SECURITY DEFINER en public).
async function authorizeProvisioning(
  client: ReturnType<typeof createClient>,
  userId: string,
): Promise<{ error: Response | null }> {
  try {
    for (const permission of ALLOWED_PERMISSIONS) {
      const { data, error } = await client.rpc('is_permission_granted', {
        uid: userId,
        permission_code: permission,
      })
      if (error) {
        console.error('delete-auth-user: error de autorizacion', error)
        return {
          error: json(
            { error: 'INTERNAL', message: 'Error al verificar autorizacion.' },
            500,
          ),
        }
      }
      if (data === true) {
        return { error: null }
      }
    }
    return { error: json({ error: 'FORBIDDEN', message: 'No tienes permiso para eliminar usuarios.' }, 403) }
  } catch (e) {
    console.error('delete-auth-user: error de autorizacion', e)
    return { error: json({ error: 'INTERNAL', message: 'Error al verificar autorizacion.' }, 500) }
  }
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  })
}