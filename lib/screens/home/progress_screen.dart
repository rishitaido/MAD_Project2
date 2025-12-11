import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/workout_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';

// Local widgets
import '/widgets/progress_stat_card.dart';
import '/widgets/progress_weekly_chart.dart';
import '/widgets/progress_exercise_breakdown.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final userId = authService.currentUser?.uid ?? '';
    final dbService = DatabaseService();

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
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Data Yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start logging workouts to see your progress',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // Precomputed stats
          final totalWorkouts = workouts.length;
          final totalMinutes =
              workouts.fold<int>(0, (sum, w) => sum + w.duration);
          final totalExercises = workouts.fold<int>(
            0,
            (sum, w) => sum + w.exercises.length,
          );
          final thisWeekCount = _getThisWeekCount(workouts);

          // Personal Record (heaviest lift)
          final pr = _findHeaviestLift(workouts);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary card row
                Row(
                  children: [
                    Expanded(
                      child: ProgressStatCard(
                        icon: Icons.fitness_center,
                        label: 'Total Workouts',
                        value: totalWorkouts.toString(),
                        subtitle:
                            '${totalMinutes} min • $totalExercises exercises',
                        color: Colors.blue,
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

                // Personal Record row
                Row(
                  children: [
                    Expanded(
                      child: ProgressStatCard(
                        icon: Icons.military_tech,
                        label: 'Heaviest Lift',
                        value: pr != null
                            ? _formatWeightValue(pr.weight)
                            : '--',
                        subtitle: pr != null
                            ? pr.exerciseName
                            : 'Log weighted exercises to unlock PRs',
                        color: Colors.purple,
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
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ProgressWeeklyChart(workouts: workouts),
                ),
                const SizedBox(height: 24),

                // Exercise breakdown
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
                        color: Colors.grey[400],
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
                    'Swipe to delete. Editing will open the workout editor screen.',
                    style: TextStyle(
                      color: Colors.grey[600],
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
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(
                                              color: Colors.redAccent),
                                        ),
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
                              trailing: IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () {
                                  // TODO: hook into Add/Edit workout screen
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Workout editing will be handled in the workout editor screen.',
                                      ),
                                    ),
                                  );
                                },
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
                        color: Colors.grey[400],
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
                      color: Colors.grey[600],
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${_formatWeightValue(pr.weight)} • '
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
        final w = exercise.weight;
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
      List<WorkoutModel> workouts) {
    final Map<String, _ExercisePR> prs = {};

    for (final workout in workouts) {
      for (final exercise in workout.exercises) {
        final w = exercise.weight;
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
      ..sort((a, b) => b.weight.compareTo(a.weight)); // heaviest first
    return list;
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$month/$day/$year';
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
