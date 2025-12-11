import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/workout_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';

class LogWorkoutScreen extends StatefulWidget {
  const LogWorkoutScreen({super.key});

  @override
  State<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends State<LogWorkoutScreen> {
  final _captionController = TextEditingController();
  final _durationController = TextEditingController(); // NEW
  final _exerciseNameController = TextEditingController();
  final _setsController = TextEditingController();
  final _repsController = TextEditingController();
  final _weightController = TextEditingController();
  
  final List<Exercise> _exercises = [];
  final ImagePicker _picker = ImagePicker();
  
  File? _preWorkoutImage;
  File? _postWorkoutImage;
  bool _isLoading = false;
  String _visibility = 'public';

  @override
  void dispose() {
    _captionController.dispose();
    _durationController.dispose(); // NEW
    _exerciseNameController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _handleImagePicker(bool isPreWorkout, ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        setState(() {
          if (isPreWorkout) {
            _preWorkoutImage = File(image.path);
          } else {
            _postWorkoutImage = File(image.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Error picking image: $e');
      }
    }
  }

  void _showPhotoOptions(bool isPreWorkout) {
    final hasImage = isPreWorkout ? _preWorkoutImage != null : _postWorkoutImage != null;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _handleImagePicker(isPreWorkout, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _handleImagePicker(isPreWorkout, ImageSource.camera);
              },
            ),
            if (hasImage)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    if (isPreWorkout) {
                      _preWorkoutImage = null;
                    } else {
                      _postWorkoutImage = null;
                    }
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  void _addExercise() {
    if (_exerciseNameController.text.isEmpty ||
        _setsController.text.isEmpty ||
        _repsController.text.isEmpty) {
      _showError('Please fill in exercise name, sets, and reps', isWarning: true);
      return;
    }

    setState(() {
      _exercises.add(Exercise(
        name: _exerciseNameController.text.trim(),
        sets: _setsController.text.trim(),
        reps: _repsController.text.trim(),
        weight: _weightController.text.isNotEmpty ? _weightController.text.trim() : null,
      ));

      _exerciseNameController.clear();
      _setsController.clear();
      _repsController.clear();
      _weightController.clear();
    });
  }

  Future<void> _saveWorkout() async {
    if (_exercises.isEmpty) {
      _showError('Please add at least one exercise', isWarning: true);
      return;
    }

    // Validate duration input
    if (_durationController.text.isEmpty) {
      _showError('Please enter workout duration', isWarning: true);
      return;
    }

    final duration = int.tryParse(_durationController.text);
    if (duration == null || duration <= 0) {
      _showError('Please enter a valid duration in minutes', isWarning: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      if (user == null) return;

      final dbService = DatabaseService();
      final userData = await dbService.getUserData(user.uid);

      // Upload photos
      final prePhotoUrl = _preWorkoutImage != null
          ? await dbService.uploadWorkoutPhoto(user.uid, _preWorkoutImage!)
          : null;
      
      final postPhotoUrl = _postWorkoutImage != null
          ? await dbService.uploadWorkoutPhoto(user.uid, _postWorkoutImage!)
          : null;

      // Create workout
      final workout = WorkoutModel(
        id: '',
        userId: user.uid,
        userName: userData?.name ?? 'User',
        userPhoto: userData?.profilePhoto,
        date: DateTime.now(),
        exercises: _exercises,
        duration: duration, // Use manual input
        visibility: _visibility,
        preWorkoutPhoto: prePhotoUrl,
        postWorkoutPhoto: postPhotoUrl,
      );

      final workoutId = await dbService.addWorkout(workout);

      // Create post if public
      if (_visibility == 'public') {
        await dbService.createPost(
          workoutId: workoutId,
          userId: user.uid,
          userName: userData?.name ?? 'User',
          userPhoto: userData?.profilePhoto,
          caption: _captionController.text.isNotEmpty ? _captionController.text : null,
        );
      }

      await dbService.updateChallengeProgress(user.uid);

      if (mounted) {
        _showSuccess('Workout logged successfully! 💪');
        _clearForm();
      }
    } catch (e) {
      if (mounted) _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    setState(() {
      _exercises.clear();
      _captionController.clear();
      _durationController.clear(); // NEW
      _visibility = 'public';
      _preWorkoutImage = null;
      _postWorkoutImage = null;
    });
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message, {bool isWarning = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isWarning ? Colors.orange : Colors.red,
      ),
    );
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
            // Photo cards
            Row(
              children: [
                Expanded(
                  child: _PhotoCard(
                    label: 'Pre-Workout',
                    image: _preWorkoutImage,
                    onTap: () => _showPhotoOptions(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PhotoCard(
                    label: 'Post-Workout',
                    image: _postWorkoutImage,
                    onTap: () => _showPhotoOptions(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Duration input - NEW
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Workout Duration (minutes)',
                hintText: 'e.g., 45',
                prefixIcon: const Icon(Icons.timer),
                border: const OutlineInputBorder(),
                helperText: 'How long was your workout?',
              ),
            ),
            const SizedBox(height: 24),

            // Exercise list
            if (_exercises.isNotEmpty) ...[
              Text('Exercises (${_exercises.length})', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ..._exercises.asMap().entries.map((entry) {
                final exercise = entry.value;
                final index = entry.key;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(exercise.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${exercise.sets} sets × ${exercise.reps} reps'
                      '${exercise.weight != null ? ' @ ${exercise.weight}lbs' : ''}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() => _exercises.removeAt(index)),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
            ],

            // Add exercise form
            _ExerciseForm(
              nameController: _exerciseNameController,
              setsController: _setsController,
              repsController: _repsController,
              weightController: _weightController,
              onAdd: _addExercise,
            ),
            const SizedBox(height: 24),

            // Caption and visibility
            if (_exercises.isNotEmpty) ...[
              TextField(
                controller: _captionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Caption (Optional)',
                  hintText: 'Share your thoughts...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'public', label: Text('Public'), icon: Icon(Icons.public)),
                  ButtonSegment(value: 'private', label: Text('Private'), icon: Icon(Icons.lock)),
                ],
                selected: {_visibility},
                onSelectionChanged: (newSelection) => setState(() => _visibility = newSelection.first),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _saveWorkout,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save Workout'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Extracted widgets
class _ExerciseForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController setsController;
  final TextEditingController repsController;
  final TextEditingController weightController;
  final VoidCallback onAdd;

  const _ExerciseForm({
    required this.nameController,
    required this.setsController,
    required this.repsController,
    required this.weightController,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add Exercise', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
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
                    controller: setsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Sets',
                      hintText: '3 or 3-4',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: repsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Reps',
                      hintText: '8-12',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Weight (lbs) - Optional',
                hintText: '135-155-185',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add Exercise'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final String label;
  final File? image;
  final VoidCallback onTap;

  const _PhotoCard({required this.label, required this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: image == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(label, style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text('Optional', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(image!, fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}