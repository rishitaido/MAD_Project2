import 'package:flutter/material.dart';
import '../../models/challenge_model.dart';
import '../../services/challenge_generator.dart';
import '../../services/database_service.dart';

class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  ChallengeType _selectedType = ChallengeType.totalWorkouts;
  int _duration = 7;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _createChallenge() async {
    if (_titleController.text.isEmpty || _targetController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final challenge = ChallengeGenerator.createCustomChallenge(
        title: _titleController.text,
        type: _selectedType,
        targetValue: int.parse(_targetController.text),
        durationDays: _duration,
      );

      await DatabaseService().createChallenge(challenge);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Challenge created! 🏆'),
            backgroundColor: Colors.green,
          ),
        );
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

  Future<void> _generateRandomChallenge() async {
    setState(() => _isLoading = true);

    try {
      final challenge = ChallengeGenerator.generateRandomChallenge(
        durationDays: _duration,
      );

      await DatabaseService().createChallenge(challenge);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Random challenge created! 🎲'),
            backgroundColor: Colors.green,
          ),
        );
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
        title: const Text('Create Challenge'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Random challenge button
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.casino,
                      size: 48,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Quick Start',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Generate a random challenge automatically',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer
                            .withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _generateRandomChallenge,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Generate Random Challenge'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Divider
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[300])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR CREATE CUSTOM',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[300])),
              ],
            ),
            const SizedBox(height: 24),

            // Title
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Challenge Title',
                hintText: 'e.g., Beast Week',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Type selector
            Text(
              'Challenge Type',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<ChallengeType>(
              segments: const [
                ButtonSegment(
                  value: ChallengeType.totalWorkouts,
                  label: Text('Workouts'),
                  icon: Icon(Icons.fitness_center),
                ),
                ButtonSegment(
                  value: ChallengeType.totalExercises,
                  label: Text('Exercises'),
                  icon: Icon(Icons.list),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (Set<ChallengeType> newSelection) {
                setState(() {
                  _selectedType = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 8),
            SegmentedButton<ChallengeType>(
              segments: const [
                ButtonSegment(
                  value: ChallengeType.totalMinutes,
                  label: Text('Minutes'),
                  icon: Icon(Icons.timer),
                ),
                ButtonSegment(
                  value: ChallengeType.consecutiveDays,
                  label: Text('Streak'),
                  icon: Icon(Icons.local_fire_department),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (Set<ChallengeType> newSelection) {
                setState(() {
                  _selectedType = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 16),

            // Target value
            TextField(
              controller: _targetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Target Value',
                hintText: _getTargetHint(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Duration slider
            Text(
              'Duration: $_duration days',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: _duration.toDouble(),
              min: 3,
              max: 30,
              divisions: 27,
              label: '$_duration days',
              onChanged: (value) {
                setState(() {
                  _duration = value.toInt();
                });
              },
            ),
            const SizedBox(height: 24),

            // Create button
            FilledButton(
              onPressed: _isLoading ? null : _createChallenge,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Custom Challenge'),
            ),
          ],
        ),
      ),
    );
  }

  String _getTargetHint() {
    switch (_selectedType) {
      case ChallengeType.totalWorkouts:
        return 'e.g., 5';
      case ChallengeType.totalExercises:
        return 'e.g., 25';
      case ChallengeType.totalMinutes:
        return 'e.g., 120';
      case ChallengeType.consecutiveDays:
        return 'e.g., 7';
    }
  }
}