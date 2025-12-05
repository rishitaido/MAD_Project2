import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/post_model.dart';
import '../../models/workout_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dbService = DatabaseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beast Mode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications coming soon!')),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<PostModel>>(
        stream: dbService.getFeedPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final posts = snapshot.data ?? [];

          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.fitness_center,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No workouts yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Be the first to log a workout!',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // Refresh is automatic with StreamBuilder
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {
                return PostCard(post: posts[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  final PostModel post;

  const PostCard({super.key, required this.post});

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(timestamp);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUserId = authService.currentUser?.uid ?? '';
    final isLiked = post.isLikedBy(currentUserId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          ListTile(
            leading: CircleAvatar(
              backgroundImage: post.userPhoto != null
                  ? NetworkImage(post.userPhoto!)
                  : null,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: post.userPhoto == null
                  ? Text(
                      post.userName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    )
                  : null,
            ),
            title: Text(
              post.userName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(_getTimeAgo(post.timestamp)),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                // TODO: Show options
              },
            ),
          ),

          // Workout details
          FutureBuilder<WorkoutModel?>(
            future: DatabaseService().getWorkout(post.workoutId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Loading workout...'),
                );
              }

              final workout = snapshot.data!;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Exercises
                    ...workout.exercises.map((exercise) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.fitness_center,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${exercise.name} • ${exercise.sets}×${exercise.reps}'
                                  '${exercise.weight != null ? ' @ ${exercise.weight}kg' : ''}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 8),
                    Text(
                      '${workout.duration} min • ${workout.exercises.length} exercises',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Caption
          if (post.caption != null && post.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(post.caption!),
            ),

          const Divider(height: 1),

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await DatabaseService().toggleLike(post.id, currentUserId);
                  },
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : null,
                  ),
                  label: Text('${post.likes.length}'),
                ),
                TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Comments coming in Week 3!')),
                    );
                  },
                  icon: const Icon(Icons.comment_outlined),
                  label: Text('${post.commentCount}'),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Share coming soon!')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}