import 'package:uuid/uuid.dart';
import '../security/crypto_utils.dart';

class SeedData {
  SeedData._();

  static const _uuid = Uuid();

  static final List<Map<String, dynamic>> defaultCategories = [
    // Income Categories
    {
      'id': 'cat_inc_salary',
      'name': 'Salary',
      'type': 'income',
      'icon': 'work',
      'color': '0xFF10B981',
      'parent_id': null,
    },
    {
      'id': 'cat_inc_freelance',
      'name': 'Freelancing / Business',
      'type': 'income',
      'icon': 'laptop',
      'color': '0xFF3B82F6',
      'parent_id': null,
    },
    {
      'id': 'cat_inc_investment',
      'name': 'Investment & Dividends',
      'type': 'income',
      'icon': 'trending_up',
      'color': '0xFF8B5CF6',
      'parent_id': null,
    },
    {
      'id': 'cat_inc_rental',
      'name': 'Rental Income',
      'type': 'income',
      'icon': 'home',
      'color': '0xFF06B6D4',
      'parent_id': null,
    },
    {
      'id': 'cat_inc_cashback',
      'name': 'Cashback & Rewards',
      'type': 'income',
      'icon': 'card_giftcard',
      'color': '0xFFF59E0B',
      'parent_id': null,
    },
    {
      'id': 'cat_inc_other',
      'name': 'Other Income',
      'type': 'income',
      'icon': 'attach_money',
      'color': '0xFF14B8A6',
      'parent_id': null,
    },

    // Expense Categories
    {
      'id': 'cat_exp_food',
      'name': 'Food & Dining',
      'type': 'expense',
      'icon': 'restaurant',
      'color': '0xFFF43F5E',
      'parent_id': null,
    },
    {
      'id': 'cat_exp_groceries',
      'name': 'Groceries',
      'type': 'expense',
      'icon': 'shopping_cart',
      'color': '0xFFF97316',
      'parent_id': null,
    },
    {
      'id': 'cat_exp_rent',
      'name': 'Housing & Rent',
      'type': 'expense',
      'icon': 'apartment',
      'color': '0xFFEC4899',
      'parent_id': null,
    },
    {
      'id': 'cat_exp_utilities',
      'name': 'Utilities & Bills',
      'type': 'expense',
      'icon': 'bolt',
      'color': '0xFFEAB308',
      'parent_id': null,
    },
    {
      'id': 'cat_exp_transport',
      'name': 'Transport & Fuel',
      'type': 'expense',
      'icon': 'directions_car',
      'color': '0xFF06B6D4',
      'parent_id': null,
    },
    {
      'id': 'cat_exp_shopping',
      'name': 'Shopping',
      'type': 'expense',
      'icon': 'shopping_bag',
      'color': '0xFF8B5CF6',
      'parent_id': null,
    },
    {
      'id': 'cat_exp_healthcare',
      'name': 'Healthcare & Medical',
      'type': 'expense',
      'icon': 'medical_services',
      'color': '0xFFEF4444',
      'parent_id': null,
    },
    {
      'id': 'cat_exp_entertainment',
      'name': 'Entertainment & Leisure',
      'type': 'expense',
      'icon': 'movie',
      'color': '0xFFA855F7',
      'parent_id': null,
    },
    {
      'id': 'cat_exp_subscriptions',
      'name': 'Subscriptions',
      'type': 'expense',
      'icon': 'subscriptions',
      'color': '0xFF6366F1',
      'parent_id': null,
    },
    {
      'id': 'cat_exp_emi',
      'name': 'Loans & EMIs',
      'type': 'expense',
      'icon': 'account_balance',
      'color': '0xFFF59E0B',
      'parent_id': null,
    },
    {
      'id': 'cat_exp_education',
      'name': 'Education',
      'type': 'expense',
      'icon': 'school',
      'color': '0xFF3B82F6',
      'parent_id': null,
    },
    {
      'id': 'cat_exp_other',
      'name': 'Other Expense',
      'type': 'expense',
      'icon': 'receipt_long',
      'color': '0xFF64748B',
      'parent_id': null,
    },

    // Transfer Category
    {
      'id': 'cat_transfer_general',
      'name': 'Account Transfer',
      'type': 'transfer',
      'icon': 'swap_horiz',
      'color': '0xFF6366F1',
      'parent_id': null,
    },
  ];

  static final List<Map<String, dynamic>> defaultAccounts = [];

  static List<Map<String, dynamic>> generateDemoTransactions() => [];

  static Map<String, dynamic> getDefaultDemoUser() {
    const salt = 's4lt_d3m0_2026';
    final hash = CryptoUtils.hashPassword('demo123', salt);
    final now = DateTime.now().toIso8601String();
    return {
      'id': 'usr_demo_primary',
      'email': 'demo@personalfinance.local',
      'username': 'demouser',
      'full_name': 'Alex Johnson',
      'password_hash': hash,
      'salt': salt,
      'reset_token': null,
      'reset_token_expiry': null,
      'created_at': now,
      'updated_at': now,
    };
  }
}
