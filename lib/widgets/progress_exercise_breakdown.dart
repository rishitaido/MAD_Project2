import 'package:flutter/material.dart';
import '../models/workout_model.dart';

class ProgressExerciseBreakdown extends StatelessWidget {
  final List<WorkoutModel> workouts;

  const ProgressExerciseBreakdown({
    super.key,
    required this.workouts,
  });

  @override
  Widget build(BuildContext context) {
    final exerciseCounts = <String, int>{};
    final exerciseIsCardio = <String, bool>{};

    for (final workout in workouts) {
      for (final exercise in workout.exercises) {
        final name = exercise.name;

        exerciseCounts[name] = (exerciseCounts[name] ?? 0) + 1;

        // If we ever logged this exercise name as cardio, remember it
        if (exercise.isCardio) {
          exerciseIsCardio[name] = true;
        } else {
          exerciseIsCardio[name] = exerciseIsCardio[name] ?? false;
        }
      }
    }

    final sortedExercises = exerciseCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: sortedExercises.take(5).map((entry) {
        final name = entry.key;
        final count = entry.value;
        final isCardio = exerciseIsCardio[name] == true;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isCardio ? Icons.directions_run : Icons.fitness_center,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${count}x',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
