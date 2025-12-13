import 'package:flutter/material.dart';

/// Helper functions for profile screen formatting and calculations
class ProfileHelpers {
  /// Format a DateTime to display as "Month Year"
  static String formatDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  /// Calculate age from date of birth
  static int calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  /// Format height in inches to feet and inches (e.g., "5'10\"")
  static String formatHeight(double heightInInches) {
    final feet = heightInInches ~/ 12;
    final inches = (heightInInches % 12).round();
    return '$feet\'$inches"';
  }

  /// Calculate BMI from height (inches) and weight (pounds)
  /// Formula: (weight in pounds × 703) / (height in inches)²
  static double calculateBMI(double heightInInches, double weightInPounds) {
    return (weightInPounds * 703) / (heightInInches * heightInInches);
  }

  /// Get color for BMI value based on healthy ranges
  /// - Green: Healthy weight (18.5-24.9)
  /// - Orange: Underweight or Overweight
  /// - Red: Obese (≥30)
  static Color getBMIColor(double bmi) {
    if (bmi < 18.5) {
      return Colors.orange; // Underweight
    } else if (bmi >= 18.5 && bmi < 25) {
      return Colors.green; // Healthy weight
    } else if (bmi >= 25 && bmi < 30) {
      return Colors.orange; // Overweight
    } else {
      return Colors.red; // Obese
    }
  }
}
