import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

class ChartPoint {
  ChartPoint(this.time, this.value);
  final DateTime time;
  final double value;
}

class HistoryLineChart extends StatelessWidget {
  const HistoryLineChart({
    super.key,
    required this.points,
    required this.label,
  });

  final List<ChartPoint> points;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(
        child: Text(
          'Sin datos',
          style: TextStyle(color: MinerColors.text),
        ),
      );
    }

    final minX = 0.0;
    final maxX = (points.length - 1).toDouble();
    final ys = points.map((e) => e.value).toList();
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY).abs() * 0.12;
    final chartMinY = minY - pad;
    final chartMaxY = maxY + pad;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: MinerColors.text,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: chartMinY.isFinite ? chartMinY : null,
                  maxY: chartMaxY.isFinite ? chartMaxY : null,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: MinerColors.border.withValues(alpha: 0.35),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (v, meta) => Text(
                          v.toStringAsFixed(1),
                          style: TextStyle(
                            color: MinerColors.text.withValues(alpha: 0.75),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: (points.length / 4).clamp(1, 999).toDouble(),
                        getTitlesWidget: (v, meta) {
                          final idx = v.round().clamp(0, points.length - 1);
                          final t = points[idx].time;
                          final hh = t.hour.toString().padLeft(2, '0');
                          final mm = t.minute.toString().padLeft(2, '0');
                          return Text(
                            '$hh:$mm',
                            style: TextStyle(
                              color: MinerColors.text.withValues(alpha: 0.75),
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      color: MinerColors.accent,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: MinerColors.accent.withValues(alpha: 0.18),
                      ),
                      spots: [
                        for (var i = 0; i < points.length; i++)
                          FlSpot(i.toDouble(), points[i].value),
                      ],
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipRoundedRadius: 10,
                      getTooltipColor: (_) => MinerColors.sidebar,
                      getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                        final idx = s.x.round().clamp(0, points.length - 1);
                        final t = points[idx].time;
                        final hh = t.hour.toString().padLeft(2, '0');
                        final mm = t.minute.toString().padLeft(2, '0');
                        return LineTooltipItem(
                          '$hh:$mm\n${s.y.toStringAsFixed(2)}',
                          const TextStyle(
                            color: MinerColors.text,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

