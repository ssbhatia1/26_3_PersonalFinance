import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final String type; // 'income', 'expense', 'transfer', 'other'
  final String icon;
  final String color;
  final String? parentId;

  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.parentId,
  });

  Color get colorValue {
    try {
      if (color.startsWith('0x') || color.startsWith('0X')) {
        return Color(int.parse(color));
      }
      return Color(int.parse('0xFF$color'));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  IconData get iconData {
    switch (icon) {
      case 'work':
        return Icons.work_rounded;
      case 'laptop':
        return Icons.laptop_mac_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'apartment':
        return Icons.apartment_rounded;
      case 'card_giftcard':
        return Icons.card_giftcard_rounded;
      case 'attach_money':
        return Icons.attach_money_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'shopping_cart':
        return Icons.shopping_cart_rounded;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      case 'directions_car':
        return Icons.directions_car_rounded;
      case 'medical_services':
        return Icons.medical_services_rounded;
      case 'movie':
        return Icons.movie_rounded;
      case 'subscriptions':
        return Icons.subscriptions_rounded;
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'swap_horiz':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'icon': icon,
      'color': color,
      'parent_id': parentId,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      icon: map['icon'] as String,
      color: map['color'] as String,
      parentId: map['parent_id'] as String?,
    );
  }
}
