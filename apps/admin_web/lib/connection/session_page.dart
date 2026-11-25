import 'package:flutter/material.dart';

import 'admin_session.dart';
import '../dashboard/admin_dashboard.dart';
import '../users/app_colors.dart';

class SessionPage extends StatefulWidget {
  const SessionPage({required this.session, super.key});
  final AdminSession session;
  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscurePassword = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) => widget.session.name != null
        ? AdminDashboard(session: widget.session)
        : Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                      child: Card(
                        elevation: 0,
                        color: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: ListenableBuilder(
                      listenable: widget.session,
                      builder: (context, _) {
                        final session = widget.session;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Row(children: [
                              Icon(Icons.vaccines_rounded, color: AppColors.primary, size: 32),
                              SizedBox(width: 10),
                              Text('Tu Vacuna PAI', style: TextStyle(
                                color: AppColors.ink, fontSize: 20,
                                fontWeight: FontWeight.bold)),
                            ]),
                            const SizedBox(height: 24),
                            Text(
                              session.name == null
                                  ? 'Bienvenido de nuevo'
                                  : 'Acceso validado',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 12),
                            if (session.name == null) ...[
                              const Text(
                                'Accede para continuar con tu jornada de vacunación.',
                              ),
                              const SizedBox(height: 24),
                              TextField(
                                controller: email,
                                enabled: !session.busy,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.username],
                                decoration: const InputDecoration(
                                  labelText: 'Correo institucional',
                                  prefixIcon: Icon(Icons.alternate_email_rounded),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: password,
                                enabled: !session.busy,
                                obscureText: obscurePassword,
                                autofillHints: const [AutofillHints.password],
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    tooltip: obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                                    onPressed: () => setState(() => obscurePassword = !obscurePassword),
                                    icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => _signIn(),
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: session.busy ? null : _signIn,
                                child: Text(
                                  session.busy ? 'Validando…' : 'Ingresar',
                                ),
                              ),
                            ] else ...[
                              Text(
                                'Hola, ${session.name}. La sesión fue validada en línea.',
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Los módulos administrativos aún no están disponibles.',
                              ),
                              const SizedBox(height: 24),
                              OutlinedButton(
                                onPressed: session.busy
                                    ? null
                                    : () => session.signOut(),
                                child: const Text('Cerrar sesión'),
                              ),
                            ],
                            if (session.error != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                session.error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                          ),
                        ),
                      ),
                  ),
                ),
              ),
            ),
          ),
  );

  Future<void> _signIn() async {
    final secret = password.text;
    password.clear();
    await widget.session.signIn(email.text, secret);
  }
}
