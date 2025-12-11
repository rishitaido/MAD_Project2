import 'package:flutter/material.dart';
import '../../../models/workout_model.dart';

class ProgressExerciseBreakdown extends StatelessWidget {
  final List<WorkoutModel> workouts;

  const ProgressExerciseBreakdown({
    super.key,
    required this.workouts,
  });

  @override
  Widget build(BuildContext context) {
    final exerciseCounts = <String, int>{};

    for (var workout in workouts) {
      for (var exercise in workout.exercises) {
        exerciseCounts[exercise.name] =
            (exerciseCounts[exercise.name] ?? 0) + 1;
      }
    }

    final sortedExercises = exerciseCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sortedExercises.take(5).map((entry) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
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
                  Icons.fitness_center,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  entry.key,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${entry.value}x',
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
