import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'vaccinator.dart';
import 'users_controller.dart';

/// Vista de escritorio (Web / Desktop) para la administración y gestión
/// de personal, vacunadores y usuarios institucionales PAI.
class AdminWebUsersView extends StatefulWidget {
  const AdminWebUsersView({
    super.key,
    required this.controller,
    required this.institutionId,
    required this.institutionName,
  });

  final UsersController controller;
  final String institutionId;
  final String institutionName;

  @override
  State<AdminWebUsersView> createState() => _AdminWebUsersViewState();
}

class _AdminWebUsersViewState extends State<AdminWebUsersView> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedRoleFilter = 'TODOS';
  String _selectedStatusFilter = 'TODOS';
  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Vaccinator> get _effectiveUsers => widget.controller.users;

  List<Vaccinator> get _filteredUsers {
    final query = _searchController.text.trim().toLowerCase();
    return _effectiveUsers.where((u) {
      // Filtro de texto
      if (query.isNotEmpty) {
        final nameMatch = u.fullName.toLowerCase().contains(query);
        final emailMatch = u.email.toLowerCase().contains(query);
        final docMatch =
            (u.documentNumber ?? '').toLowerCase().contains(query);
        final phoneMatch = (u.phone ?? '').toLowerCase().contains(query);
        if (!nameMatch && !emailMatch && !docMatch && !phoneMatch) return false;
      }

      // Filtro de Rol
      if (_selectedRoleFilter != 'TODOS') {
        if (!u.roles.contains(_selectedRoleFilter)) return false;
      }

      // Filtro de Estado
      if (_selectedStatusFilter != 'TODOS') {
        if (u.status != _selectedStatusFilter) return false;
      }

      return true;
    }).toList();
  }

  int get _totalPages {
    final count = _filteredUsers.length;
    if (count == 0) return 1;
    return (count / _pageSize).ceil();
  }

  List<Vaccinator> get _pagedUsers {
    final all = _filteredUsers;
    if (all.isEmpty) return const [];
    final page = _currentPage.clamp(1, _totalPages);
    final startIndex = (page - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, all.length);
    if (startIndex >= all.length) return const [];
    return all.sublist(startIndex, endIndex);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final allUsers = _effectiveUsers;
        final totalUsers = allUsers.length;
        final activeUsers = allUsers.where((u) => u.isActive).length;
        final nurses = allUsers
            .where((u) => u.professionCode == 'ENFERMERO')
            .length;
        final assistants = allUsers
            .where((u) => u.professionCode == 'AUXILIAR_ENFERMERIA')
            .length;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => widget.controller.loadUsers(
              institutionId: widget.institutionId,
            ),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Cabecera principal
                      _buildHeader(context),
                      const SizedBox(height: 20),
                      const Text(
                        'Consulta en línea · Los cambios de estado, creación y edición de roles están pendientes de validación.',
                        style: TextStyle(color: AppColors.slate),
                      ),
                      const SizedBox(height: 20),
                      if (widget.controller.isLoading)
                        const LinearProgressIndicator(),

                      // 2. Banner de estado / aviso si hay error
                      if (widget.controller.error != null) ...[
                        _buildErrorBanner(),
                        const SizedBox(height: 20),
                      ],

                      // 3. Fila de KPIs
                      _buildKpisRow(
                        totalUsers: totalUsers,
                        activeUsers: activeUsers,
                        nurses: nurses,
                        assistants: assistants,
                      ),
                      const SizedBox(height: 24),

                      // 4. Barra de búsqueda y filtros
                      _buildFilterAndSearchBar(),
                      const SizedBox(height: 20),

                      // 5. Tabla principal de usuarios y personal
                      _buildUsersTableCard(context),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Cabecera
  // ---------------------------------------------------------------------------
  Widget _buildHeader(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'ADMINISTRACIÓN DE PERSONAL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'PAI Colombia',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Gestión de Personal y Vacunadores',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Control institucional de habilitación, roles y credenciales operativas · ${widget.institutionName}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.slate,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botón refrescar
            OutlinedButton.icon(
              onPressed: widget.controller.isLoading
                  ? null
                  : () => widget.controller.loadUsers(
                        institutionId: widget.institutionId,
                      ),
              icon: widget.controller.isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Actualizar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.border),
                backgroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Botón registrar vacunador
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Registrar Nuevo Vacunador'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Banner de Error
  // ---------------------------------------------------------------------------
  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.controller.error!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.danger,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => widget.controller.loadUsers(
              institutionId: widget.institutionId,
            ),
            child: const Text('Reintentar'),
          ),
          IconButton(
            onPressed: widget.controller.clearError,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppColors.danger,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Fila de KPIs
  // ---------------------------------------------------------------------------
  Widget _buildKpisRow({
    required int totalUsers,
    required int activeUsers,
    required int nurses,
    required int assistants,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;
        if (isCompact) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Total Personal Registrado',
                      value: '$totalUsers',
                      subtitle: '$activeUsers activos en institución',
                      badge: '100%',
                      badgeColor: AppColors.primary,
                      icon: Icons.people_alt_rounded,
                      iconColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Vacunadores Habilitados',
                      value: '$activeUsers',
                      subtitle: 'Con permiso de aplicación',
                      badge: '${((activeUsers / (totalUsers > 0 ? totalUsers : 1)) * 100).toInt()}% operando',
                      badgeColor: AppColors.success,
                      icon: Icons.verified_user_rounded,
                      iconColor: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Enfermeros(as) Jefes',
                      value: '$nurses',
                      subtitle: 'Supervisores de cadena PAI',
                      badge: 'Rethus',
                      badgeColor: Colors.indigo,
                      icon: Icons.medical_services_rounded,
                      iconColor: Colors.indigo,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Auxiliares de Vacunación',
                      value: '$assistants',
                      subtitle: 'Puntos fijos y brigadas',
                      badge: 'Operativos',
                      badgeColor: const Color(0xFF00B4D8),
                      icon: Icons.badge_rounded,
                      iconColor: const Color(0xFF00B4D8),
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Total Personal Registrado',
                value: '$totalUsers',
                subtitle: '$activeUsers activos en la sede',
                badge: 'Plantilla',
                badgeColor: AppColors.primary,
                icon: Icons.people_alt_rounded,
                iconColor: AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildKpiCard(
                title: 'Vacunadores Habilitados',
                value: '$activeUsers',
                subtitle: 'Con permiso de aplicación',
                badge: '${((activeUsers / (totalUsers > 0 ? totalUsers : 1)) * 100).toInt()}% activos',
                badgeColor: AppColors.success,
                icon: Icons.verified_user_rounded,
                iconColor: AppColors.success,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildKpiCard(
                title: 'Enfermeros(as) Jefes',
                value: '$nurses',
                subtitle: 'Supervisores y custodia',
                badge: 'Rethus',
                badgeColor: Colors.indigo,
                icon: Icons.medical_services_rounded,
                iconColor: Colors.indigo,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildKpiCard(
                title: 'Auxiliares de Vacunación',
                value: '$assistants',
                subtitle: 'Atención intramural y brigada',
                badge: 'Operativos',
                badgeColor: const Color(0xFF00B4D8),
                icon: Icons.badge_rounded,
                iconColor: const Color(0xFF00B4D8),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.slate,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Barra de Búsqueda y Filtros
  // ---------------------------------------------------------------------------
  Widget _buildFilterAndSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          // Campo de búsqueda
          SizedBox(
            width: 380,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() => _currentPage = 1),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, documento o correo...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.hint),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.slate,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _currentPage = 1);
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          // Filtros por Rol y Estado
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Filtro por Rol
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRoleFilter,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppColors.slate,
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'TODOS',
                        child: Text('Todos los roles'),
                      ),
                      DropdownMenuItem(
                        value: 'VACCINATOR',
                        child: Text('Rol: Vacunador'),
                      ),
                      DropdownMenuItem(
                        value: 'READ_ONLY',
                        child: Text('Rol: Solo Lectura'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedRoleFilter = val;
                          _currentPage = 1;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Filtro por Estado
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStatusFilter,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppColors.slate,
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'TODOS',
                        child: Text('Todos los estados'),
                      ),
                      DropdownMenuItem(
                        value: 'ACTIVE',
                        child: Text('Solo Activos'),
                      ),
                      DropdownMenuItem(
                        value: 'INACTIVE',
                        child: Text('Solo Inactivos'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedStatusFilter = val;
                          _currentPage = 1;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Tabla de Usuarios y Personal
  // ---------------------------------------------------------------------------
  Widget _buildUsersTableCard(BuildContext context) {
    final filtered = _filteredUsers;
    final paged = _pagedUsers;
    final totalPages = _totalPages;
    final currentPage = _currentPage.clamp(1, totalPages);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado de la tabla
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Personal / Identificación',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Profesión y Registro Rethus',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Contacto Institucional',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Roles PAI',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      'Estado',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 88,
                      child: Center(
                        child: Text(
                          'Acciones',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.slate,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filas de usuarios
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_search_rounded,
                      size: 48,
                      color: AppColors.hint.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No se encontraron usuarios con los filtros aplicados',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Intenta ajustar el término de búsqueda o cambia los filtros de rol/estado.',
                      style: TextStyle(fontSize: 12, color: AppColors.slate),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: paged.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                color: AppColors.border,
              ),
              itemBuilder: (context, index) {
                final user = paged[index];
                return _buildUserTableRow(context, user);
              },
            ),

          // Pie de tabla con conteo y paginación
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  filtered.isEmpty
                      ? 'No hay usuarios para mostrar'
                      : 'Mostrando ${(currentPage - 1) * _pageSize + 1}–${((currentPage - 1) * _pageSize + paged.length)} de ${filtered.length} usuarios (${_effectiveUsers.length} en total)',
                  style: const TextStyle(fontSize: 12, color: AppColors.slate),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: currentPage > 1
                          ? () => setState(() => _currentPage = currentPage - 1)
                          : null,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('‹ Anterior'),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Página $currentPage de $totalPages',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: currentPage < totalPages
                          ? () => setState(() => _currentPage = currentPage + 1)
                          : null,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Siguiente ›'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTableRow(BuildContext context, Vaccinator user) {
    final initials = user.fullName
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join();

    final professionLabel = switch (user.professionCode) {
      'ENFERMERO' => 'Enfermero(a) Profesional',
      'AUXILIAR_ENFERMERIA' => 'Auxiliar de Enfermería',
      'MEDICO' => 'Médico General',
      'ODONTOLOGO' => 'Odontólogo',
      'BACTERIOLOGO' => 'Bacteriólogo',
      'PROMOTOR_SALUD' => 'Promotor de Salud',
      _ => user.professionCode ?? 'Personal Asistencial',
    };

    final docText = user.documentType != null && user.documentNumber != null
        ? '${user.documentType} ${user.documentNumber}'
        : 'Sin documento';

    final rethusText = user.professionalRegistrationNumber != null &&
            user.professionalRegistrationNumber!.isNotEmpty
        ? user.professionalRegistrationNumber!
        : 'Habilitación General';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          // 1. Personal / Identificación
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: user.isActive
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.hint.withValues(alpha: 0.15),
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: user.isActive ? AppColors.primary : AppColors.slate,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        docText,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.slate,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Profesión y Registro Rethus
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  professionLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.verified_outlined,
                      size: 13,
                      color: AppColors.slate,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        rethusText,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.slate,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Contacto Institucional
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.mail_outline_rounded,
                      size: 13,
                      color: AppColors.slate,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 13,
                      color: AppColors.slate,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      user.phone != null && user.phone!.isNotEmpty
                          ? user.phone!
                          : 'Sin registrar',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.slate,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 4. Roles PAI
          Expanded(
            flex: 2,
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: user.roles.map((r) {
                final isVaccinator = r == 'VACCINATOR';
                final label = isVaccinator ? 'Vacunador' : 'Solo Lectura';
                final color = isVaccinator ? AppColors.primary : Colors.blueGrey;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: color.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // 5. Estado
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: user.isActive
                      ? AppColors.success.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: user.isActive
                            ? AppColors.success
                            : Colors.grey.shade600,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      user.isActive ? 'Activo' : 'Inactivo',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: user.isActive
                            ? AppColors.success
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 6. Acciones
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 88,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Ver detalle
                    Tooltip(
                      message: 'Ver ficha completa',
                      child: IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: const EdgeInsets.all(6),
                        icon: const Icon(
                          Icons.visibility_outlined,
                          size: 18,
                          color: AppColors.slate,
                        ),
                        onPressed: () => _showUserDetailsDialog(context, user),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Diálogo de Detalle del Usuario
  // ---------------------------------------------------------------------------
  void _showUserDetailsDialog(BuildContext context, Vaccinator user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: const Icon(
                Icons.person_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    user.email,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.slate,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 24, color: AppColors.border),
              _buildDetailRow(
                'Identificación',
                '${user.documentType ?? 'CC'} ${user.documentNumber ?? 'No registrada'}',
              ),
              const SizedBox(height: 10),
              _buildDetailRow(
                'Profesión',
                user.professionCode ?? 'Personal Asistencial',
              ),
              const SizedBox(height: 10),
              _buildDetailRow(
                'Registro Rethus / Matrícula',
                user.professionalRegistrationNumber ?? 'Sin registro específico',
              ),
              const SizedBox(height: 10),
              _buildDetailRow(
                'Teléfono de Contacto',
                user.phone ?? 'No registrado',
              ),
              const SizedBox(height: 10),
              _buildDetailRow(
                'Estado Operativo',
                user.isActive
                    ? 'Activo (Habilitado para registrar vacunación)'
                    : 'Inactivo (Acceso suspendido)',
              ),
              const SizedBox(height: 10),
              _buildDetailRow(
                'Roles Asignados',
                user.roles.join(', '),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 170,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.slate,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
