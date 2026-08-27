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
  // Perfil ampliado del personal de salud. Spring lo envia ya normalizado
  // (documento canonico). Vive en user_metadata para trazabilidad; la fuente
  // de verdad de negocio es app.users.
  documentType?: string
  documentNumber?: string
  phone?: string
  birthDate?: string
  gender?: string
  professionCode?: string
  professionalRegistrationNumber?: string
  professionalRegistrationType?: string
  // Idempotencia: el mismo operationId se reenvia en reintentos. Se escribe en
  // app_metadata DENTRO de la misma llamada admin.createUser para que, aunque
  // la respuesta HTTP se pierda, la correlacion ya exista en auth.users.
  operationId?: string
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
  const operationId = (body.operationId ?? '').trim()

  if (!email || !password) {
    return json({ error: 'BAD_REQUEST', message: 'Email y contrasena son obligatorios.' }, 400)
  }
  if (password.length < 8) {
    return json(
      { error: 'BAD_REQUEST', message: 'La contrasena debe tener al menos 8 caracteres.' },
      400,
    )
  }
  if (!/^[0-9a-fA-F-]{36}$/.test(operationId)) {
    return json(
      { error: 'BAD_REQUEST', message: 'operationId invalido: se espera un UUID.' },
      400,
    )
  }

  // 5. Crear el usuario en auth.users con el Admin API (service role).
  //    La contrasena viaja solo hasta aqui y no se devuelve ni se persiste fuera.
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  const userMetadata: Record<string, string> = {}
  if (fullName) userMetadata.full_name = fullName
  if (body.documentType) userMetadata.document_type = body.documentType
  if (body.documentNumber) userMetadata.document_number = body.documentNumber
  if (body.phone) userMetadata.phone = body.phone
  if (body.birthDate) userMetadata.birth_date = body.birthDate
  if (body.gender) userMetadata.gender = body.gender
  if (body.professionCode) userMetadata.profession_code = body.professionCode
  if (body.professionalRegistrationNumber) {
    userMetadata.professional_registration_number = body.professionalRegistrationNumber
  }
  if (body.professionalRegistrationType) {
    userMetadata.professional_registration_type = body.professionalRegistrationType
  }

  const { data: created, error: createError } = await adminClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: Object.keys(userMetadata).length > 0 ? userMetadata : undefined,
    app_metadata: { provisioning_operation_id: operationId },
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