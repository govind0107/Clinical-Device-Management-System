import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../providers/live_chart_provider.dart';
import '../theme/app_theme.dart';

class LiveTelemetryChart extends StatelessWidget {
  const LiveTelemetryChart({
    super.key,
    required this.channel,
    required this.points,
    required this.color,
  });

  final String channel;
  final List<TelemetryPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Center(child: Text('Waiting for $channel data...'));
    }

    final spots = <FlSpot>[];
    final base = points.first.timestamp.millisecondsSinceEpoch.toDouble();
    for (var i = 0; i < points.length; i++) {
      final x = (points[i].timestamp.millisecondsSinceEpoch - base) / 1000;
      spots.add(FlSpot(x, points[i].value));
    }

    final stats = LiveChartNotifier.stats(points);

    // Calculate clean, rounded bounds and intervals to eliminate decimal bounds and overlaps
    final double interval;
    final double minY;
    final double maxY;

    if (channel == 'SpO2') {
      interval = 5;
      minY = ((stats.min - 2) / interval).floorToDouble() * interval;
      maxY = ((stats.max + 2) / interval).ceilToDouble() * interval;
    } else if (channel == 'ECG') {
      interval = 20;
      minY = ((stats.min - 5) / interval).floorToDouble() * interval;
      maxY = ((stats.max + 5) / interval).ceilToDouble() * interval;
    } else {
      // BP
      interval = 20;
      minY = ((stats.min - 10) / interval).floorToDouble() * interval;
      maxY = ((stats.max + 10) / interval).ceilToDouble() * interval;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // left padding 48 offsets past the 40px leftTitles to align text with the start of the grid
          padding: const EdgeInsets.only(left: 48, right: 8),
          child: Row(
            children: [
              Text(
                channel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
              const Spacer(),
              _StatBadge('Min', stats.min.toStringAsFixed(1), color),
              const SizedBox(width: 8),
              _StatBadge('Avg', stats.avg.toStringAsFixed(1), color),
              const SizedBox(width: 8),
              _StatBadge('Max', stats.max.toStringAsFixed(1), color),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: interval,
                    getTitlesWidget: (value, meta) {
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 8,
                        child: Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: color,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color.withValues(alpha: 0.22),
                        color.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(milliseconds: 200),
          ),
        ),
      ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge(this.label, this.val, this.color);
  final String label;
  final String val;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Text(
        '$label: $val',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

final channelColors = {
  'ECG': AppTheme.clinicalRed,
  'SpO2': AppTheme.clinicalBlue,
  'BP': AppTheme.clinicalGreen,
};
