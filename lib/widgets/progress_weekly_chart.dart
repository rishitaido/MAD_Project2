import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/workout_model.dart';

class ProgressWeeklyChart extends StatelessWidget {
  final List<WorkoutModel> workouts;

  const ProgressWeeklyChart({
    super.key,
    required this.workouts,
  });

  @override
  Widget build(BuildContext context) {
    final weekData = _getWeekData();
    final maxValue =
        weekData.values.reduce((a, b) => a > b ? a : b); // max count in week
    final maxY = (maxValue == 0 ? 1 : maxValue + 1).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                final index = value.toInt();
                if (index < 0 || index >= days.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  days[index],
                  style: const TextStyle(fontSize: 12),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: weekData.entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.toDouble(),
                color: Theme.of(context).colorScheme.primary,
                width: 20,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Map<int, int> _getWeekData() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    final data = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};

    for (var workout in workouts) {
      if (workout.date.isAfter(weekStart)) {
        final day = workout.date.weekday - 1;
        data[day] = (data[day] ?? 0) + 1;
      }
    }

    return data;
  }
}
