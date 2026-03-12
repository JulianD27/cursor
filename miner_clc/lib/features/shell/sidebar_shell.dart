import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../gases/gases_screen.dart';
import '../ventilacion/ventilacion_screen.dart';
import '../alertas/alertas_screen.dart';
import '../configuracion/configuracion_screen.dart';

const _sidebarBg = Color(0xFF1A1A1A);
const _topbarBg  = Color(0xFF1E1E1E);
const _mainBg    = Color(0xFF3A3A3A);
const _activeNav = Color(0xFF2A2A2A);
const _accent    = Color(0xFF4A90D9);
const _border    = Color(0xFF444444);
const _white     = Color(0xFFFFFFFF);
const _muted     = Color(0xFF888888);
const _light     = Color(0xFFE0E0E0);

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem(this.label, this.icon);
}

// ── 5 ítems principales + Configuración al fondo ──
const _navItems = [
  _NavItem('Dashboard',          Icons.dashboard_outlined),
  _NavItem('Monitoreo de Gases', Icons.monitor_heart_outlined),
  _NavItem('Ventilación',        Icons.air_outlined),
  _NavItem('Alertas',            Icons.notifications_outlined),
];

class SidebarShell extends StatefulWidget {
  const SidebarShell({super.key});
  @override
  State<SidebarShell> createState() => _SidebarShellState();
}

class _SidebarShellState extends State<SidebarShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    GasesScreen(),
    VentilacionScreen(),
    AlertasScreen(),
    ConfiguracionScreen(), // índice 4
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: _mainBg,
      body: Row(
        children: [
          _Sidebar(
            selectedIndex: _selectedIndex,
            userName: auth.displayName ?? auth.username ?? 'Usuario',
            userRole: auth.userId != null ? 'Usuario: ${auth.userId}' : 'Minero',
            onNavTap: (i) => setState(() => _selectedIndex = i),
            onLogout: () => auth.logout(),
          ),
          Expanded(
            child: Column(
              children: [
                _Topbar(
                  title: _selectedIndex < _navItems.length
                      ? _navItems[_selectedIndex].label
                      : 'Configuración',
                ),
                Expanded(child: _screens[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SIDEBAR
// ─────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final String userName;
  final String userRole;
  final ValueChanged<int> onNavTap;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.selectedIndex,
    required this.userName,
    required this.userRole,
    required this.onNavTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(color: _sidebarBg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LOGO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: const BoxDecoration(
              color: _sidebarBg,
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: const [
                Icon(Icons.construction, color: _accent, size: 22),
                SizedBox(width: 10),
                Text(
                  'MINER CLC',
                  style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _white,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          // PERFIL
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF242424),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF333333),
                    border: Border.all(color: _accent, width: 1.5),
                  ),
                  child: const Icon(Icons.person, color: _light, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontFamily: 'Rajdhani',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(userRole,
                          style: const TextStyle(fontSize: 11, color: _muted)),
                    ],
                  ),
                ),
                // Botón ir a Configuración directamente
                IconButton(
                  icon: const Icon(Icons.settings_outlined,
                      size: 16, color: _muted),
                  onPressed: () => onNavTap(4),
                  tooltip: 'Ver / editar perfil',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // NAV ITEMS principales
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: _navItems.length,
              itemBuilder: (_, i) => _NavRow(
                icon: _navItems[i].icon,
                label: _navItems[i].label,
                isActive: selectedIndex == i,
                onTap: () => onNavTap(i),
              ),
            ),
          ),

          // FOOTER — Configuración + Cerrar sesión
          Container(
            decoration: const BoxDecoration(
              color: _sidebarBg,
              border: Border(top: BorderSide(color: _border)),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              children: [
                // Configuración como ítem navegable (índice 4)
                _NavRow(
                  icon: Icons.manage_accounts_outlined,
                  label: 'Configuración',
                  isActive: selectedIndex == 4,
                  onTap: () => onNavTap(4),
                  color: _muted,
                ),
                const SizedBox(height: 2),
                // Cerrar sesión
                InkWell(
                  onTap: onLogout,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: const [
                        Icon(Icons.logout, color: _muted, size: 18),
                        SizedBox(width: 14),
                        Text(
                          'CERRAR SESIÓN',
                          style: TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _muted,
                            letterSpacing: 0.8,
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
}

// ─────────────────────────────────────────────
//  FILA NAV
// ─────────────────────────────────────────────
class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color? color;

  const _NavRow({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isActive ? _accent : (color ?? _light);
    final textColor = isActive ? _white  : (color ?? _light);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? _activeNav : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isActive
            ? Border.all(color: _accent.withOpacity(0.25))
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 14,
                    fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.w600,
                    color: textColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (isActive)
                Container(
                  width: 5, height: 5,
                  decoration: const BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  TOPBAR
// ─────────────────────────────────────────────
class _Topbar extends StatelessWidget {
  final String title;
  const _Topbar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: _topbarBg,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu, color: _muted, size: 20),
          const SizedBox(width: 16),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Rajdhani',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _white,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A3A1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF27AE60).withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2ECC71),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('Sistema activo',
                    style: TextStyle(
                        fontSize: 11, color: Color(0xFF2ECC71))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: _muted, size: 20),
                onPressed: () {},
              ),
              Positioned(
                right: 8, top: 8,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE74C3C),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}