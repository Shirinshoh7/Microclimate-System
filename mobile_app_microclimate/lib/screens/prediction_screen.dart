import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/climate_provider.dart';
import 'package:fl_chart/fl_chart.dart';

enum _TrendMetric { temperature, humidity, co2, co }

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  _TrendMetric _selectedMetric = _TrendMetric.temperature;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 32),
              _buildPredictionCard(context),
              const SizedBox(height: 24),
              _buildForecastChart(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'prediction'.tr(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'climate_forecast'.tr(),
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionCard(BuildContext context) {
    return Consumer<ClimateProvider>(
      builder: (context, provider, _) {
        final currentData = provider.currentData;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF312E81),
                Color(0xFF1E293B),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 49, 46, 129).withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedHorizonLabel().toUpperCase(),
                    style: TextStyle(
                      color: Colors.indigo[200],
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                  _buildCardHorizonPicker(provider),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                '${_selectedMetricLabel(context)} • ${_selectedHorizonLabel()}',
                style: TextStyle(
                  color: Colors.indigo[200],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              if (_selectedPrediction(provider) != null && currentData != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedPrediction(provider)!.toStringAsFixed(_valuePrecision())}${_metricUnit()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 72,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildParameterRow(
                      context,
                      'temperature'.tr(),
                      '${currentData.temp.toStringAsFixed(1)}°C',
                      Icons.thermostat_rounded,
                      Colors.red[300]!,
                      metric: _TrendMetric.temperature,
                    ),
                    const SizedBox(height: 12),
                    _buildParameterRow(
                      context,
                      'humidity'.tr(),
                      '${currentData.humidity.toStringAsFixed(0)}%',
                      Icons.water_drop_rounded,
                      Colors.blue[300]!,
                      metric: _TrendMetric.humidity,
                    ),
                    const SizedBox(height: 12),
                    _buildParameterRow(
                      context,
                      'co2'.tr(),
                      '${currentData.co2.toStringAsFixed(0)} ppm',
                      Icons.air_rounded,
                      Colors.green[300]!,
                      metric: _TrendMetric.co2,
                    ),
                    const SizedBox(height: 12),
                    _buildParameterRow(
                      context,
                      'co'.tr(),
                      '${currentData.co.toStringAsFixed(0)} ppm',
                      Icons.air_rounded,
                      Colors.deepOrange[300]!,
                      metric: _TrendMetric.co,
                    ),
                    const SizedBox(height: 12),
                  ],
                )
              else
                Column(
                  children: [
                    const Text(
                      '--.-°C',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 72,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'loading_data'.tr(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.indigo[300],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _buildAiComment(provider),
                        style: TextStyle(
                          color: Colors.indigo[300],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (currentData != null && _selectedPrediction(provider) != null)
                _buildPredictionDetails(context, provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildParameterRow(BuildContext context, String label, String value,
      IconData icon, Color color,
      {required _TrendMetric metric}) {
    final isSelected = _selectedMetric == metric;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? color.withOpacity(0.18)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? color.withOpacity(0.9)
              : Colors.white.withOpacity(0.1),
          width: isSelected ? 1.4 : 1,
        ),
      ),
      child: GestureDetector(
        onTap: () => setState(() => _selectedMetric = metric),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardHorizonPicker(ClimateProvider provider) {
    const horizons = [('30M', '30m'), ('3H', '3h'), ('24H', '24h')];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: horizons.map((h) {
          final isActive = provider.forecastHorizon == h.$2;
          return GestureDetector(
            onTap: () {
              provider.setForecastHorizon(h.$2);
              setState(() {});
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.indigo[400]
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                h.$1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildForecastButtons(BuildContext context, ClimateProvider provider) {
    return Row(
      children: [
        _buildForecastButton('30M', '30m', provider),
        const SizedBox(width: 4),
        _buildForecastButton('3H', '3h', provider),
        const SizedBox(width: 4),
        _buildForecastButton('24H', '24h', provider),
      ],
    );
  }

  String _buildAiComment(ClimateProvider provider) {
    final predicted = _selectedPrediction(provider);
    final current = _selectedCurrent(provider);
    if (predicted == null || current == null) {
      return 'ai_comment_unavailable'.tr();
    }

    final horizonLabel = _horizonLabel(provider.forecastHorizon);
    final delta = predicted - current;
    final absDelta = delta.abs();

    if (absDelta < _changeThreshold()) {
      return 'ai_comment_stable_metric'.tr(namedArgs: {
        'horizon': horizonLabel,
        'metric': _selectedMetricLabel(context).toLowerCase(),
        'value': predicted.toStringAsFixed(_valuePrecision()),
        'unit': _metricUnit().trim(),
      });
    }

    if (delta > 0) {
      return 'ai_comment_rise_metric'.tr(namedArgs: {
        'horizon': horizonLabel,
        'metric': _selectedMetricLabel(context).toLowerCase(),
        'delta': absDelta.toStringAsFixed(_valuePrecision()),
        'value': predicted.toStringAsFixed(_valuePrecision()),
        'unit': _metricUnit().trim(),
      });
    }

    return 'ai_comment_drop_metric'.tr(namedArgs: {
      'horizon': horizonLabel,
      'metric': _selectedMetricLabel(context).toLowerCase(),
      'delta': absDelta.toStringAsFixed(_valuePrecision()),
      'value': predicted.toStringAsFixed(_valuePrecision()),
      'unit': _metricUnit().trim(),
    });
  }

  String _horizonLabel(String horizon) {
    switch (horizon) {
      case '1h':
        return 'horizon_1h'.tr();
      case '3h':
        return 'horizon_3h'.tr();
      case '24h':
        return 'horizon_24h'.tr();
      case '30m':
      default:
        return 'horizon_30m'.tr();
    }
  }

  double? _selectedPrediction(ClimateProvider provider) {
    final p = provider.predictions ?? provider.currentData?.predictions;
    if (p == null) return null;
    switch (_selectedMetric) {
      case _TrendMetric.temperature:
        return p.temperature;
      case _TrendMetric.humidity:
        return p.humidity;
      case _TrendMetric.co2:
        return p.co2;
      case _TrendMetric.co:
        return p.co;
    }
  }

  double? _selectedCurrent(ClimateProvider provider) {
    final c = provider.currentData;
    if (c == null) return null;
    switch (_selectedMetric) {
      case _TrendMetric.temperature:
        return c.temp;
      case _TrendMetric.humidity:
        return c.humidity;
      case _TrendMetric.co2:
        return c.co2;
      case _TrendMetric.co:
        return c.co;
    }
  }

  List<FlSpot> _buildForecastSpots(ClimateProvider provider) {
    final current = _selectedCurrent(provider);
    final predicted = _selectedPrediction(provider);
    if (current == null || predicted == null) return const [];

    final totalMin = _horizonMinutes();
    const points = 12;
    final spots = <FlSpot>[];
    for (var i = 0; i <= points; i++) {
      final t = i / points;
      final x = totalMin * t;
      final y = current + (predicted - current) * t;
      spots.add(FlSpot(x.toDouble(), y));
    }
    return spots;
  }

  int _horizonMinutes() {
    switch (_selectedHorizon()) {
      case '1h':
        return 60;
      case '3h':
        return 180;
      case '24h':
        return 1440;
      case '30m':
      default:
        return 30;
    }
  }

  String _selectedHorizon() {
    return context.read<ClimateProvider>().forecastHorizon;
  }

  String _selectedHorizonLabel() {
    switch (_selectedHorizon()) {
      case '1h':
        return '1H';
      case '3h':
        return '3H';
      case '24h':
        return '24H';
      case '30m':
      default:
        return '30M';
    }
  }

  double _xInterval() {
    final mins = _horizonMinutes();
    if (mins <= 60) return 15;
    if (mins <= 240) return 60;
    if (mins <= 1440) return 240;
    return 1440; // 7d — отметка каждый день
  }

  String _formatTimeTick(double value) {
    final mins = value.round();
    if (_horizonMinutes() >= 10080) {
      final d = mins ~/ 1440;
      return '${d}d';
    }
    if (_horizonMinutes() >= 60) {
      final h = mins ~/ 60;
      return '${h}h';
    }
    return '${mins}m';
  }

  String _metricUnit() {
    switch (_selectedMetric) {
      case _TrendMetric.temperature:
        return '°C';
      case _TrendMetric.humidity:
        return '%';
      case _TrendMetric.co2:
        return ' ppm';
      case _TrendMetric.co:
        return ' ppm';
    }
  }

  int _valuePrecision() {
    switch (_selectedMetric) {
      case _TrendMetric.temperature:
        return 1;
      case _TrendMetric.humidity:
      case _TrendMetric.co2:
      case _TrendMetric.co:
        return 0;
    }
  }

  double _changeThreshold() {
    switch (_selectedMetric) {
      case _TrendMetric.temperature:
        return 0.5;
      case _TrendMetric.humidity:
        return 2;
      case _TrendMetric.co2:
        return 50;
      case _TrendMetric.co:
        return 5;
    }
  }

  String _formatAxisValue(double value) {
    return value.toStringAsFixed(_valuePrecision());
  }

  Widget _buildForecastButton(
    String label,
    String horizon,
    ClimateProvider provider,
  ) {
    final isActive = provider.forecastHorizon == horizon;
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          provider.setForecastHorizon(horizon);
          setState(() {});
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF4F46E5)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionDetails(
      BuildContext context, ClimateProvider provider) {
    return Column(
      children: [
        _buildDetailRow(
          'current'.tr(),
          '${_selectedCurrent(provider)!.toStringAsFixed(_valuePrecision())}${_metricUnit()}',
          Colors.white70,
        ),
        const SizedBox(height: 12),
        if (_selectedPrediction(provider) != null)
          _buildDetailRow(
            'change'.tr(),
            _getPredictionChange(provider),
            _getPredictionChangeColor(provider),
          ),
        const SizedBox(height: 12),
        _buildDetailRow(
          'model_accuracy'.tr(),
          'Метод Хольта — экспоненц. сглаживание',
          Colors.green[300]!,
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getPredictionChange(ClimateProvider provider) {
    final predicted = _selectedPrediction(provider);
    final current = _selectedCurrent(provider);
    if (predicted == null || current == null) {
      return '—';
    }
    final change = predicted - current;
    final sign = change >= 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(_valuePrecision())}${_metricUnit()}';
  }

  Color _getPredictionChangeColor(ClimateProvider provider) {
    final predicted = _selectedPrediction(provider);
    final current = _selectedCurrent(provider);
    if (predicted == null || current == null) {
      return Colors.white70;
    }
    final change = predicted - current;
    final threshold = _changeThreshold();
    if (change > threshold) return Colors.red[300]!;
    if (change < -threshold) return Colors.blue[300]!;
    return Colors.green[300]!;
  }

  Widget _buildForecastChart(BuildContext context) {
    return Consumer<ClimateProvider>(
      builder: (context, provider, _) {
        final colorScheme = Theme.of(context).colorScheme;
        final hasForecastData =
            _selectedCurrent(provider) != null && _selectedPrediction(provider) != null;
        if (!hasForecastData) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.show_chart_rounded,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.55),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'no_history_data'.tr(),
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedMetricLabel(context),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: colorScheme.outlineVariant.withOpacity(0.45),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              _formatAxisValue(value),
                              style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            );
                          },
                          reservedSize: 32,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: _xInterval(),
                          getTitlesWidget: (value, meta) {
                            if (value < 0 ||
                                value > _horizonMinutes().toDouble()) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _formatTimeTick(value),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(
                        color: colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _buildForecastSpots(provider),
                        isCurved: true,
                        color: _selectedMetricColor(_selectedMetric),
                        barWidth: 3,
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              _selectedMetricColor(_selectedMetric)
                                  .withOpacity(0.3),
                              _selectedMetricColor(_selectedMetric)
                                  .withOpacity(0.05),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 2,
                              color: colorScheme.surface,
                              strokeWidth: 2,
                              strokeColor:
                                  _selectedMetricColor(_selectedMetric),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _selectedMetricColor(_selectedMetric),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedMetricLabel(context),
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildForecastButtons(context, provider),
            ],
          ),
        );
      },
    );
  }

  Color _selectedMetricColor(_TrendMetric metric) {
    switch (metric) {
      case _TrendMetric.temperature:
        return Colors.redAccent;
      case _TrendMetric.humidity:
        return Colors.blueAccent;
      case _TrendMetric.co2:
        return Colors.green;
      case _TrendMetric.co:
        return Colors.deepOrange;
    }
  }

  String _selectedMetricLabel(BuildContext context) {
    switch (_selectedMetric) {
      case _TrendMetric.temperature:
        return 'temperature'.tr();
      case _TrendMetric.humidity:
        return 'humidity'.tr();
      case _TrendMetric.co2:
        return 'co2'.tr();
      case _TrendMetric.co:
        return 'co'.tr();
    }
  }
}
