import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/post_model.dart';
import '../../../models/workout_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import 'home/../comments_screen.dart';

import 'profile_screen.dart';
import 'notifications_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading feed',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
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
                    'Be the first to log a workout and share it with the community!',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
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

class PostCard extends StatefulWidget {
  final PostModel post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isFollowing = false;
  bool _isLoadingFollow = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    if (currentUser != null && currentUser.uid != widget.post.userId) {
      final isFollowing = await DatabaseService().isFollowing(currentUser.uid, widget.post.userId);
      if (mounted) {
        setState(() => _isFollowing = isFollowing);
      }
    }
  }

  Future<void> _followUser() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoadingFollow = true);
    try {
      await DatabaseService().followUser(currentUser.uid, widget.post.userId);
      if (mounted) {
        setState(() => _isFollowing = true);
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() => _isLoadingFollow = false);
      }
    }
  }

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

  String _formatCardioSubtitle(Exercise exercise) {
    final parts = <String>['Cardio'];

    if (exercise.distanceMiles != null) {
      parts.add('${exercise.distanceMiles} mi');
    }

    // Speed (mph)
    if (exercise.speedMph != null) {
      parts.add('${exercise.speedMph} mph');
    }

    if (exercise.terrain != null && exercise.terrain!.trim().isNotEmpty) {
      parts.add(exercise.terrain!.trim());
    }

    return parts.join(' • ');
  }

  String _formatStrengthSubtitle(Exercise exercise) {
    return '${exercise.sets} sets × ${exercise.reps} reps'
        '${exercise.weight != null && exercise.weight!.trim().isNotEmpty ? ' @ ${exercise.weight}lbs' : ''}';
  }

  IconData _exerciseIcon(Exercise exercise) {
    return exercise.isCardio ? Icons.directions_run : Icons.fitness_center;
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(viewUserId: widget.post.userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUserId = authService.currentUser?.uid ?? '';
    final isOwner = currentUserId == widget.post.userId;
    final isLiked = widget.post.isLikedBy(currentUserId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          ListTile(
            onTap: _navigateToProfile,
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            leading: CircleAvatar(
              backgroundImage: widget.post.userPhoto != null
                  ? NetworkImage(widget.post.userPhoto!)
                  : null,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: widget.post.userPhoto == null
                  ? Text(
                      widget.post.userName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    )
                  : null,
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    widget.post.userName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isOwner) ...[
                  const SizedBox(width: 8),
                  if (_isFollowing)
                    Text(
                      'Following',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else
                    SizedBox(
                      height: 24,
                      child: _isLoadingFollow
                        ? const SizedBox(width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : TextButton(
                            onPressed: _followUser,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Follow', style: TextStyle(fontSize: 12)),
                          ),
                    ),
                ],
              ],
            ),
            subtitle: Row(
              children: [
                Text(_getTimeAgo(widget.post.timestamp)),
                if (widget.post.title != null && widget.post.title!.isNotEmpty) ...[
                  const Text(' • '),
                  Expanded(
                    child: Text(
                      widget.post.title!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            trailing: isOwner
                ? PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Post'),
                            content: const Text(
                                'Are you sure you want to delete this post? This will also delete all comments.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          try {
                            await DatabaseService().deletePost(widget.post.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Post deleted'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete Post'),
                          ],
                        ),
                      ),
                    ],
                  )
                : IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Report feature coming soon')),
                      );
                    },
                  ),
          ),

          // Workout details
          FutureBuilder<WorkoutModel?>(
            future: DatabaseService().getWorkout(widget.post.workoutId),
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
                    ...workout.exercises.map(
                      (exercise) {
                        final subtitle = exercise.isCardio
                            ? _formatCardioSubtitle(exercise)
                            : _formatStrengthSubtitle(exercise);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                _exerciseIcon(exercise),
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${exercise.name} • $subtitle',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
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
          if (widget.post.caption != null && widget.post.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(widget.post.caption!),
            ),

          const Divider(height: 1),

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await DatabaseService().toggleLike(widget.post.id, currentUserId);
                  },
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : null,
                  ),
                  label: Text('${widget.post.likes.length}'),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CommentsScreen(post: widget.post),
                      ),
                    );
                  },
                  icon: const Icon(Icons.comment_outlined),
                  label: Text('${widget.post.commentCount}'),
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
