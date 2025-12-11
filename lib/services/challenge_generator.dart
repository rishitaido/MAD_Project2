import 'dart:math';
import '../models/challenge_model.dart';

class ChallengeGenerator {
  static final Random _random = Random();

  static final List<Map<String, dynamic>> _challengeTemplates = [
    {
      'title': 'Weekly Warrior',
      'description': 'Complete {target} workouts this week',
      'type': ChallengeType.totalWorkouts,
      'minTarget': 3,
      'maxTarget': 7,
    },
    {
      'title': 'Exercise Machine',
      'description': 'Perform {target} different exercises',
      'type': ChallengeType.totalExercises,
      'minTarget': 15,
      'maxTarget': 30,
    },
    {
      'title': 'Time Grinder',
      'description': 'Train for {target} minutes total',
      'type': ChallengeType.totalMinutes,
      'minTarget': 60,
      'maxTarget': 180,
    },
    {
      'title': 'Consistency King',
      'description': 'Workout {target} days in a row',
      'type': ChallengeType.consecutiveDays,
      'minTarget': 3,
      'maxTarget': 7,
    },
    {
      'title': 'Beast Mode Activated',
      'description': 'Hit {target} workouts before the week ends',
      'type': ChallengeType.totalWorkouts,
      'minTarget': 4,
      'maxTarget': 6,
    },
    {
      'title': 'Volume Master',
      'description': 'Complete {target} exercises this week',
      'type': ChallengeType.totalExercises,
      'minTarget': 20,
      'maxTarget': 40,
    },
    {
      'title': 'Grind Time',
      'description': 'Spend {target} minutes training',
      'type': ChallengeType.totalMinutes,
      'minTarget': 90,
      'maxTarget': 150,
    },
    {
      'title': 'Streak Seeker',
      'description': 'Build a {target}-day workout streak',
      'type': ChallengeType.consecutiveDays,
      'minTarget': 4,
      'maxTarget': 7,
    },
  ];

  static ChallengeModel generateRandomChallenge({int durationDays = 7}) {
    final template = _challengeTemplates[_random.nextInt(_challengeTemplates.length)];
    
    final minTarget = template['minTarget'] as int;
    final maxTarget = template['maxTarget'] as int;
    final targetValue = minTarget + _random.nextInt(maxTarget - minTarget + 1);
    
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day);
    final endDate = startDate.add(Duration(days: durationDays));
    
    return ChallengeModel(
      id: '',
      title: template['title'] as String,
      description: (template['description'] as String).replaceAll('{target}', targetValue.toString()),
      type: template['type'] as ChallengeType,
      targetValue: targetValue,
      startDate: startDate,
      endDate: endDate,
      participants: [],
      leaderboard: {},
    );
  }

  static ChallengeModel createCustomChallenge({
    required String title,
    required ChallengeType type,
    required int targetValue,
    required int durationDays,
  }) {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day);
    final endDate = startDate.add(Duration(days: durationDays));
    
    String description;
    switch (type) {
      case ChallengeType.totalWorkouts:
        description = 'Complete $targetValue workouts';
        break;
      case ChallengeType.totalExercises:
        description = 'Perform $targetValue exercises';
        break;
      case ChallengeType.totalMinutes:
        description = 'Train for $targetValue minutes';
        break;
      case ChallengeType.consecutiveDays:
        description = 'Workout $targetValue days in a row';
        break;
    }
    
    return ChallengeModel(
      id: '',
      title: title,
      description: description,
      type: type,
      targetValue: targetValue,
      startDate: startDate,
      endDate: endDate,
      participants: [],
      leaderboard: {},
    );
  }
}