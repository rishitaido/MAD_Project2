import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/workout_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';

class LogWorkoutScreen extends StatefulWidget {
  const LogWorkoutScreen({super.key});

  @override
  State<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends State<LogWorkoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _captionController = TextEditingController();
  final List<Exercise> _exercises = [];
  bool _isLoading = false;
  String _visibility = 'public';

  // Controllers for new exercise
  final _exerciseNameController = TextEditingController();
  final _setsController = TextEditingController();
  final _repsController = TextEditingController();
  final _weightController = TextEditingController();

  @override
  void dispose() {
    _captionController.dispose();
    _exerciseNameController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _addExercise() {
    if (_exerciseNameController.text.isEmpty ||
        _setsController.text.isEmpty ||
        _repsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in exercise name, sets, and reps'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _exercises.add(Exercise(
        name: _exerciseNameController.text,
        sets: int.parse(_setsController.text),
        reps: int.parse(_repsController.text),
        weight: _weightController.text.isNotEmpty
            ? double.parse(_weightController.text)
            : null,
      ));

      // Clear fields
      _exerciseNameController.clear();
      _setsController.clear();
      _repsController.clear();
      _weightController.clear();
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
    });
  }

  Future<void> _saveWorkout() async {
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one exercise'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    // Update challenge progress
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (user == null) return;

      final dbService = DatabaseService();
      final userData = await dbService.getUserData(user.uid);

      // Calculate total duration (rough estimate)
      int totalDuration = _exercises.fold(
        0,
        (sum, exercise) => sum + (exercise.sets * 2), // 2 min per set estimate
      );

      // Create workout
      final workout = WorkoutModel(
        id: '',
        userId: user.uid,
        userName: userData?.name ?? 'User',
        userPhoto: userData?.profilePhoto,
        date: DateTime.now(),
        exercises: _exercises,
        duration: totalDuration,
        visibility: _visibility,
      );

      // Save workout and get the ID
      final workoutId = await dbService.addWorkout(workout);

      // Create post if public
      if (_visibility == 'public') {
        await dbService.createPost(
          workoutId: workoutId, // Use the actual workout ID
          userId: user.uid,
          userName: userData?.name ?? 'User',
          userPhoto: userData?.profilePhoto,
          caption: _captionController.text.isNotEmpty
              ? _captionController.text
              : null,
        );
      }
      await dbService.updateChallengeProgress(user.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout logged successfully! 💪'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        setState(() {
          _exercises.clear();
          _captionController.clear();
          _visibility = 'public';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Workout'),
        actions: [
          if (_exercises.isNotEmpty)
            TextButton(
              onPressed: _isLoading ? null : _saveWorkout,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Exercise list
            if (_exercises.isNotEmpty) ...[
              Text(
                'Exercises (${_exercises.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _exercises.length,
                itemBuilder: (context, index) {
                  final exercise = _exercises[index];
                  return Card(
                    child: ListTile(
                      title: Text(
                        exercise.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${exercise.sets} sets × ${exercise.reps} reps'
                        '${exercise.weight != null ? ' @ ${exercise.weight}lbs' : ''}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeExercise(index),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],

            // Add exercise form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Add Exercise',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _exerciseNameController,
                      decoration: const InputDecoration(
                        labelText: 'Exercise Name',
                        hintText: 'e.g., Bench Press',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _setsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Sets',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _repsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Reps',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _weightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Weight (lbs) - Optional',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _addExercise,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Exercise'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Caption and visibility (only show if exercises added)
            if (_exercises.isNotEmpty) ...[
              TextField(
                controller: _captionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Caption (Optional)',
                  hintText: 'Share your thoughts about this workout...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'public',
                    label: Text('Public'),
                    icon: Icon(Icons.public),
                  ),
                  ButtonSegment(
                    value: 'private',
                    label: Text('Private'),
                    icon: Icon(Icons.lock),
                  ),
                ],
                selected: {_visibility},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _visibility = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _saveWorkout,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Workout'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}