import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/workout_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';

class LogWorkoutScreen extends StatefulWidget {
  const LogWorkoutScreen({
    super.key,
    this.existingWorkout,
  });

  final WorkoutModel? existingWorkout;

  @override
  State<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends State<LogWorkoutScreen> {
  final _captionController = TextEditingController();
  final _titleController = TextEditingController();
  final _durationController = TextEditingController();
  final _exerciseNameController = TextEditingController();
  final _setsController = TextEditingController();
  final _repsController = TextEditingController();
  final _weightController = TextEditingController();

  // Cardio-specific controllers (distance + speed + terrain)
  final _distanceController = TextEditingController();
  final _speedController = TextEditingController();
  final _terrainController = TextEditingController();

  final List<Exercise> _exercises = [];
  final ImagePicker _picker = ImagePicker();

  File? _preWorkoutImage;
  File? _postWorkoutImage;
  bool _isLoading = false;
  String _visibility = 'public';

  // Editing state
  WorkoutModel? _editingWorkout;
  String? _existingPrePhotoUrl;
  String? _existingPostPhotoUrl;

  // Cardio toggle for the "Add Exercise" form
  bool _isCardio = false;

  bool get _isEditing => _editingWorkout != null;

  @override
  void initState() {
    super.initState();

    // If editing, preload workout data into the form
    if (widget.existingWorkout != null) {
      _editingWorkout = widget.existingWorkout;
      final w = widget.existingWorkout!;

      _titleController.text = w.title ?? '';
      _durationController.text = w.duration.toString();
      _visibility = w.visibility;
      _exercises.addAll(w.exercises.map((e) => e.copyWith()));

      _existingPrePhotoUrl = w.preWorkoutPhoto;
      _existingPostPhotoUrl = w.postWorkoutPhoto;
      // Caption lives on PostModel, so we leave caption empty here
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _titleController.dispose();
    _durationController.dispose();
    _exerciseNameController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    _distanceController.dispose();
    _speedController.dispose();
    _terrainController.dispose();
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
    final hasImage =
        isPreWorkout ? _preWorkoutImage != null : _postWorkoutImage != null;

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
    final name = _exerciseNameController.text.trim();

    if (name.isEmpty) {
      _showError('Please enter an exercise name', isWarning: true);
      return;
    }

    if (_isCardio) {
      // Cardio: distance + speed + terrain
      final distanceText = _distanceController.text.trim();
      final speedText = _speedController.text.trim();
      final terrainText = _terrainController.text.trim();

      final distance =
          distanceText.isNotEmpty ? double.tryParse(distanceText) : null;
      final speed =
          speedText.isNotEmpty ? double.tryParse(speedText) : null;
      final hasTerrain = terrainText.isNotEmpty;

      if (distance == null && speed == null && !hasTerrain) {
        _showError(
          'For cardio, add distance, speed, or terrain',
          isWarning: true,
        );
        return;
      }

      setState(() {
        _exercises.add(
          Exercise(
            name: name,
            // strength fields are unused for cardio; store neutral values
            sets: '0',
            reps: '0',
            weight: null,
            isCardio: true,
            distanceMiles: distance,
            speedMph: speed,
            terrain: hasTerrain ? terrainText : null,
          ),
        );

        _exerciseNameController.clear();
        _setsController.clear();
        _repsController.clear();
        _weightController.clear();
        _distanceController.clear();
        _speedController.clear();
        _terrainController.clear();
        _isCardio = false;
      });
    } else {
      // Strength: require sets/reps, weight optional
      final setsText = _setsController.text.trim();
      final repsText = _repsController.text.trim();

      if (setsText.isEmpty || repsText.isEmpty) {
        _showError('Please enter sets and reps', isWarning: true);
        return;
      }

      final weightText = _weightController.text.trim();
      final weight = weightText.isNotEmpty ? weightText : null;

      setState(() {
        _exercises.add(
          Exercise(
            name: name,
            sets: setsText,
            reps: repsText,
            weight: weight,
          ),
        );

        _exerciseNameController.clear();
        _setsController.clear();
        _repsController.clear();
        _weightController.clear();
        _distanceController.clear();
        _speedController.clear();
        _terrainController.clear();
      });
    }
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
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

    final titleText = _titleController.text.trim().isEmpty
        ? null
        : _titleController.text.trim();

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      if (user == null) return;

      final dbService = DatabaseService();
      final userData = await dbService.getUserData(user.uid);

      // Upload photos (if new ones were selected)
      String? prePhotoUrl = _existingPrePhotoUrl;
      String? postPhotoUrl = _existingPostPhotoUrl;

      if (_preWorkoutImage != null) {
        prePhotoUrl =
            await dbService.uploadWorkoutPhoto(user.uid, _preWorkoutImage!);
      }
      if (_postWorkoutImage != null) {
        postPhotoUrl =
            await dbService.uploadWorkoutPhoto(user.uid, _postWorkoutImage!);
      }

      if (_isEditing) {
        // 🔁 Update existing workout
        final original = _editingWorkout!;
        final updated = original.copyWith(
          title: titleText,
          exercises: List<Exercise>.from(_exercises),
          duration: duration,
          visibility: _visibility,
        );

        // Rebuild with photos included
        final updatedWithPhotos = WorkoutModel(
          id: updated.id,
          userId: updated.userId,
          userName: updated.userName,
          userPhoto: updated.userPhoto,
          title: updated.title,
          date: updated.date,
          exercises: updated.exercises,
          duration: updated.duration,
          visibility: updated.visibility,
          preWorkoutPhoto: prePhotoUrl,
          postWorkoutPhoto: postPhotoUrl,
        );

        await dbService.updateWorkout(updatedWithPhotos);

        if (mounted) {
          _showSuccess('Workout updated!');
          Navigator.of(context).pop(); // go back to previous screen
        }
      } else {
        // ➕ Create new workout
        final workout = WorkoutModel(
          id: '',
          userId: user.uid,
          userName: userData?.name ?? 'User',
          userPhoto: userData?.profilePhoto,
          title: titleText,
          date: DateTime.now(),
          exercises: _exercises,
          duration: duration,
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
            caption: _captionController.text.isNotEmpty
                ? _captionController.text
                : null,
            title: _titleController.text.isNotEmpty
                ? _titleController.text
                : null,
          );
        }

        await dbService.updateChallengeProgress(user.uid);

        if (mounted) {
          _showSuccess('Workout logged successfully! 💪');
          _clearForm();
        }
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
      _titleController.clear();
      _durationController.clear();
      _visibility = 'public';
      _preWorkoutImage = null;
      _postWorkoutImage = null;
      _editingWorkout = null;
      _existingPrePhotoUrl = null;
      _existingPostPhotoUrl = null;
      _exerciseNameController.clear();
      _setsController.clear();
      _repsController.clear();
      _weightController.clear();
      _distanceController.clear();
      _speedController.clear();
      _terrainController.clear();
      _isCardio = false;
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
    final titleText = _isEditing ? 'Edit Workout' : 'Log Workout';

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
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

            // Workout title
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Workout Title (optional)',
                hintText: 'e.g., Push Day, Leg Day',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Duration input
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Workout Duration (minutes)',
                hintText: 'e.g., 45',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Exercise list
            if (_exercises.isNotEmpty) ...[
              Text(
                'Exercises (${_exercises.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ..._exercises.asMap().entries.map((entry) {
                final exercise = entry.value;
                final index = entry.key;

                String subtitle;
                if (exercise.isCardio == true) {
                  final parts = <String>[];
                  if (exercise.distanceMiles != null) {
                    parts.add('${exercise.distanceMiles} mi');
                  }
                  if (exercise.speedMph != null) {
                    parts.add('${exercise.speedMph} mph');
                  }
                  if (exercise.terrain != null &&
                      exercise.terrain!.trim().isNotEmpty) {
                    parts.add(exercise.terrain!.trim());
                  }
                  subtitle = parts.isEmpty
                      ? 'Cardio'
                      : 'Cardio • ${parts.join(' • ')}';
                } else {
                  subtitle =
                      '${exercise.sets} sets × ${exercise.reps} reps'
                      '${exercise.weight != null && exercise.weight!.isNotEmpty ? ' @ ${exercise.weight}lbs' : ''}';
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      exercise.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(subtitle),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeExercise(index),
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
              distanceController: _distanceController,
              speedController: _speedController,
              terrainController: _terrainController,
              isCardio: _isCardio,
              onCardioChanged: (value) {
                setState(() {
                  _isCardio = value;
                  if (value) {
                    // Clear strength fields when switching to cardio
                    _setsController.clear();
                    _repsController.clear();
                    _weightController.clear();
                  } else {
                    // Clear cardio fields when switching back
                    _distanceController.clear();
                    _speedController.clear();
                    _terrainController.clear();
                  }
                });
              },
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
                onSelectionChanged: (newSelection) =>
                    setState(() => _visibility = newSelection.first),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _saveWorkout,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
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

// Extracted widgets
class _ExerciseForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController setsController;
  final TextEditingController repsController;
  final TextEditingController weightController;
  final TextEditingController distanceController;
  final TextEditingController speedController;
  final TextEditingController terrainController;
  final bool isCardio;
  final ValueChanged<bool> onCardioChanged;
  final VoidCallback onAdd;

  const _ExerciseForm({
    required this.nameController,
    required this.setsController,
    required this.repsController,
    required this.weightController,
    required this.distanceController,
    required this.speedController,
    required this.terrainController,
    required this.isCardio,
    required this.onCardioChanged,
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
                hintText: 'e.g., Bench Press, Run',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Strength metrics (disabled when cardio)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: setsController,
                    enabled: !isCardio,
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
                    enabled: !isCardio,
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
              enabled: !isCardio,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Weight (lbs) - Optional',
                hintText: '135-155-185',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Cardio toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('This is a cardio exercise'),
              value: isCardio,
              onChanged: onCardioChanged,
            ),

            // Cardio-specific fields (distance + speed + terrain)
            if (isCardio) ...[
              const SizedBox(height: 8),
              TextField(
                controller: distanceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Distance (mi)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: speedController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Speed (mph) - Optional',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: terrainController,
                decoration: const InputDecoration(
                  labelText: 'Terrain / Environment - Optional',
                  hintText: 'e.g., Treadmill, Trail, Hills',
                  border: OutlineInputBorder(),
                ),
              ),
            ],

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

  const _PhotoCard({
    required this.label,
    required this.image,
    required this.onTap,
  });

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
                  Icon(Icons.add_photo_alternate,
                      size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(label, style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text(
                    'Optional',
                    style:
                        TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
