import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/database_service.dart';

// Bottom sheet dialog for editing user profile information
class EditProfileSheet extends StatefulWidget {
  final String uid;
  final dynamic userData;
  final VoidCallback onProfileUpdated;

  const EditProfileSheet({
    super.key,
    required this.uid,
    required this.userData,
    required this.onProfileUpdated,
  });

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _heightController;
  late TextEditingController _currentWeightController;
  late TextEditingController _targetWeightController;

  final ImagePicker _picker = ImagePicker();
  File? _newProfileImage;
  bool _isLoading = false;
  DateTime? _selectedDateOfBirth;
  String? _selectedGender;

  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  @override
  void initState() {
    super.initState();
    final userData = widget.userData;
    _nameController = TextEditingController(text: userData?.name ?? '');
    _bioController = TextEditingController(text: userData?.bio ?? '');
    _heightController = TextEditingController(
      text: userData?.height?.toStringAsFixed(0) ?? '',
    );
    _currentWeightController = TextEditingController(
      text: userData?.currentWeight?.toStringAsFixed(1) ?? '',
    );
    _targetWeightController = TextEditingController(
      text: userData?.targetWeight?.toStringAsFixed(1) ?? '',
    );
    _selectedDateOfBirth = userData?.dateOfBirth;
    _selectedGender = userData?.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _heightController.dispose();
    _currentWeightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() => _newProfileImage = File(image.path));
      }
    } catch (e) {
      if (mounted) _showError('Error picking image: $e');
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildImageOption(Icons.photo_library, 'Gallery',
                () => _pickImage(ImageSource.gallery)),
            _buildImageOption(Icons.camera_alt, 'Camera',
                () => _pickImage(ImageSource.camera)),
            if (_newProfileImage != null ||
                widget.userData?.profilePhoto != null)
              _buildImageOption(Icons.delete, 'Remove Photo', () {
                setState(() => _newProfileImage = null);
              }, isDestructive: true),
          ],
        ),
      ),
    );
  }

  ListTile _buildImageOption(IconData icon, String title, VoidCallback onTap,
      {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : null),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter a name', isWarning: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updateData = <String, dynamic>{};
      final userData = widget.userData;

      // Helper to add if changed
      void addIfChanged(String key, dynamic newValue, dynamic oldValue) {
        if (newValue != oldValue) updateData[key] = newValue;
      }

      void addDoubleIfChanged(
          String key, TextEditingController controller, double? oldValue) {
        final text = controller.text.trim();
        if (text.isNotEmpty) {
          final value = double.tryParse(text);
          if (value != null && value != oldValue) updateData[key] = value;
        } else if (oldValue != null) {
          updateData[key] = null;
        }
      }

      addIfChanged('name', _nameController.text.trim(), userData?.name);
      
      final bio = _bioController.text.trim();
      if (bio != (userData?.bio ?? '')) {
         updateData['bio'] = bio.isEmpty ? null : bio;
      }

      addDoubleIfChanged('height', _heightController, userData?.height);
      addDoubleIfChanged(
          'currentWeight', _currentWeightController, userData?.currentWeight);
      addDoubleIfChanged(
          'targetWeight', _targetWeightController, userData?.targetWeight);

      addIfChanged('dateOfBirth', _selectedDateOfBirth, userData?.dateOfBirth);
      addIfChanged('gender', _selectedGender, userData?.gender);

      if (_newProfileImage != null) {
        updateData['profilePhoto'] = await DatabaseService()
            .uploadProfilePhoto(widget.uid, _newProfileImage!);
      }

      if (updateData.isNotEmpty) {
        await DatabaseService().updateUserProfile(widget.uid, updateData);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onProfileUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('Error updating profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message, {bool isWarning = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isWarning ? Colors.orange : Colors.red,
    ));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        hintText: hint,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Edit Profile',
                    style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 24),

            // Profile Photo
            Center(
              child: GestureDetector(
                onTap: _showImageOptions,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      backgroundImage: _newProfileImage != null
                          ? FileImage(_newProfileImage!)
                          : (widget.userData?.profilePhoto != null
                              ? NetworkImage(widget.userData!.profilePhoto!)
                                  as ImageProvider
                              : null),
                      child: (_newProfileImage == null &&
                              widget.userData?.profilePhoto == null)
                          ? Icon(Icons.person, size: 50)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.camera_alt,
                            size: 20,
                            color: Theme.of(context).colorScheme.onPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TextButton(
                onPressed: _showImageOptions,
                child: const Text('Change Profile Picture')),
            const SizedBox(height: 24),

            _buildTextField(
                controller: _nameController, label: 'Name *', icon: Icons.person),
            const SizedBox(height: 16),
            _buildTextField(
                controller: _bioController,
                label: 'Bio',
                icon: Icons.edit,
                maxLines: 3,
                hint: 'Tell us about yourself...'),
            const SizedBox(height: 16),
            _buildTextField(
                controller: _heightController,
                label: 'Height (inches)',
                icon: Icons.height,
                keyboardType: TextInputType.number,
                hint: 'e.g., 70 for 5\'10"'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                      controller: _currentWeightController,
                      label: 'Current Weight (lbs)',
                      icon: Icons.monitor_weight,
                      keyboardType: TextInputType.number),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                      controller: _targetWeightController,
                      label: 'Target Weight (lbs)',
                      icon: Icons.flag,
                      keyboardType: TextInputType.number),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Date of Birth
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDateOfBirth ?? DateTime(2000),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _selectedDateOfBirth = date);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.cake),
                ),
                child: Text(
                  _selectedDateOfBirth != null
                      ? '${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.year}'
                      : 'Tap to select',
                  style: TextStyle(
                      color: _selectedDateOfBirth != null
                          ? Theme.of(context).textTheme.bodyLarge?.color
                          : Colors.grey[600]),
                ),
              ),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: _genderOptions
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedGender = v),
            ),
            const SizedBox(height: 24),

            FilledButton(
              onPressed: _isLoading ? null : _saveProfile,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Changes'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// Helper function to show edit profile sheet
void showEditProfileSheet(BuildContext context, String uid, dynamic userData,
    VoidCallback onProfileUpdated) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => EditProfileSheet(
      uid: uid,
      userData: userData,
      onProfileUpdated: onProfileUpdated,
    ),
  );
}
