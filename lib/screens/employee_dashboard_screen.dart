import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/attendance_model.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';

const Color _emerald = Color(0xFF059669);
const Color _emeraldDark = Color(0xFF047857);
const Color _emeraldLight = Color(0xFFECFDF5);
const Color _blue = Color(0xFF2563EB);
const Color _pageBackground = Color(0xFFF7F9FC);
const Color _textPrimary = Color(0xFF172033);
const Color _textSecondary = Color(0xFF718096);
const Color _borderColor = Color(0xFFE8EDF3);

class EmployeeDashboardScreen extends ConsumerWidget {
  const EmployeeDashboardScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authProvider.notifier).logout();

    if (!context.mounted) return;

    context.go('/login');
  }

  Future<void> _refresh(WidgetRef ref) async {
    await ref.read(employeeAttendanceProvider.notifier).fetchMyAttendance();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final attendanceState = ref.watch(employeeAttendanceProvider);

    final user = authState.user;
    final fullName = user?.fullName ?? 'Employee';
    final email = user?.email ?? '';
    final initial = fullName.trim().isNotEmpty
        ? fullName.trim()[0].toUpperCase()
        : 'E';

    return Scaffold(
      backgroundColor: _pageBackground,
      drawer: MediaQuery.sizeOf(context).width < 900
          ? Drawer(
              backgroundColor: Colors.white,
              child: SafeArea(
                child: _DashboardSidebar(
                  name: fullName,
                  email: email,
                  onDashboard: () => Navigator.pop(context),
                  onAttendance: () {
                    Navigator.pop(context);
                    context.go('/check-in');
                  },
                  onLogout: () => _logout(context, ref),
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 900;

            return Row(
              children: [
                if (desktop)
                  SizedBox(
                    width: 250,
                    child: _DashboardSidebar(
                      name: fullName,
                      email: email,
                      onDashboard: () {},
                      onAttendance: () => context.go('/check-in'),
                      onLogout: () => _logout(context, ref),
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      _DashboardTopBar(
                        name: fullName,
                        onMenu: desktop
                            ? null
                            : () => Scaffold.of(context).openDrawer(),
                        onLogout: () => _logout(context, ref),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () => _refresh(ref),
                          color: _emerald,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.all(desktop ? 32 : 18),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1250,
                                ),
                                child: attendanceState.when(
                                  loading: () => const SizedBox(
                                    height: 350,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: _emerald,
                                      ),
                                    ),
                                  ),
                                  error: (error, stackTrace) => _ErrorPanel(
                                    message:
                                        'We could not load your attendance '
                                        'records. Check your connection and '
                                        'try again.',
                                    onRetry: () => _refresh(ref),
                                  ),
                                  data: (logs) => _DashboardContent(
                                    name: fullName,
                                    email: email,
                                    initial: initial,
                                    logs: logs,
                                    desktop: desktop,
                                    onAttendance: () => context.go('/check-in'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// TOP BAR
// ============================================================

class _DashboardTopBar extends StatelessWidget {
  final String name;
  final VoidCallback? onMenu;
  final VoidCallback onLogout;

  const _DashboardTopBar({
    required this.name,
    required this.onMenu,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          if (onMenu != null) ...[
            Builder(
              builder: (context) => IconButton(
                onPressed: onMenu,
                icon: const Icon(Icons.menu_rounded),
                tooltip: 'Open navigation',
              ),
            ),
            const SizedBox(width: 8),
          ],
          const Expanded(
            child: Text(
              'Employee workspace',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: _emeraldLight,
            child: Text(
              name.trim().isEmpty ? 'E' : name.trim()[0].toUpperCase(),
              style: const TextStyle(
                color: _emeraldDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: onLogout,
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded, color: _textSecondary),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SIDEBAR
// ============================================================

class _DashboardSidebar extends StatelessWidget {
  final String name;
  final String email;
  final VoidCallback onDashboard;
  final VoidCallback onAttendance;
  final VoidCallback onLogout;

  const _DashboardSidebar({
    required this.name,
    required this.email,
    required this.onDashboard,
    required this.onAttendance,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _emerald,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.workspaces_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'WorkSphere',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 38),
          const Padding(
            padding: EdgeInsets.only(left: 12, bottom: 12),
            child: Text(
              'WORKSPACE',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
          _SidebarItem(
            icon: Icons.grid_view_rounded,
            label: 'Dashboard',
            selected: true,
            onTap: onDashboard,
          ),
          _SidebarItem(
            icon: Icons.fact_check_outlined,
            label: 'Attendance',
            onTap: onAttendance,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _pageBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _emeraldLight,
                  child: Text(
                    name.trim().isEmpty ? 'E' : name.trim()[0].toUpperCase(),
                    style: const TextStyle(
                      color: _emeraldDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SidebarItem(
            icon: Icons.logout_rounded,
            label: 'Log out',
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? _emeraldLight : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? _emeraldDark : _textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? _emeraldDark : _textSecondary,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (selected) ...[
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: _emerald,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DASHBOARD CONTENT
// ============================================================

class _DashboardContent extends StatelessWidget {
  final String name;
  final String email;
  final String initial;
  final List<AttendanceLog> logs;
  final bool desktop;
  final VoidCallback onAttendance;

  const _DashboardContent({
    required this.name,
    required this.email,
    required this.initial,
    required this.logs,
    required this.desktop,
    required this.onAttendance,
  });

  @override
  Widget build(BuildContext context) {
    final sortedLogs = [...logs]
      ..sort((a, b) => b.checkInTime.compareTo(a.checkInTime));

    final now = DateTime.now();
    final todayLogs = sortedLogs.where((log) {
      final date = log.checkInTime.toLocal();
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();

    final todayRecord = todayLogs.isEmpty ? null : todayLogs.first;

    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));

    final weekLogs = sortedLogs.where((log) {
      final date = log.checkInTime.toLocal();
      return !date.isBefore(weekStart) && !date.isAfter(now);
    }).toList();

    final presentDays = weekLogs
        .map((log) {
          final date = log.checkInTime.toLocal();
          return '${date.year}-${date.month}-${date.day}';
        })
        .toSet()
        .length;

    final hoursWorked = weekLogs.fold<double>(
      0,
      (total, log) => total + log.getHoursWorked(),
    );

    final isCheckedIn = todayRecord != null && todayRecord.checkOutTime == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WelcomeSection(
          name: name,
          email: email,
          initial: initial,
          desktop: desktop,
        ),
        const SizedBox(height: 28),
        _AttendanceStatusCard(
          record: todayRecord,
          isCheckedIn: isCheckedIn,
          onAttendance: onAttendance,
          desktop: desktop,
        ),
        const SizedBox(height: 28),
        const Text(
          'Your overview',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'A summary of your recorded attendance over the last 7 days.',
          style: TextStyle(color: _textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: desktop ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: desktop ? 1.9 : 1.4,
          children: [
            _MetricCard(
              title: 'Days present',
              value: '$presentDays',
              subtitle: 'Distinct recorded days',
              icon: Icons.calendar_month_rounded,
              accent: _emerald,
              background: _emeraldLight,
            ),
            _MetricCard(
              title: 'Hours recorded',
              value: hoursWorked.toStringAsFixed(1),
              subtitle: 'Completed attendance sessions',
              icon: Icons.schedule_rounded,
              accent: _blue,
              background: const Color(0xFFEFF6FF),
              suffix: 'h',
            ),
            _MetricCard(
              title: 'Attendance records',
              value: '${logs.length}',
              subtitle: 'Records returned by the API',
              icon: Icons.fact_check_outlined,
              accent: const Color(0xFF7C3AED),
              background: const Color(0xFFF5F3FF),
            ),
          ],
        ),
        const SizedBox(height: 30),
        _RecentAttendanceSection(
          logs: sortedLogs.take(5).toList(),
          desktop: desktop,
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text(
            'WorkSphere AI 2.0 · Employee workspace',
            style: TextStyle(color: _textSecondary, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _WelcomeSection extends StatelessWidget {
  final String name;
  final String email;
  final String initial;
  final bool desktop;

  const _WelcomeSection({
    required this.name,
    required this.email,
    required this.initial,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final firstName = name.trim().isEmpty
        ? 'there'
        : name.trim().split(RegExp(r'\s+')).first;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back, $firstName',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: desktop ? 27 : 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Here is what is happening with your attendance.',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: desktop ? 14 : 12,
                ),
              ),
            ],
          ),
        ),
        if (desktop) ...[
          const SizedBox(width: 16),
          CircleAvatar(
            radius: 27,
            backgroundColor: _emeraldLight,
            child: Text(
              initial,
              style: const TextStyle(
                color: _emeraldDark,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================
// TODAY'S ATTENDANCE STATUS
// ============================================================

class _AttendanceStatusCard extends StatelessWidget {
  final AttendanceLog? record;
  final bool isCheckedIn;
  final VoidCallback onAttendance;
  final bool desktop;

  const _AttendanceStatusCard({
    required this.record,
    required this.isCheckedIn,
    required this.onAttendance,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final hasRecord = record != null;

    final title = !hasRecord
        ? 'No check-in recorded yet'
        : isCheckedIn
        ? 'You are checked in'
        : 'You have checked out';

    final description = !hasRecord
        ? 'Start your attendance session when you are ready.'
        : isCheckedIn
        ? 'Your attendance session is currently open.'
        : 'Your latest attendance session is complete.';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(desktop ? 25 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF172033).withValues(alpha: 0.035),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: isCheckedIn ? _emeraldLight : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  isCheckedIn
                      ? Icons.check_circle_rounded
                      : Icons.access_time_rounded,
                  color: isCheckedIn ? _emeraldDark : _blue,
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TODAY'S ATTENDANCE",
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(
                label: !hasRecord
                    ? 'Not started'
                    : isCheckedIn
                    ? 'Checked in'
                    : 'Checked out',
                active: isCheckedIn,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            description,
            style: const TextStyle(color: _textSecondary, fontSize: 13),
          ),
          if (hasRecord) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 26,
              runSpacing: 12,
              children: [
                _TimeDetail(
                  label: 'Check-in',
                  value: _formatTime(record!.checkInTime),
                  icon: Icons.login_rounded,
                ),
                _TimeDetail(
                  label: 'Check-out',
                  value: record!.checkOutTime == null
                      ? 'Not recorded'
                      : _formatTime(record!.checkOutTime!),
                  icon: Icons.logout_rounded,
                ),
              ],
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: desktop ? 220 : double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAttendance,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Open attendance'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _emerald,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final bool active;

  const _StatusPill({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? _emeraldDark : _textSecondary;
    final background = active ? _emeraldLight : _pageBackground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TimeDetail extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _TimeDetail({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _textSecondary, size: 17),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: _textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// STATISTICS CARDS
// ============================================================

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color background;
  final String suffix;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.background,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 19),
              ),
              const Spacer(),
              Icon(
                Icons.trending_up_rounded,
                size: 17,
                color: accent.withValues(alpha: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                if (suffix.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 3, bottom: 3),
                    child: Text(
                      suffix,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// RECENT ATTENDANCE HISTORY
// ============================================================

class _RecentAttendanceSection extends StatelessWidget {
  final List<AttendanceLog> logs;
  final bool desktop;

  const _RecentAttendanceSection({required this.logs, required this.desktop});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(desktop ? 24 : 17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent attendance',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Your latest recorded attendance sessions.',
            style: TextStyle(color: _textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),
          if (logs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_note_rounded,
                      color: _textSecondary,
                      size: 35,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'No attendance records yet',
                      style: TextStyle(color: _textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ...logs.map((log) => _AttendanceHistoryRow(log: log)),
        ],
      ),
    );
  }
}

class _AttendanceHistoryRow extends StatelessWidget {
  final AttendanceLog log;

  const _AttendanceHistoryRow({required this.log});

  @override
  Widget build(BuildContext context) {
    final checkedOut = log.checkOutTime != null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: checkedOut ? _emeraldLight : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              checkedOut
                  ? Icons.check_circle_outline_rounded
                  : Icons.access_time_rounded,
              color: checkedOut ? _emeraldDark : _blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(log.checkInTime),
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_formatTime(log.checkInTime)}'
                  '  ·  '
                  '${log.checkOutTime == null ? 'No check-out' : _formatTime(log.checkOutTime!)}',
                  style: const TextStyle(color: _textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusPill(
            label: checkedOut ? 'Complete' : 'Open',
            active: !checkedOut,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ERROR STATE
// ============================================================

class _ErrorPanel extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorPanel({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: _textSecondary, size: 42),
          const SizedBox(height: 16),
          const Text(
            'Attendance unavailable',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _emerald,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DATE AND TIME FORMATTING
// ============================================================

String _formatTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';

  return '$hour:$minute $period';
}

String _formatDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${weekdays[local.weekday - 1]}, '
      '${months[local.month - 1]} ${local.day}, ${local.year}';
}
