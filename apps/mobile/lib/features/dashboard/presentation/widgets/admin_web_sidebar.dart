import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Ítem principal de navegación para el sidebar de escritorio.
class AdminSidebarItem {
  const AdminSidebarItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.subItems = const [],
  });

  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final List<AdminSidebarSubItem> subItems;

  bool get hasSubItems => subItems.isNotEmpty;
}

/// Sub-opción dentro de una sección del sidebar.
class AdminSidebarSubItem {
  const AdminSidebarSubItem({
    required this.label,
    required this.actionKey,
    this.icon,
  });

  final String label;
  final String actionKey;
  final IconData? icon;
}

/// Menú lateral interactivo de escritorio para Administradores.
///
/// Permanece colapsado en 72px mostrando solo iconos con Tooltip.
/// Al pasar el mouse encima (a cualquier altura), se expande suavemente a 270px
/// mostrando nombres y flechas desplegables para sub-opciones.
class AdminWebSidebar extends StatefulWidget {
  const AdminWebSidebar({
    super.key,
    required this.selectedSection,
    required this.onSelectSection,
    required this.onAction,
    required this.onSignOut,
    required this.userName,
    required this.institutionName,
    this.roleName = 'ADMINISTRADOR',
    this.isSuperAdmin = false,
  });

  final String selectedSection;
  final ValueChanged<String> onSelectSection;
  final ValueChanged<String> onAction;
  final VoidCallback onSignOut;
  final String userName;
  final String institutionName;
  final String roleName;
  final bool isSuperAdmin;

  @override
  State<AdminWebSidebar> createState() => _AdminWebSidebarState();
}

class _AdminWebSidebarState extends State<AdminWebSidebar> {
  bool _isHovered = false;
  final Set<String> _expandedSubmenus = {};

  List<AdminSidebarItem> get _items {
    if (widget.isSuperAdmin) {
      return const [
        AdminSidebarItem(
          id: 'inicio',
          label: 'Inicio',
          icon: Icons.space_dashboard_outlined,
          selectedIcon: Icons.space_dashboard_rounded,
        ),
        AdminSidebarItem(
          id: 'instituciones',
          label: 'Instituciones',
          icon: Icons.account_balance_outlined,
          selectedIcon: Icons.account_balance_rounded,
        ),
        AdminSidebarItem(
          id: 'administracion',
          label: 'Usuarios Globales',
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings_rounded,
        ),
        AdminSidebarItem(
          id: 'inventario',
          label: 'Inventario Global',
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2_rounded,
        ),
      ];
    }

    return const [
      AdminSidebarItem(
        id: 'inicio',
        label: 'Inicio',
        icon: Icons.space_dashboard_outlined,
        selectedIcon: Icons.space_dashboard_rounded,
      ),
      AdminSidebarItem(
        id: 'inventario',
        label: 'Inventario',
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2_rounded,
        subItems: [
          AdminSidebarSubItem(
            label: 'Catálogo y Stock de Lotes',
            actionKey: 'Inventario',
            icon: Icons.format_list_bulleted_rounded,
          ),
          AdminSidebarSubItem(
            label: 'Configuración de Vacunas',
            actionKey: 'Configuracion Vacunas',
            icon: Icons.tune_rounded,
          ),
          AdminSidebarSubItem(
            label: 'Ajustes y Regularizaciones',
            actionKey: 'Ajustes Inventario',
            icon: Icons.swap_horiz_rounded,
          ),
        ],
      ),
      AdminSidebarItem(
        id: 'entregas',
        label: 'Entregas y Custodia',
        icon: Icons.local_shipping_outlined,
        selectedIcon: Icons.local_shipping_rounded,
        subItems: [
          AdminSidebarSubItem(
            label: 'Entregas a Vacunadores',
            actionKey: 'Entregas',
            icon: Icons.outbox_rounded,
          ),
          AdminSidebarSubItem(
            label: 'Jornadas y Campañas',
            actionKey: 'Jornadas',
            icon: Icons.campaign_outlined,
          ),
          AdminSidebarSubItem(
            label: 'Custodia y Cierre de Jornada',
            actionKey: 'Custodia y cierre',
            icon: Icons.lock_clock_outlined,
          ),
          AdminSidebarSubItem(
            label: 'Conciliación de Diferencias',
            actionKey: 'Conciliacion',
            icon: Icons.fact_check_outlined,
          ),
        ],
      ),
      AdminSidebarItem(
        id: 'historial',
        label: 'Historial Clínico',
        icon: Icons.history_rounded,
        selectedIcon: Icons.history_rounded,
        subItems: [
          AdminSidebarSubItem(
            label: 'Búsqueda y Registro Clínico',
            actionKey: 'Historial',
            icon: Icons.search_rounded,
          ),
          AdminSidebarSubItem(
            label: 'Exportación de Reportes PAI',
            actionKey: 'Exportar datos',
            icon: Icons.download_rounded,
          ),
        ],
      ),
      AdminSidebarItem(
        id: 'administracion',
        label: 'Administración',
        icon: Icons.admin_panel_settings_outlined,
        selectedIcon: Icons.admin_panel_settings_rounded,
        subItems: [
          AdminSidebarSubItem(
            label: 'Personal y Vacunadores',
            actionKey: 'Administracion',
            icon: Icons.people_outline_rounded,
          ),
        ],
      ),
    ];
  }

  void _toggleSubmenu(String itemId) {
    setState(() {
      if (_expandedSubmenus.contains(itemId)) {
        _expandedSubmenus.remove(itemId);
      } else {
        _expandedSubmenus.add(itemId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded = _isHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) {
        setState(() {
          _isHovered = false;
          _expandedSubmenus.clear();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOutCubic,
        clipBehavior: Clip.antiAlias,
        width: isExpanded ? 270 : 72,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(
            right: BorderSide(color: AppColors.border, width: 1),
          ),
          boxShadow: [
            if (isExpanded)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(4, 0),
              ),
          ],
        ),
        child: Column(
          children: [
            // Cabecera del sidebar: Logo e Isotipo
            _buildHeader(isExpanded),
            const Divider(height: 1, color: AppColors.border),

            // Lista de ítems y submenús
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  for (final item in _items) _buildItemTile(item, isExpanded),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.border),
            // Pie de página: Usuario y botón de salir
            _buildFooter(isExpanded),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isExpanded) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.vaccines_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(width: 12),
            Expanded(
              child: ClipRect(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tu Vacuna PAI',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.ink,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.roleName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
                  const Text(
                    'Tu Vacuna PAI',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.ink,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.roleName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemTile(AdminSidebarItem item, bool isExpanded) {
    final isSelected = widget.selectedSection == item.id;
    final isSubmenuOpen = _expandedSubmenus.contains(item.id);

    if (!isExpanded) {
      // Estado colapsado: Solo icono centrado con Tooltip
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Tooltip(
          message: item.label,
          preferBelow: false,
          waitDuration: const Duration(milliseconds: 300),
          child: InkWell(
            onTap: () {
              widget.onSelectSection(item.id);
              if (item.hasSubItems) {
                _toggleSubmenu(item.id);
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isSelected ? item.selectedIcon : item.icon,
                color: isSelected ? AppColors.primary : AppColors.slate,
                size: 22,
              ),
            ),
          ),
        ),
      );
    }

    // Estado expandido: Fila con icono, nombre y flecha si tiene sub-opciones
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              widget.onSelectSection(item.id);
              if (item.hasSubItems) {
                _toggleSubmenu(item.id);
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? item.selectedIcon : item.icon,
                    color: isSelected ? AppColors.primary : AppColors.slate,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? AppColors.primary : AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.hasSubItems)
                    IconButton(
                      icon: Icon(
                        isSubmenuOpen
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_right_rounded,
                        size: 20,
                        color: isSelected ? AppColors.primary : AppColors.hint,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _toggleSubmenu(item.id),
                    ),
                ],
              ),
            ),
          ),

          // Sub-opciones desplegables
          if (item.hasSubItems && isSubmenuOpen)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 4, bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final subItem in item.subItems)
                    InkWell(
                      onTap: () {
                        widget.onSelectSection(item.id);
                        widget.onAction(subItem.actionKey);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              subItem.icon ?? Icons.arrow_right_rounded,
                              size: 16,
                              color: AppColors.slate,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                subItem.label,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.slate,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isExpanded) {
    if (!isExpanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Tooltip(
          message: 'Cerrar sesión',
          child: IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.slate),
            onPressed: widget.onSignOut,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primarySoft,
              child: Text(
                widget.userName.isNotEmpty
                    ? widget.userName[0].toUpperCase()
                    : 'A',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.institutionName,
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
            Tooltip(
              message: 'Cerrar sesión',
              child: IconButton(
                icon: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.danger,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: widget.onSignOut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
