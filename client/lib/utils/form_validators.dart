import 'package:flutter/material.dart';

/// Form validation utilities
class FormValidators {
  /// Email validation
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Password validation
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  /// Required field validation
  static String? required(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }
    return null;
  }

  /// Minimum length validation
  static String? minLength(String? value, int minLength, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }
    if (value.length < minLength) {
      return '${fieldName ?? 'This field'} must be at least $minLength characters';
    }
    return null;
  }

  /// Maximum length validation
  static String? maxLength(String? value, int maxLength, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return null; // Let required validator handle empty
    }
    if (value.length > maxLength) {
      return '${fieldName ?? 'This field'} must not exceed $maxLength characters';
    }
    return null;
  }

  /// Phone number validation
  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    final phoneRegex = RegExp(r'^[0-9]{10,15}$');
    if (!phoneRegex.hasMatch(value.replaceAll(RegExp(r'[\s\-\(\)]'), ''))) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  /// Numeric validation
  static String? numeric(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }
    if (double.tryParse(value) == null) {
      return '${fieldName ?? 'This field'} must be a number';
    }
    return null;
  }

  /// Positive number validation
  static String? positiveNumber(String? value, {String? fieldName}) {
    final numericError = numeric(value, fieldName: fieldName);
    if (numericError != null) return numericError;
    final num = double.tryParse(value!);
    if (num != null && num <= 0) {
      return '${fieldName ?? 'This field'} must be greater than 0';
    }
    return null;
  }

  /// Location validation (for source/destination)
  static String? location(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'Location'} is required';
    }
    if (value.trim().length < 3) {
      return 'Please enter a valid ${fieldName ?? 'location'}';
    }
    return null;
  }

  /// Friend code validation
  static String? friendCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Friend code is required';
    }
    final code = value.trim().toUpperCase();
    if (code.length != 5) {
      return 'Friend code must be exactly 5 characters';
    }
    final codeRegex = RegExp(r'^[A-Z0-9]{5}$');
    if (!codeRegex.hasMatch(code)) {
      return 'Friend code can only contain letters and numbers';
    }
    return null;
  }
}

/// Extension for TextEditingController validation
extension TextEditingControllerValidation on TextEditingController {
  String? validate(String? Function(String?) validator) {
    return validator(text);
  }
}

