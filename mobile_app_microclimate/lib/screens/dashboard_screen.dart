import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../providers/climate_provider.dart';
import '../widgets/status_badge.dart';
import 'package:easy_localization/easy_localization.dart';
import '../utils/profile_localization.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedChart =
      'all'; // 'all', 'temp', 'humidity', 'co2', 'co'
  String _chartTimeRange = 'all'; // 'all', '1h', '4h', '7d'

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => context.read<ClimateProvider>().refreshData(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 24),
                  _buildGauges(context),
                  const SizedBox(height: 24),
                  _buildChartSelector(context),
                  const SizedBox(height: 16),
                  _buildChart(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Consumer<ClimateProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MicroClimate AI',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF4F46E5),
                                ),
                      ),
                      Text(
                        'PRO',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showDeviceSheet(context, provider),
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.devices_rounded),
                      if (provider.devices.length > 1)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4F46E5),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => provider.refreshData(),
                  icon: provider.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: () =>
                          _showNotificationHistory(context, provider),
                      icon: Icon(
                        provider.pushInitialized
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_off_rounded,
                        color: provider.pushInitialized
                            ? Colors.green
                            : Colors.grey,
                      ),
                    ),
                    if (provider.notificationLogs.isNotEmpty)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            provider.notificationLogs.length > 99
                                ? '99+'
                                : provider.notificationLogs.length.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            StatusBadge(
              isOnline: provider.serverOnline,
              isDanger: provider.isDangerMode(),
            ),
            if (provider.devices.length > 1) ...[
              const SizedBox(height: 12),
              _buildDeviceSelector(context, provider),
            ],
            const SizedBox(height: 8),
            if (provider.activeProfile != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${'profile'.tr()}: ',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      localizedProfileName(
                          context, provider.activeProfile!.name),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF4F46E5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDeviceSelector(BuildContext context, dynamic provider) {
    final colorScheme = Theme.of(context).colorScheme;
    final devices = provider.devices as List<Map<String, dynamic>>;
    final selectedId = provider.selectedDeviceId as String?;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: devices.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final dev = devices[i];
          final id = dev['device_id']?.toString() ?? dev['id']?.toString() ?? '';
          final name = dev['name']?.toString().isNotEmpty == true
              ? dev['name'].toString()
              : id.length > 8 ? '${id.substring(0, 8)}…' : id;
          final isSelected = id == selectedId;

          return GestureDetector(
            onTap: () => provider.setSelectedDevice(id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF4F46E5)
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sensors_rounded,
                    size: 14,
                    color: isSelected
                        ? Colors.white
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 🎯 СПИДОМЕТРЫ для основных параметров
  Widget _buildGauges(BuildContext context) {
    return Consumer<ClimateProvider>(
      builder: (context, provider, _) {
        final data = provider.currentData;
        if (data == null) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              provider.error ?? 'Нет данных. Нажмите обновить.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return Column(
          children: [
            // Первый ряд: Температура и Влажность
            Row(
              children: [
                Expanded(
                  child: _buildGaugeCard(
                    context: context,
                    title: 'temperature'.tr(),
                    value: data.temp,
                    unit: '°C',
                    minValue: 0,
                    maxValue: 40,
                    color: Colors.red,
                    isDanger: provider.activeProfile != null &&
                        (data.temp < provider.activeProfile!.tempMin ||
                            data.temp > provider.activeProfile!.tempMax),
                    icon: Icons.thermostat_rounded,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildGaugeCard(
                    context: context,
                    title: 'humidity'.tr(),
                    value: data.humidity,
                    unit: '%',
                    minValue: 0,
                    maxValue: 100,
                    color: Colors.blue,
                    isDanger: provider.activeProfile != null &&
                        data.humidity > provider.activeProfile!.humidityMax,
                    icon: Icons.water_drop_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Второй ряд: CO₂ и CO
            Row(
              children: [
                Expanded(
                  child: _buildGaugeCard(
                    context: context,
                    title: 'CO₂',
                    value: data.co2.toDouble(),
                    unit: 'ppm',
                    minValue: 400,
                    maxValue: 2000,
                    color: Colors.green,
                    isDanger: provider.activeProfile != null &&
                        data.co2 > provider.activeProfile!.co2Max,
                    icon: Icons.air_rounded,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildGaugeCard(
                    context: context,
                    title: 'CO',
                    value: data.co,
                    unit: 'ppm',
                    minValue: 0,
                    maxValue: 200,
                    color: Colors.deepOrange,
                    isDanger: provider.activeProfile != null &&
                        data.co > provider.activeProfile!.coMax,
                    icon: Icons.air_rounded,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildGaugeCard({
    required BuildContext context,
    required String title,
    required double value,
    required String unit,
    required double minValue,
    required double maxValue,
    required Color color,
    required bool isDanger,
    required IconData icon,
  }) {
    final percentage =
        ((value - minValue) / (maxValue - minValue)).clamp(0.0, 1.0);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            width: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background arc
                CustomPaint(
                  size: const Size(120, 120),
                  painter: GaugeArcPainter(
                    percentage: 1.0,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                    strokeWidth: 12,
                  ),
                ),
                // Filled arc
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeOutCubic,
                  tween: Tween(begin: 0.0, end: percentage),
                  builder: (context, animatedValue, _) {
                    return CustomPaint(
                      size: const Size(120, 120),
                      painter: GaugeArcPainter(
                        percentage: animatedValue,
                        color: isDanger ? Colors.red : color,
                        strokeWidth: 12,
                      ),
                    );
                  },
                ),
                // Value in center
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      value.toStringAsFixed(
                          unit == 'ppm' || unit == 'lx' ? 0 : 1),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDanger ? Colors.red : color,
                      ),
                    ),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (isDanger)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 14, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(
                    'out_of_range'.tr(),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List _filterHistoryByTimeRange(List history) {
    if (_chartTimeRange == 'all') return history;
    Duration duration;
    if (_chartTimeRange == '1h') {
      duration = const Duration(hours: 1);
    } else if (_chartTimeRange == '4h') {
      duration = const Duration(hours: 4);
    } else if (_chartTimeRange == '7d') {
      duration = const Duration(days: 7);
    } else {
      return history;
    }
    final now = DateTime.now();
    final cutoff = now.subtract(duration);
    final filtered = history.where((d) {
      final dt = DateTime.tryParse(d.timestamp as String);
      if (dt == null) return true;
      return dt.isAfter(cutoff);
    }).toList();
    return filtered.isEmpty ? history : filtered;
  }

  Widget _buildTimeRangePicker(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ranges = [
      ('All', 'all'),
      ('1H', '1h'),
      ('4H', '4h'),
      ('7D', '7d'),
    ];
    return Row(
      children: ranges.map((entry) {
        final label = entry.$1;
        final value = entry.$2;
        final isSelected = _chartTimeRange == value;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _chartTimeRange = value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF4F46E5)
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Chart type selector: allows switching between different climate metrics
  /// or viewing all metrics simultaneously
  Widget _buildChartSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildChartButton(context, 'All'.tr(), 'all'),
          _buildChartButton(context, 'Temp.'.tr(), 'temp'),
          _buildChartButton(context, 'Humi.'.tr(), 'humidity'),
          _buildChartButton(context, 'co2'.tr(), 'co2'),
          _buildChartButton(context, 'CO', 'co'),
        ],
      ),
    );
  }

  Widget _buildChartButton(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedChart == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedChart = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    return Consumer<ClimateProvider>(
      builder: (context, provider, _) {
        if (provider.history.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getChartTitle(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 250,
                child: _buildSelectedChart(
                  _filterHistoryByTimeRange(provider.history),
                ),
              ),
              if (_selectedChart == 'all') ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildChartLegend(context, 'temperature'.tr(), Colors.red),
                    const SizedBox(width: 16),
                    _buildChartLegend(context, 'humidity'.tr(), Colors.blue),
                    const SizedBox(width: 16),
                    _buildChartLegend(context, 'CO', Colors.deepOrange),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _buildTimeRangePicker(context),
            ],
          ),
        );
      },
    );
  }

  String _getChartTitle() {
    switch (_selectedChart) {
      case 'temp':
        return 'temperature'.tr();
      case 'humidity':
        return 'humidity'.tr();
      case 'co2':
        return 'co2_level'.tr();
      case 'co':
        return 'co'.tr();
      default:
        return 'live_stream'.tr();
    }
  }

  Widget _buildSelectedChart(List history) {
    const maxDataPoints = 100;
    if (history.length > maxDataPoints) {
      history = history.sublist(history.length - maxDataPoints);
    }

    switch (_selectedChart) {
      case 'temp':
        return _buildSingleLineChart(
          history: history,
          getValue: (data) => data.temp,
          color: Colors.red,
          unit: '°C',
        );
      case 'humidity':
        return _buildSingleLineChart(
          history: history,
          getValue: (data) => data.humidity,
          color: Colors.blue,
          unit: '%',
        );
      case 'co2':
        return _buildSingleLineChart(
          history: history,
          getValue: (data) => data.co2.toDouble(),
          color: Colors.green,
          unit: 'ppm',
        );
      case 'co':
        return _buildSingleLineChart(
          history: history,
          getValue: (data) => data.co,
          color: Colors.deepOrange,
          unit: 'ppm',
        );
      default:
        return _buildMultiLineChart(history);
    }
  }

  Widget _buildSingleLineChart({
    required List history,
    required double Function(dynamic) getValue,
    required Color color,
    required String unit,
  }) {
    final spots = history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), getValue(e.value)))
        .toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: null,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.35),
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval:
                  history.length > 10 ? (history.length / 5).ceilToDouble() : 2,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: Theme.of(context).colorScheme.surface,
                  strokeWidth: 2,
                  strokeColor: color,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.3),
                  color.withValues(alpha: 0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiLineChart(List history) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 10,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.35),
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval:
                  history.length > 10 ? (history.length / 5).ceilToDouble() : 2,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          // Temperature line
          LineChartBarData(
            spots: history
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.temp))
                .toList(),
            isCurved: true,
            color: Colors.red,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.red.withValues(alpha: 0.05),
            ),
          ),
          // Humidity line
          LineChartBarData(
            spots: history
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.humidity))
                .toList(),
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: false),
          ),
          // CO line
          LineChartBarData(
            spots: history
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.co))
                .toList(),
            isCurved: true,
            color: Colors.deepOrange,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend(BuildContext context, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  void _showDeviceSheet(BuildContext context, dynamic provider) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final devices =
                provider.devices as List<Map<String, dynamic>>;
            final selectedId = provider.selectedDeviceId as String?;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Заголовок
                    Row(
                      children: [
                        Text(
                          'Мои устройства',
                          style: Theme.of(ctx)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        // Кнопка добавить
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            _showAddDeviceDialog(context, provider);
                          },
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Добавить'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (provider.isDeviceLoading)
                      const Center(
                          child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ))
                    else if (devices.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Нет устройств. Нажмите «Добавить».',
                          style:
                              TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    else
                      ...devices.map((dev) {
                        final id = dev['device_id']?.toString() ??
                            dev['id']?.toString() ??
                            '';
                        final name =
                            dev['name']?.toString().isNotEmpty == true
                                ? dev['name'].toString()
                                : id;
                        final isSelected = id == selectedId;
                        return GestureDetector(
                          onTap: () async {
                            Navigator.pop(sheetCtx);
                            await provider.setSelectedDevice(id);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF4F46E5).withValues(alpha: 0.12)
                                  : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                              border: isSelected
                                  ? Border.all(
                                      color: const Color(0xFF4F46E5),
                                      width: 1.5)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF4F46E5)
                                        : colorScheme.surfaceContainerHigh,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.sensors_rounded,
                                    size: 18,
                                    color: isSelected
                                        ? Colors.white
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: isSelected
                                              ? const Color(0xFF4F46E5)
                                              : colorScheme.onSurface,
                                        ),
                                      ),
                                      Text(
                                        id,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle_rounded,
                                      color: Color(0xFF4F46E5), size: 20),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddDeviceDialog(BuildContext context, dynamic provider) {
    final deviceIdCtrl = TextEditingController();
    final secretCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    bool loading = false;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Добавить устройство'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: deviceIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Device ID (MAC)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: secretCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Secret',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Название (Зал, Спальня…)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: loading
                    ? null
                    : () async {
                        setDialogState(() => loading = true);
                        try {
                          await provider.registerDevice(
                            deviceId: deviceIdCtrl.text.trim(),
                            secret: secretCtrl.text.trim(),
                            name: nameCtrl.text.trim(),
                          );
                          if (ctx.mounted) Navigator.pop(dialogCtx);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Ошибка: $e')),
                            );
                          }
                        } finally {
                          setDialogState(() => loading = false);
                        }
                      },
                child: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Добавить'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showNotificationHistory(
      BuildContext context, ClimateProvider provider) {
    final notifications = provider.notificationLogs;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.62,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'event_history'.tr(),
                    style:
                        Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: notifications.isEmpty
                        ? Center(
                            child: Text(
                              'no_events'.tr(),
                              style: TextStyle(
                                  color: colorScheme.onSurfaceVariant),
                            ),
                          )
                        : ListView.separated(
                            itemCount: notifications.length,
                            separatorBuilder: (_, __) => Divider(
                              color:
                                  colorScheme.outlineVariant.withValues(alpha: 0.35),
                              height: 14,
                            ),
                            itemBuilder: (_, i) {
                              final log = notifications[i];
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.notifications_active_rounded,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          log.message,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.onSurface,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          log.formattedTime,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: colorScheme.onSurfaceVariant,
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// 🎨 CUSTOM PAINTER для спидометра
class GaugeArcPainter extends CustomPainter {
  final double percentage;
  final Color color;
  final double strokeWidth;

  GaugeArcPainter({
    required this.percentage,
    required this.color,
    this.strokeWidth = 10,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const startAngle = math.pi * 0.75; // 135 degrees
    final sweepAngle = math.pi * 1.5 * percentage; // Max 270 degrees

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(GaugeArcPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
