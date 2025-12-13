import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/profile_widgets.dart';
import '../../widgets/edit_profile_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _refreshKey = 0;

  void _refreshProfile() {
    setState(() {
      _refreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = authService.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    final dbService = DatabaseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => showSettingsSheet(context, themeProvider),
          ),
        ],
      ),
      body: FutureBuilder(
        key: ValueKey(_refreshKey), // Force rebuild when key changes
        future: dbService.getUserData(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data;

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 24),

                // Profile Picture with Edit Button
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      backgroundImage: userData?.profilePhoto != null
                          ? NetworkImage(userData!.profilePhoto!)
                          : null,
                      child: userData?.profilePhoto == null
                          ? Icon(
                              Icons.person,
                              size: 50,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => showEditProfileSheet(
                          context,
                          user.uid,
                          userData,
                          _refreshProfile,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.edit,
                            size: 20,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Name
                Text(
                  userData?.name ?? 'User',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),

                // Bio section
                if (userData?.bio != null && userData!.bio!.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
                    child: Text(
                      userData.bio!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Stats Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FutureBuilder<int>(
                          future: dbService.getUserWorkoutCount(user.uid),
                          builder: (context, snapshot) {
                            return ProfileStatCard(
                              icon: Icons.fitness_center,
                              label: 'Workouts',
                              value: snapshot.data != null
                                  ? snapshot.data.toString()
                                  : '--',
                              color: Theme.of(context).colorScheme.primary,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FutureBuilder<int>(
                          future: dbService.getUserWorkoutStreak(user.uid),
                          builder: (context, snapshot) {
                            return ProfileStatCard(
                              icon: Icons.local_fire_department,
                              label: 'Streak',
                              value: snapshot.data != null
                                  ? '${snapshot.data}'
                                  : '--',
                              color: Colors.orange,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FutureBuilder<int>(
                          future: dbService.getFollowerCount(user.uid),
                          builder: (context, snapshot) {
                            return ProfileStatCard(
                              icon: Icons.people,
                              label: 'Followers',
                              value: snapshot.data != null
                                  ? snapshot.data.toString()
                                  : '--',
                              color: Colors.blue,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Body Metrics Card
                BodyMetricsCard(userData: userData),

                // Personal Info Card
                PersonalInfoCard(userData: userData, user: user),

                // Spacer to push sign out button to bottom
                const SizedBox(height: 24),

                // Sign out button at bottom
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await authService.signOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}