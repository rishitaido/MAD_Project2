import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/workout_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../widgets/progress_exercise_breakdown.dart';
import '../home/log_workout_screen.dart'; 

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final userId = authService.currentUser?.uid ?? '';
    final dbService = DatabaseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
      ),
      body: StreamBuilder<List<WorkoutModel>>(
        stream: dbService.getUserWorkouts(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final workouts = snapshot.data ?? [];

          if (workouts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.insights_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Data Yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start logging workouts to see your progress',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          // Pre-computed stats
          final totalWorkouts = workouts.length;
          final totalMinutes =
              workouts.fold<int>(0, (sum, w) => sum + w.duration);
          final totalExercises = workouts.fold<int>(
            0,
            (sum, w) => sum + w.exercises.length,
          );
          final thisWeekCount = _getThisWeekCount(workouts);
          final pr = _findHeaviestLift(workouts);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary card row (Total Workouts + condensed stats)
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.fitness_center,
                        label: 'Total Workouts',
                        value: totalWorkouts.toString(),
                        color: Colors.blue,
                        subtitle:
                            '${totalMinutes} min • $totalExercises exercises',
                        onTap: () => _showWorkoutHistorySheet(
                          context,
                          workouts,
                          dbService,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Personal Record (Heaviest Lift)
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.military_tech,
                        label: 'Heaviest Lift',
                        value:
                            pr != null ? _formatWeightValue(pr.weight) : '--',
                        color: Colors.purple,
                        subtitle: pr != null
                            ? pr.exerciseName
                            : 'Log weighted exercises to unlock PRs',
                        onTap: pr == null
                            ? null
                            : () => _showPRSheet(context, workouts),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Weekly Activity header + inline "this week" pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Weekly Activity',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    _ThisWeekPill(count: thisWeekCount),
                  ],
                ),
                const SizedBox(height: 16),

                // Weekly chart
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                        : Theme.of(context)
                            .colorScheme
                            .surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _WeeklyChart(workouts: workouts),
                ),
                const SizedBox(height: 24),

                // Exercise breakdown (now using shared widget)
                Text(
                  'Top Exercises',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ProgressExerciseBreakdown(workouts: workouts),
              ],
            ),
          );
        },
      ),
    );
  }

  int _getThisWeekCount(List<WorkoutModel> workouts) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return workouts.where((w) => w.date.isAfter(weekStart)).length;
  }

  void _showWorkoutHistorySheet(
    BuildContext context,
    List<WorkoutModel> workouts,
    DatabaseService dbService,
  ) {
    final sorted = [...workouts]..sort((a, b) => b.date.compareTo(a.date));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Text(
                    'Workout History',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap a workout to view actions. Swipe left to quickly delete.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: sorted.length,
                      itemBuilder: (context, index) {
                        final workout = sorted[index];
                        final exerciseCount = workout.exercises.length;

                        return Dismissible(
                          key: ValueKey(workout.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.red[400],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (_) async {
                            final shouldDelete = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogCtx) => AlertDialog(
                                    title: const Text('Delete workout?'),
                                    content: const Text(
                                      'This action cannot be undone.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dialogCtx).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dialogCtx).pop(true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;
                            return shouldDelete;
                          },
                          onDismissed: (_) async {
                            await dbService.deleteWorkout(workout.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Workout deleted'),
                              ),
                            );
                          },
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                workout.title ?? 'Workout',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${_formatDate(workout.date)} • '
                                '${workout.duration} min • '
                                '$exerciseCount exercises',
                              ),
                              onTap: () => _showWorkoutActionsSheet(
                                context,
                                workout,
                                dbService,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showWorkoutActionsSheet(
    BuildContext context,
    WorkoutModel workout,
    DatabaseService dbService,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        final theme = Theme.of(sheetCtx);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(
                workout.title ?? 'Workout',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatDate(workout.date)} • '
                '${workout.duration} min • '
                '${workout.exercises.length} exercises',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetCtx).pop(); // close actions sheet
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LogWorkoutScreen(
                        existingWorkout: workout,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit workout'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dialogCtx) => AlertDialog(
                          title: const Text('Delete workout?'),
                          content: const Text(
                            'This will permanently remove this workout.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogCtx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogCtx).pop(true),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ) ??
                      false;

                  if (!confirm) return;

                  Navigator.of(sheetCtx).pop(); // close actions sheet

                  await dbService.deleteWorkout(workout.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Workout deleted')),
                  );
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete workout'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPRSheet(BuildContext context, List<WorkoutModel> workouts) {
    final prByExercise = _computePRsByExercise(workouts);
    if (prByExercise.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No weighted exercises logged yet.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Text(
                    'Personal Records',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Best weight per exercise (all time).',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: prByExercise.length,
                      itemBuilder: (context, index) {
                        final pr = prByExercise[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.military_tech),
                            title: Text(
                              pr.exerciseName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${_formatWeightValue(pr.weight)} lbs • '
                              'Set on ${_formatDate(pr.date)}',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static String _formatWeightValue(double weight) {
    if (weight % 1 == 0) {
      return weight.toInt().toString();
    }
    return weight.toStringAsFixed(1);
  }

  static _ExercisePR? _findHeaviestLift(List<WorkoutModel> workouts) {
    _ExercisePR? best;
    double maxWeight = 0;

    for (final workout in workouts) {
      for (final exercise in workout.exercises) {
        final w = double.tryParse(exercise.weight ?? '');
        if (w != null && w > maxWeight) {
          maxWeight = w;
          best = _ExercisePR(
            exerciseName: exercise.name,
            weight: w,
            date: workout.date,
          );
        }
      }
    }

    return best;
  }

  static List<_ExercisePR> _computePRsByExercise(
    List<WorkoutModel> workouts,
  ) {
    final Map<String, _ExercisePR> prs = {};

    for (final workout in workouts) {
      for (final exercise in workout.exercises) {
        final w = double.tryParse(exercise.weight ?? '');
        if (w == null || w <= 0) continue;

        final existing = prs[exercise.name];
        if (existing == null || w > existing.weight) {
          prs[exercise.name] = _ExercisePR(
            exerciseName: exercise.name,
            weight: w,
            date: workout.date,
          );
        }
      }
    }

    final list = prs.values.toList()
      ..sort((a, b) => b.weight.compareTo(a.weight));
    return list;
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$month/$day/$year';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: card,
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final List<WorkoutModel> workouts;

  const _WeeklyChart({required this.workouts});

  @override
  Widget build(BuildContext context) {
    final weekData = _getWeekData();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (weekData.values.reduce((a, b) => a > b ? a : b) + 1).toDouble(),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                return Text(
                  days[value.toInt()],
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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

class _ThisWeekPill extends StatelessWidget {
  final int count;

  const _ThisWeekPill({required this.count});

  @override
  Widget build(BuildContext context) {
    final hasStreak = count > 0;
    final text = hasStreak
        ? '$count workout${count == 1 ? '' : 's'} this week'
        : 'No workouts yet';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: hasStreak
            ? Colors.green.withOpacity(0.08)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: hasStreak
              ? Colors.green.withOpacity(0.25)
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department,
            size: 16,
            color: hasStreak ? Colors.green[700] : Colors.grey[600],
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: hasStreak ? Colors.green[800] : Colors.grey[700],
              fontWeight: hasStreak ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExercisePR {
  final String exerciseName;
  final double weight;
  final DateTime date;

  _ExercisePR({
    required this.exerciseName,
    required this.weight,
    required this.date,
  });
}
