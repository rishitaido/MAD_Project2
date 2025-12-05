import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/workout_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final dbService = DatabaseService();

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit profile coming in Week 3!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
            },
          ),
        ],
      ),
      body: FutureBuilder<UserModel?>(
        future: dbService.getUserData(user.uid),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = userSnapshot.data;

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 24),
                // Profile picture
                CircleAvatar(
                  radius: 60,
                  backgroundImage: userData?.profilePhoto != null
                      ? NetworkImage(userData!.profilePhoto!)
                      : null,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: userData?.profilePhoto == null
                      ? Text(
                          userData?.name.substring(0, 1).toUpperCase() ?? 'U',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  userData?.name ?? 'User',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email ?? '',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                if (userData?.bio != null && userData!.bio!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      userData.bio!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Stats
                FutureBuilder<int>(
                  future: dbService.getUserWorkoutCount(user.uid),
                  builder: (context, countSnapshot) {
                    final workoutCount = countSnapshot.data ?? 0;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatCard(
                          label: 'Workouts',
                          value: workoutCount.toString(),
                        ),
                        _StatCard(
                          label: 'Streak',
                          value: '0', // TODO: Calculate streak
                        ),
                        _StatCard(
                          label: 'Followers',
                          value: '0', // TODO: Implement followers
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Divider(),

                // Recent workouts
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Recent Workouts',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                StreamBuilder<List<WorkoutModel>>(
                  stream: dbService.getUserWorkouts(user.uid),
                  builder: (context, workoutSnapshot) {
                    if (workoutSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final workouts = workoutSnapshot.data ?? [];

                    if (workouts.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No workouts yet. Start logging!',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: workouts.length,
                      itemBuilder: (context, index) {
                        final workout = workouts[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                Theme.of(context).colorScheme.primaryContainer,
                            child: Icon(
                              Icons.fitness_center,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                          title: Text(
                            '${workout.exercises.length} exercises',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${workout.duration} min • ${workout.date.toString().split(' ')[0]}',
                          ),
                          trailing: Icon(
                            workout.visibility == 'public'
                                ? Icons.public
                                : Icons.lock,
                            size: 16,
                            color: Colors.grey,
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
