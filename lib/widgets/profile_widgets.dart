import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/user_model.dart';
import '../../../providers/theme_provider.dart';
import '../../../utils/profile_helpers.dart';

// Reusable stat card widget for displaying profile statistics
class ProfileStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const ProfileStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
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
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Body Metrics card showing height, weight, and BMI in 2x2 grid
class BodyMetricsCard extends StatelessWidget {
  final UserModel? userData;

  const BodyMetricsCard({
    super.key,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    // Don't show card if no metrics are available
    if (userData?.currentWeight == null &&
        userData?.targetWeight == null &&
        userData?.height == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.monitor_weight,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Body Metrics',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Row 1: Height and Current Weight
              Row(
                children: [
                  if (userData?.height != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Height',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ProfileHelpers.formatHeight(userData!.height!),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  if (userData?.height != null && userData?.currentWeight != null)
                    const SizedBox(width: 16),
                  if (userData?.currentWeight != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Weight',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${userData!.currentWeight!.toStringAsFixed(1)} lbs',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              // Add spacing between rows
              if ((userData?.height != null && userData?.currentWeight != null) ||
                  userData?.targetWeight != null)
                const SizedBox(height: 16),
              // Row 2: BMI and Target Weight
              Row(
                children: [
                  if (userData?.height != null && userData?.currentWeight != null) ...[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BMI',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ProfileHelpers.calculateBMI(
                              userData!.height!,
                              userData!.currentWeight!,
                            ).toStringAsFixed(1),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: ProfileHelpers.getBMIColor(
                                    ProfileHelpers.calculateBMI(
                                      userData!.height!,
                                      userData!.currentWeight!,
                                    ),
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if ((userData?.height != null && userData?.currentWeight != null) &&
                      userData?.targetWeight != null)
                    const SizedBox(width: 16),
                  if (userData?.targetWeight != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Target Weight',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${userData!.targetWeight!.toStringAsFixed(1)} lbs',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Personal info card showing age, gender, email, and member since
class PersonalInfoCard extends StatelessWidget {
  final UserModel? userData;
  final User user;

  const PersonalInfoCard({
    super.key,
    required this.userData,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    if (userData == null) return const SizedBox.shrink();

    final isOwnProfile = userData!.uid == user.uid;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Column(
          children: [
            if (userData?.dateOfBirth != null) ...[
              ListTile(
                leading: const Icon(Icons.cake),
                title: const Text('Age'),
                subtitle: Text(
                  '${ProfileHelpers.calculateAge(userData!.dateOfBirth!)} years old',
                ),
              ),
              const Divider(height: 1),
            ],
            if (userData?.gender != null) ...[
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Gender'),
                subtitle: Text(userData!.gender!),
              ),
              const Divider(height: 1),
            ],
            // Only show email if it's the user's own profile
            if (isOwnProfile) ...[
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                subtitle: Text(userData!.email),
              ),
              const Divider(height: 1),
            ],
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Member Since'),
              subtitle: Text(
                 ProfileHelpers.formatDate(userData!.createdAt),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Settings bottom sheet dialog
void showSettingsSheet(BuildContext context, ThemeProvider themeProvider) {
  showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Settings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Dark Mode'),
              value: themeProvider.isDarkMode,
              onChanged: (_) => themeProvider.toggleTheme(),
              secondary: Icon(
                themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
