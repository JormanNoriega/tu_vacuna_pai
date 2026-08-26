import { createClient } from 'jsr:@supabase/supabase-js@2'

// Edge Function: create-auth-user
//
// Crea un usuario en auth.users usando el Admin API (service role).
// El service role JAMAS llega al cliente ni a Flutter: vive solo aqui, en el
// entorno de la Edge Function (SUPABASE_SERVICE_ROLE_KEY inyectado por Supabase).
//
// Autorizacion: con verify_jwt=true (default) la plataforma ya valido el JWT
// del usuario. Aqui ademas verificamos en DB que ese usuario este ACTIVE en
// app.users y tenga permiso INSTITUTION_WRITE (SUPER_ADMIN) o USER_MANAGE
// (ADMIN_INSTITUTION), alineado con app.users -> user_roles -> role_permissions
// -> permissions. No confiamos unicamente en claims del JWT. La consulta se
// hace via RPC (public.is_permission_granted) porque las tablas de negocio
// viven en el esquema app, que NO esta expuesto a PostgREST por seguridad.

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

// Permisos que habilitan la creacion de usuarios: INSTITUTION_WRITE cubre al
// SUPER_ADMIN y USER_MANAGE al ADMIN_INSTITUTION (scope institucional, que
// Spring ya aplico al derivar la institucion del actor).
const ALLOWED_PERMISSIONS = ['INSTITUTION_WRITE', 'USER_MANAGE']

interface CreateAuthUserRequest {
  email: string
  password: string
  fullName?: string
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return json({ error: 'METHOD_NOT_ALLOWED', message: 'Metodo no permitido.' }, 405)
  }

  // 1. Obtener el JWT del usuario autenticado.
  const authHeader = req.headers.get('Authorization')
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return json({ error: 'UNAUTHORIZED', message: 'Token de acceso ausente.' }, 401)
  }
  const accessToken = authHeader.slice('Bearer '.length)

  // 2. Cliente con el JWT del usuario para conocer su identidad (sub).
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

  // 3. Verificar en DB: usuario activo en app.users con permiso permitido.
  const authz = await authorizeProvisioning(userClient, user.id)
  if (authz.error) {
    return authz.error
  }

  // 4. Leer el payload (sin registrar la contrasena en logs).
  let body: CreateAuthUserRequest
  try {
    body = (await req.json()) as CreateAuthUserRequest
  } catch {
    return json({ error: 'BAD_REQUEST', message: 'Cuerpo JSON invalido.' }, 400)
  }

  const email = (body.email ?? '').trim().toLowerCase()
  const password = body.password ?? ''
  const fullName = (body.fullName ?? '').trim()

  if (!email || !password) {
    return json({ error: 'BAD_REQUEST', message: 'Email y contrasena son obligatorios.' }, 400)
  }
  if (password.length < 8) {
    return json(
      { error: 'BAD_REQUEST', message: 'La contrasena debe tener al menos 8 caracteres.' },
      400,
    )
  }

  // 5. Crear el usuario en auth.users con el Admin API (service role).
  //    La contrasena viaja solo hasta aqui y no se devuelve ni se persiste fuera.
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  const { data: created, error: createError } = await adminClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: fullName ? { full_name: fullName } : undefined,
  })

  if (createError) {
    if (
      createError.message?.toLowerCase().includes('already registered') ||
      createError.status === 422
    ) {
      return json(
        { error: 'EMAIL_ALREADY_EXISTS', message: 'Ya existe un usuario con ese correo.' },
        409,
      )
    }
    console.error('create-auth-user: error creando usuario', createError.message)
    return json({ error: 'INTERNAL', message: 'No se pudo crear el usuario.' }, 500)
  }

  // 6. Respuesta: solo id y email. Nunca la contrasena.
  return json({ id: created.user?.id, email: created.user?.email ?? email }, 201)
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
        console.error('create-auth-user: error de autorizacion', error)
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
    return { error: json({ error: 'FORBIDDEN', message: 'No tienes permiso para crear usuarios.' }, 403) }
  } catch (e) {
    console.error('create-auth-user: error de autorizacion', e)
    return { error: json({ error: 'INTERNAL', message: 'Error al verificar autorizacion.' }, 500) }
  }
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  })
}