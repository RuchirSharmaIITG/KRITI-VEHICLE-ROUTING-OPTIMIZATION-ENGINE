import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/constants.dart';
import '../services/app_state.dart';
import '../widgets/control_panel.dart';
import '../widgets/results_panel.dart';
import '../widgets/map_board.dart';
import '../widgets/fleet_table.dart';
import '../widgets/employee_table.dart';
import '../widgets/analytics_view.dart'; // This import is now active and working!

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  int? _lastSimulatingIndex;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
  }

  // Called on every rebuild — detects when simulation ends and re-expands sheet
  void _handleSheetOnSimulationChange(int? simulatingIndex) {
    if (_lastSimulatingIndex != null && simulatingIndex == null) {
      // Simulation just ended → re-expand sheet so user sees results
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_sheetController.isAttached) {
          _sheetController.animateTo(
            0.35,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
    _lastSimulatingIndex = simulatingIndex;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Track simulation state changes to auto-expand/collapse sheet
    _handleSheetOnSimulationChange(state.simulatingVehicleIndex);

    return FadeTransition(
      opacity: _fadeController,
      child: Scaffold(
        backgroundColor: VeloraColors.background,
        // Top Nav Bar
        appBar: _buildNavBar(state),
        // Bottom Navigation for mobile
        bottomNavigationBar: _buildBottomNav(state),
        body: _buildBody(state),
      ),
    );
  }

  PreferredSizeWidget _buildNavBar(AppState state) {
    return AppBar(
      backgroundColor: VeloraColors.surface,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => state.resetApp(),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: VeloraColors.surfaceLighter),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back, color: VeloraColors.textSecondary, size: 16),
              SizedBox(width: 1),
            ],
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [VeloraColors.cyanDark, VeloraColors.blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: VeloraColors.cyan.withOpacity(0.3),
                  blurRadius: 15,
                ),
              ],
            ),
            child: const Center(
              child: Text('V', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'VELORA',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              color: Colors.white,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        // Bell icon
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: VeloraColors.textSecondary),
              onPressed: () {},
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: VeloraColors.cyan,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        // User avatar
        Container(
          margin: const EdgeInsets.only(right: 12),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: VeloraColors.surfaceLight,
            border: Border.all(color: VeloraColors.surfaceLighter),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person_outline, color: VeloraColors.cyan, size: 20),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: VeloraColors.borderCyan,
        ),
      ),
    );
  }

  Widget _buildBottomNav(AppState state) {
    return Container(
      decoration: BoxDecoration(
        color: VeloraColors.surface,
        border: Border(top: BorderSide(color: VeloraColors.surfaceLighter.withOpacity(0.3))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              _navItem(state, 'map', Icons.map_outlined, 'Map View'),
              _navItem(state, 'dashboard_view', Icons.dashboard_outlined, 'Dashboard'),
              _navItem(state, 'analytics', Icons.bar_chart_rounded, 'Analytics'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(AppState state, String tab, IconData icon, String label) {
    final isActive = state.activeTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => state.setActiveTab(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isActive ? VeloraColors.cyan.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive ? Border.all(color: VeloraColors.cyan.withOpacity(0.2)) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isActive ? VeloraColors.cyan : VeloraColors.textMuted, size: 20),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isActive ? VeloraColors.cyan : VeloraColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppState state) {
    switch (state.activeTab) {
      case 'map':
        return _buildMapView(state);
      case 'dashboard_view':
        return _buildDashboardView(state);
      case 'analytics':
      // This successfully calls your newly updated AnalyticsView
        return AnalyticsView(mapData: state.mapData);
      default:
        return _buildMapView(state);
    }
  }

  /// VIEW 1: MAP BOARD
  Widget _buildMapView(AppState state) {
    return Column(
      children: [
        ControlPanelWidget(
          fileName: state.fileName,
          fileBytes: state.fileBytes,
        ),
        Expanded(
          child: Stack(
            children: [
              MapBoardWidget(
                pickups: state.mapData.pickups,
                dropoffs: state.mapData.dropoffs,
                routes: state.mapData.routes,
                selectedRouteIndex: state.selectedVehicleIndex,
                simulatingVehicleIndex: state.simulatingVehicleIndex,
              ),
              DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: 0.35,
                minChildSize: 0.08,
                maxChildSize: 0.7,
                snap: true,
                snapSizes: const [0.08, 0.35, 0.7],
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: VeloraColors.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      border: Border(top: BorderSide(color: VeloraColors.surfaceLighter.withOpacity(0.5))),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: VeloraColors.surfaceLighter,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: ResultsPanelWidget(
                              data: state.mapData,
                              selectedIndex: state.selectedVehicleIndex,
                              onVehicleSelect: (i) => state.selectVehicle(i),
                              onSimulateClick: (i) {
                                state.handleSimulate(i);
                                // Auto-collapse sheet so map is fully visible
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (_sheetController.isAttached) {
                                    _sheetController.animateTo(
                                      0.08,
                                      duration: const Duration(milliseconds: 450),
                                      curve: Curves.easeOutCubic,
                                    );
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// VIEW 2: DASHBOARD TABLE
  Widget _buildDashboardView(AppState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.dashboard_outlined, color: VeloraColors.cyan, size: 22),
              SizedBox(width: 8),
              Text(
                'Live Fleet Manifest',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Synchronized with: ${state.fileName ?? 'No file'}',
            style: const TextStyle(fontSize: 12, color: VeloraColors.textSecondary, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 20),

          FleetTable(routes: state.mapData.routes),

          const SizedBox(height: 24),

          const Row(
            children: [
              Icon(Icons.people_outline, color: VeloraColors.emerald, size: 22),
              SizedBox(width: 8),
              Text(
                'Employee Assignments',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Individual pickup schedules & vehicle assignments',
            style: TextStyle(fontSize: 12, color: VeloraColors.textSecondary, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 16),

          EmployeeTable(assignments: state.mapData.rawAssignments),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}