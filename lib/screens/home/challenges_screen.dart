import 'package:flutter/material.dart';
import 'package:project_2/screens/home/create_challenge_screen.dart';
import 'package:provider/provider.dart';
import '../../models/challenge_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';

class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dbService = DatabaseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenges'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (context) => const CreateChallengeScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<ChallengeModel>>(
        stream: dbService.getActiveChallenges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final challenges = snapshot.data ?? [];

          if (challenges.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Active Challenges',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to create a sample challenge',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: challenges.length,
            itemBuilder: (context, index) {
              return ChallengeCard(challenge: challenges[index]);
            },
          );
        },
      ),
    );
  }
}

class ChallengeCard extends StatelessWidget {
  final ChallengeModel challenge;

  const ChallengeCard({super.key, required this.challenge});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUserId = authService.currentUser?.uid ?? '';
    final isParticipant = challenge.participants.contains(currentUserId);
    final userProgress = challenge.leaderboard[currentUserId] ?? 0;
    final daysLeft = challenge.endDate.difference(DateTime.now()).inDays;

    // Sort leaderboard
    final sortedLeaderboard = challenge.leaderboard.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.emoji_events,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                      ),
                      Text(
                        challenge.description,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                              .withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress (if participant)
                if (isParticipant) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Progress',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '$userProgress / ${challenge.targetValue}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: userProgress / challenge.targetValue,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 16),
                ],

                // Info
                Row(
                  children: [
                    Icon(Icons.people, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${challenge.participants.length} participants',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '$daysLeft days left',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Leaderboard
                if (sortedLeaderboard.isNotEmpty) ...[
                  Text(
                    'Leaderboard',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...sortedLeaderboard.take(5).map((entry) {
                    final position = sortedLeaderboard.indexOf(entry) + 1;
                    final isCurrentUser = entry.key == currentUserId;

                    return FutureBuilder<UserModel?>(
                      future: DatabaseService().getUserData(entry.key),
                      builder: (context, snapshot) {
                        final userName = snapshot.data?.name ?? 'User';
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCurrentUser
                                ? Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withOpacity(0.3)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: position <= 3
                                      ? Colors.amber
                                      : Colors.grey[400],
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    position.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  userName,
                                  style: TextStyle(
                                    fontWeight: isCurrentUser
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              Text(
                                '${entry.value} workouts',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }),
                ],

                const SizedBox(height: 16),

                // Join/Leave button
                SizedBox(
                  width: double.infinity,
                  child: isParticipant
                      ? OutlinedButton(
                          onPressed: () async {
                            await DatabaseService()
                                .leaveChallenge(challenge.id, currentUserId);
                          },
                          child: const Text('Leave Challenge'),
                        )
                      : FilledButton(
                          onPressed: () async {
                            await DatabaseService()
                                .joinChallenge(challenge.id, currentUserId);
                          },
                          child: const Text('Join Challenge'),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}