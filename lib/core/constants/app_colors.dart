import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Dark Theme Palette
  static const Color darkBg = Color(0xFF0A0E17);
  static const Color darkSurface = Color(0xFF131B2A);
  static const Color darkCard = Color(0xFF1A2333);
  static const Color darkCardElevated = Color(0xFF222F45);
  static const Color darkBorder = Color(0xFF2D3A4F);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Light Theme Palette
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardElevated = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Semantic & Financial Palette
  static const Color primary = Color(0xFF10B981); // Emerald
  static const Color primaryLight = Color(0xFF34D399);
  static const Color primaryDark = Color(0xFF059669);

  static const Color income = Color(0xFF10B981); // Vibrant Emerald Green
  static const Color incomeBg = Color(0x1A10B981);

  static const Color expense = Color(0xFFF43F5E); // Radiant Rose Coral
  static const Color expenseBg = Color(0x1AF43F5E);

  static const Color transfer = Color(0xFF6366F1); // Indigo
  static const Color transferBg = Color(0x1A6366F1);

  static const Color asset = Color(0xFF06B6D4); // Cyan
  static const Color liability = Color(0xFFF59E0B); // Amber
  static const Color investment = Color(0xFF8B5CF6); // Purple
  static const Color goal = Color(0xFFEC4899); // Pink

  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Category Color Palette
  static const List<Color> categoryColors = [
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
    Color(0xFFF43F5E),
    Color(0xFF14B8A6),
    Color(0xFF84CC16),
    Color(0xFFA855F7),
    Color(0xFFEAB308),
    Color(0xFF64748B),
  ];
}
