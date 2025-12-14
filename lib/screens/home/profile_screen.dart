import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/profile_widgets.dart';
import '../../../widgets/edit_profile_sheet.dart';

class ProfileScreen extends StatefulWidget {
  final String? viewUserId; // Optional: if null, view current user

  const ProfileScreen({super.key, this.viewUserId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _refreshKey = 0;
  bool _isFollowing = false;
  bool _isLoadingFollow = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  void _refreshProfile() {
    setState(() {
      _refreshKey++;
    });
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    
    if (widget.viewUserId != null && currentUser != null) {
      final isFollowing = await DatabaseService().isFollowing(
        currentUser.uid, 
        widget.viewUserId!
      );
      if (mounted) {
        setState(() => _isFollowing = isFollowing);
      }
    }
  }

  Future<void> _toggleFollow() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    
    if (currentUser == null || widget.viewUserId == null) return;

    setState(() => _isLoadingFollow = true);
    
    try {
      if (_isFollowing) {
        await DatabaseService().unfollowUser(currentUser.uid, widget.viewUserId!);
      } else {
        await DatabaseService().followUser(currentUser.uid, widget.viewUserId!);
      }
      
      if (mounted) {
        setState(() => _isFollowing = !_isFollowing);
        _refreshProfile(); // Update follower counts
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingFollow = false);
      }
    }
  }

  void _showFollowersList(String userId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FollowersListSheet(userId: userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    final targetUserId = widget.viewUserId ?? currentUser.uid;
    final isOwnProfile = widget.viewUserId == null || widget.viewUserId == currentUser.uid;
    final dbService = DatabaseService();

    return Scaffold(
      appBar: AppBar(
        title: Text(isOwnProfile ? 'My Profile' : 'Profile'),
        actions: [
          if (isOwnProfile)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => showSettingsSheet(context, themeProvider),
            ),
        ],
      ),
      body: FutureBuilder(
        key: ValueKey(_refreshKey), // Force rebuild when key changes
        future: dbService.getUserData(targetUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data;

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 24),

                // Profile Picture
                Stack(
                  alignment: Alignment.center,
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
                    if (isOwnProfile)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => showEditProfileSheet(
                            context,
                            currentUser.uid,
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
                
                // Follow Button (if not own profile)
                if (!isOwnProfile)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: FilledButton.icon(
                      onPressed: _isLoadingFollow ? null : _toggleFollow,
                      icon: _isLoadingFollow 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(_isFollowing ? Icons.check : Icons.person_add),
                      label: Text(_isFollowing ? 'Following' : 'Follow'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _isFollowing ? Colors.grey[700] : null,
                      ),
                    ),
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
                        child: ProfileStatCard(
                          icon: Icons.emoji_events,
                          label: 'Achievements',
                          value: '0',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FutureBuilder<int>(
                          future: dbService.getUserWorkoutStreak(targetUserId),
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
                        child: GestureDetector(
                          onTap: () => _showFollowersList(targetUserId),
                          child: FutureBuilder<int>(
                            future: dbService.getFollowerCount(targetUserId),
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
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Body Metrics Card (Only show for own profile)
                if (isOwnProfile)
                  BodyMetricsCard(userData: userData),

                // Personal Info Card
                PersonalInfoCard(userData: userData, user: currentUser),

                if (isOwnProfile) ...[
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
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FollowersListSheet extends StatelessWidget {
  final String userId;
  
  const _FollowersListSheet({required this.userId});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Followers',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder(
              future: DatabaseService().getFollowers(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final followers = snapshot.data ?? [];
                
                if (followers.isEmpty) {
                  return const Center(
                    child: Text('No followers yet'),
                  );
                }
                
                return ListView.builder(
                  itemCount: followers.length,
                  itemBuilder: (context, index) {
                    final user = followers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user.profilePhoto != null 
                          ? NetworkImage(user.profilePhoto!) 
                          : null,
                        child: user.profilePhoto == null 
                          ? const Icon(Icons.person) 
                          : null,
                      ),
                      title: Text(user.name),
                      onTap: () {
                         // Close sheet and navigate to profile
                         Navigator.pop(context);
                         Navigator.push(
                           context,
                           MaterialPageRoute(
                             builder: (_) => ProfileScreen(viewUserId: user.uid),
                           ),
                         );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}