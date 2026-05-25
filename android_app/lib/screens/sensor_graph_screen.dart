import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/screen_utils.dart';

/// Time range options for graph
enum TimeRange {
  tenMin(hours: 0, minutes: 10, label: '10 Minutes', shortLabel: '10M'),
  hourly(hours: 1, minutes: 60, label: '1 Hour', shortLabel: '1H'),
  daily(hours: 24, minutes: 1440, label: '24 Hours', shortLabel: '24H'),
  weekly(hours: 168, minutes: 10080, label: '7 Days', shortLabel: '7D'),
  monthly(hours: 720, minutes: 43200, label: '30 Days', shortLabel: '30D');

  final int hours;
  final int minutes;
  final String label;
  final String shortLabel;
  const TimeRange({required this.hours, required this.minutes, required this.label, required this.shortLabel});
  
  /// Get hours for API call (minimum 1 hour)
  int get apiHours => hours > 0 ? hours : 1;
}

/// Sensor type for graph display
enum SensorType {
  temperature(label: 'Temperature', unit: '°C', icon: Icons.thermostat_rounded),
  humidity(label: 'Humidity', unit: '%', icon: Icons.water_drop_rounded);

  final String label;
  final String unit;
  final IconData icon;
  const SensorType({required this.label, required this.unit, required this.icon});
}

/// Sensor Graph Screen - Shows temperature and humidity history from MongoDB
class SensorGraphScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const SensorGraphScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<SensorGraphScreen> createState() => _SensorGraphScreenState();
}

class _SensorGraphScreenState extends State<SensorGraphScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  
  TimeRange _selectedTimeRange = TimeRange.daily;
  SensorType _selectedSensorType = SensorType.temperature;
  
  List<TelemetryDataPoint> _dataPoints = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Restore session first
      await _apiService.restoreSession();
      
      final data = await _apiService.getTelemetryHistory(
        widget.deviceId,
        hours: _selectedTimeRange.apiHours,
        limit: _selectedTimeRange == TimeRange.monthly ? 2000 : 1000,
      );

      // Filter data based on selected time range
      final now = DateTime.now();
      final cutoff = now.subtract(Duration(minutes: _selectedTimeRange.minutes));
      final filteredData = data.where((point) => point.timestamp.isAfter(cutoff)).toList();

      if (mounted) {
        setState(() {
          _dataPoints = filteredData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load data: $e';
          _isLoading = false;
        });
      }
    }
  }

  Color get _sensorColor => _selectedSensorType == SensorType.temperature
      ? AppTheme.temperature
      : AppTheme.humidity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.deviceName,
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 16),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Historical Data',
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 12),
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Time Range Selector
          _TimeRangeSelector(
            selected: _selectedTimeRange,
            onChanged: (range) {
              setState(() => _selectedTimeRange = range);
              _loadData();
            },
          ),
          
          // Sensor Type Selector
          _SensorTypeSelector(
            selected: _selectedSensorType,
            onChanged: (type) => setState(() => _selectedSensorType = type),
          ),
          
          // Content
          Expanded(
            child: _isLoading
                ? _LoadingView(color: _sensorColor)
                : _errorMessage != null
                    ? _ErrorView(message: _errorMessage!, onRetry: _loadData)
                    : _dataPoints.isEmpty
                        ? _EmptyView(timeRange: _selectedTimeRange)
                        : _GraphContent(
                            dataPoints: _dataPoints,
                            sensorType: _selectedSensorType,
                            timeRange: _selectedTimeRange,
                            color: _sensorColor,
                          ),
          ),
        ],
      ),
    );
  }
}

class _TimeRangeSelector extends StatelessWidget {
  final TimeRange selected;
  final ValueChanged<TimeRange> onChanged;

  const _TimeRangeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = ScreenUtils.getPadding(context, 16);

    return Container(
      color: isDark ? AppTheme.darkSurface : Colors.white,
      padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
      child: Container(
        padding: EdgeInsets.all(ScreenUtils.getPadding(context, 4)),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
        ),
        child: Row(
          children: TimeRange.values.map((range) {
            final isSelected = range == selected;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(range),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    vertical: ScreenUtils.getSpacing(context, 12),
                    horizontal: ScreenUtils.getPadding(context, 4),
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.lightPrimary : Colors.transparent,
                    borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 10)),
                  ),
                  child: Text(
                    range.shortLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: ScreenUtils.getFontSize(context, 12),
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SensorTypeSelector extends StatelessWidget {
  final SensorType selected;
  final ValueChanged<SensorType> onChanged;

  const _SensorTypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = ScreenUtils.getPadding(context, 16);

    return Container(
      padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
      child: Row(
        children: SensorType.values.map((type) {
          final isSelected = type == selected;
          final color = type == SensorType.temperature
              ? AppTheme.temperature
              : AppTheme.humidity;

          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.symmetric(horizontal: ScreenUtils.getPadding(context, 4)),
                padding: EdgeInsets.all(ScreenUtils.getPadding(context, 14)),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.15)
                      : (isDark ? AppTheme.darkSurface : Colors.white),
                  borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 14)),
                  border: Border.all(
                    color: isSelected ? color : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 8)]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(type.icon, color: color, size: 20),
                    SizedBox(width: ScreenUtils.getPadding(context, 8)),
                    Text(
                      type.label,
                      style: TextStyle(
                        fontSize: ScreenUtils.getFontSize(context, 14),
                        fontWeight: FontWeight.w600,
                        color: isSelected ? color : (isDark ? Colors.white70 : Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  final Color color;

  const _LoadingView({required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          SizedBox(height: ScreenUtils.getSpacing(context, 16)),
          Text(
            'Loading historical data...',
            style: TextStyle(
              fontSize: ScreenUtils.getFontSize(context, 14),
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white60
                  : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(ScreenUtils.getPadding(context, 32)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppTheme.error,
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 16)),
            Text(
              'Failed to Load Data',
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 18),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 8)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 12),
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white60
                    : Colors.black54,
              ),
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 24)),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final TimeRange timeRange;

  const _EmptyView({required this.timeRange});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart_rounded,
            size: 64,
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          SizedBox(height: ScreenUtils.getSpacing(context, 16)),
          Text(
            'No Data Available',
            style: TextStyle(
              fontSize: ScreenUtils.getFontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          SizedBox(height: ScreenUtils.getSpacing(context, 8)),
          Text(
            'No telemetry data found for\n${timeRange.label}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ScreenUtils.getFontSize(context, 13),
              color: isDark ? Colors.white54 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}

class _GraphContent extends StatelessWidget {
  final List<TelemetryDataPoint> dataPoints;
  final SensorType sensorType;
  final TimeRange timeRange;
  final Color color;

  const _GraphContent({
    required this.dataPoints,
    required this.sensorType,
    required this.timeRange,
    required this.color,
  });

  List<double> get _values {
    return dataPoints
        .map((p) => sensorType == SensorType.temperature ? p.temp : p.hum)
        .where((v) => v != null)
        .cast<double>()
        .toList();
  }

  double? get _currentValue => _values.isNotEmpty ? _values.last : null;
  double? get _minValue => _values.isNotEmpty ? _values.reduce((a, b) => a < b ? a : b) : null;
  double? get _maxValue => _values.isNotEmpty ? _values.reduce((a, b) => a > b ? a : b) : null;
  double? get _avgValue => _values.isNotEmpty ? _values.reduce((a, b) => a + b) / _values.length : null;

  @override
  Widget build(BuildContext context) {
    final padding = ScreenUtils.getPadding(context, 16);

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        children: [
          // Current Value Card
          _CurrentValueCard(
            value: _currentValue,
            sensorType: sensorType,
            color: color,
            dataCount: dataPoints.length,
          ),
          SizedBox(height: ScreenUtils.getSpacing(context, 16)),

          // Graph Card
          _ChartCard(
            dataPoints: dataPoints,
            sensorType: sensorType,
            timeRange: timeRange,
            color: color,
          ),
          SizedBox(height: ScreenUtils.getSpacing(context, 16)),

          // Statistics Card
          _StatsCard(
            minValue: _minValue,
            maxValue: _maxValue,
            avgValue: _avgValue,
            sensorType: sensorType,
            color: color,
          ),
        ],
      ),
    );
  }
}

class _CurrentValueCard extends StatelessWidget {
  final double? value;
  final SensorType sensorType;
  final Color color;
  final int dataCount;

  const _CurrentValueCard({
    required this.value,
    required this.sensorType,
    required this.color,
    required this.dataCount,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = ScreenUtils.getBorderRadius(context, 20);

    return Container(
      padding: EdgeInsets.all(ScreenUtils.getPadding(context, 24)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.8), color.withOpacity(0.6)],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(ScreenUtils.getPadding(context, 16)),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              sensorType.icon,
              color: Colors.white,
              size: ScreenUtils.getIconSize(context, 32),
            ),
          ),
          SizedBox(width: ScreenUtils.getPadding(context, 20)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Latest ${sensorType.label}',
                  style: TextStyle(
                    fontSize: ScreenUtils.getFontSize(context, 14),
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                SizedBox(height: ScreenUtils.getSpacing(context, 4)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value?.toStringAsFixed(1) ?? '--',
                      style: TextStyle(
                        fontSize: ScreenUtils.getFontSize(context, 42),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        left: ScreenUtils.getPadding(context, 4),
                        bottom: ScreenUtils.getSpacing(context, 6),
                      ),
                      child: Text(
                        sensorType.unit,
                        style: TextStyle(
                          fontSize: ScreenUtils.getFontSize(context, 18),
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ScreenUtils.getPadding(context, 12),
              vertical: ScreenUtils.getSpacing(context, 6),
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$dataCount pts',
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 10),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final List<TelemetryDataPoint> dataPoints;
  final SensorType sensorType;
  final TimeRange timeRange;
  final Color color;

  const _ChartCard({
    required this.dataPoints,
    required this.sensorType,
    required this.timeRange,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = ScreenUtils.getPadding(context, 16);

    // Create chart spots
    final spots = <FlSpot>[];
    for (int i = 0; i < dataPoints.length; i++) {
      final value = sensorType == SensorType.temperature
          ? dataPoints[i].temp
          : dataPoints[i].hum;
      if (value != null) {
        spots.add(FlSpot(i.toDouble(), value));
      }
    }

    // Calculate Y range
    final values = spots.map((s) => s.y).toList();
    double minY = 0, maxY = 100;
    if (values.isNotEmpty) {
      final dataMin = values.reduce((a, b) => a < b ? a : b);
      final dataMax = values.reduce((a, b) => a > b ? a : b);
      final padding = (dataMax - dataMin) * 0.1;
      minY = (dataMin - padding).floorToDouble();
      maxY = (dataMax + padding).ceilToDouble();
      // Ensure reasonable range
      if (sensorType == SensorType.temperature) {
        minY = max(0, minY);
        maxY = min(50, maxY);
      } else {
        minY = max(0, minY);
        maxY = min(100, maxY);
      }
    }

    return Container(
      height: 280,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 20)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, color: color, size: 20),
              SizedBox(width: ScreenUtils.getPadding(context, 8)),
              Text(
                '${timeRange.label} Trend',
                style: TextStyle(
                  fontSize: ScreenUtils.getFontSize(context, 14),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ScreenUtils.getPadding(context, 10),
                  vertical: ScreenUtils.getSpacing(context, 4),
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  timeRange.label,
                  style: TextStyle(
                    fontSize: ScreenUtils.getFontSize(context, 11),
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ScreenUtils.getSpacing(context, 16)),
          Expanded(
            child: spots.length < 2
                ? Center(
                    child: Text(
                      'Not enough data points',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black38,
                      ),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: (maxY - minY) / 5,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: isDark ? Colors.white12 : Colors.black12,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: (maxY - minY) / 5,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}${sensorType.unit}',
                                style: TextStyle(
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: max(1, (spots.length / 5).floor()).toDouble(),
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= dataPoints.length) {
                                return const SizedBox();
                              }
                              final time = dataPoints[index].timestamp;
                              String label;
                              if (timeRange == TimeRange.tenMin || timeRange == TimeRange.hourly) {
                                // Show minutes:seconds for short ranges
                                label = '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
                              } else if (timeRange == TimeRange.daily) {
                                label = '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
                              } else if (timeRange == TimeRange.weekly) {
                                label = '${time.day}/${time.month}';
                              } else {
                                label = '${time.day}/${time.month}';
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: isDark ? Colors.white38 : Colors.black38,
                                    fontSize: 9,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: (spots.length - 1).toDouble(),
                      minY: minY,
                      maxY: maxY,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.2,
                          color: color,
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: spots.length < 50,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 3,
                                color: Colors.white,
                                strokeWidth: 1.5,
                                strokeColor: color,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                color.withOpacity(0.3),
                                color.withOpacity(0.05),
                              ],
                            ),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (touchedSpot) =>
                              isDark ? Colors.white : Colors.black87,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final index = spot.spotIndex;
                              if (index >= dataPoints.length) return null;
                              final time = dataPoints[index].timestamp;
                              final timeStr = '${time.day}/${time.month} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
                              return LineTooltipItem(
                                '${spot.y.toStringAsFixed(1)}${sensorType.unit}\n$timeStr',
                                TextStyle(
                                  color: isDark ? Colors.black87 : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final double? minValue;
  final double? maxValue;
  final double? avgValue;
  final SensorType sensorType;
  final Color color;

  const _StatsCard({
    required this.minValue,
    required this.maxValue,
    required this.avgValue,
    required this.sensorType,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = ScreenUtils.getPadding(context, 16);

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 16)),
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
          Row(
            children: [
              Icon(Icons.analytics_rounded, color: color, size: 20),
              SizedBox(width: ScreenUtils.getPadding(context, 8)),
              Text(
                'Statistics',
                style: TextStyle(
                  fontSize: ScreenUtils.getFontSize(context, 14),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: ScreenUtils.getSpacing(context, 16)),
          Row(
            children: [
              _StatItem(
                label: 'MIN',
                value: minValue?.toStringAsFixed(1) ?? '--',
                unit: sensorType.unit,
                color: Colors.blue,
                icon: Icons.arrow_downward_rounded,
              ),
              _StatItem(
                label: 'AVG',
                value: avgValue?.toStringAsFixed(1) ?? '--',
                unit: sensorType.unit,
                color: color,
                icon: Icons.remove_rounded,
              ),
              _StatItem(
                label: 'MAX',
                value: maxValue?.toStringAsFixed(1) ?? '--',
                unit: sensorType.unit,
                color: Colors.red,
                icon: Icons.arrow_upward_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: ScreenUtils.getPadding(context, 4)),
        padding: EdgeInsets.all(ScreenUtils.getPadding(context, 12)),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 14),
                SizedBox(width: ScreenUtils.getPadding(context, 4)),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: ScreenUtils.getFontSize(context, 10),
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 8)),
            Text(
              value,
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 20),
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 11),
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
