import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/category.dart';
import '../../providers/category_provider.dart';

class CategoriesManagementScreen extends ConsumerStatefulWidget {
  const CategoriesManagementScreen({super.key});

  @override
  ConsumerState<CategoriesManagementScreen> createState() =>
      _CategoriesManagementScreenState();
}

class _CategoriesManagementScreenState
    extends ConsumerState<CategoriesManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openCategoryDialog([Category? existingCategory, String? defaultType]) {
    showDialog(
      context: context,
      builder: (ctx) => CategoryFormDialog(
        existingCategory: existingCategory,
        initialType: defaultType ??
            (_tabController.index == 0
                ? 'expense'
                : _tabController.index == 1
                    ? 'income'
                    : 'transfer'),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Category category) async {
    final count = await ref
        .read(categoryManagementProvider.notifier)
        .getTransactionCount(category.id);

    if (!context.mounted) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error),
              const SizedBox(width: 8),
              const Text('Delete Category?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete "${category.name}"?'),
              if (count > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$count transaction(s) currently reference this category.',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      final success = await ref
          .read(categoryManagementProvider.notifier)
          .deleteCategory(category.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Category "${category.name}" deleted'
                  : 'Failed to delete category',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(categoryManagementProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
          tabs: [
            Tab(text: 'Expenses (${state.expenseCategories.length})'),
            Tab(text: 'Income (${state.incomeCategories.length})'),
            Tab(text: 'Transfers (${state.transferCategories.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCategoryDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Category'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCategoryList(state.expenseCategories, 'expense'),
                _buildCategoryList(state.incomeCategories, 'income'),
                _buildCategoryList(state.transferCategories, 'transfer'),
              ],
            ),
    );
  }

  Widget _buildCategoryList(List<Category> categories, String type) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.category_outlined, size: 48, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              'No $type categories found.',
              style: const TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openCategoryDialog(null, type),
              icon: const Icon(Icons.add, size: 16),
              label: Text('Add $type category'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final cat = categories[index];
        return Card(
          margin: EdgeInsets.zero,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cat.colorValue.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(cat.iconData, color: cat.colorValue, size: 22),
              ),
            ),
            title: Text(
              cat.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Text(
              'Type: ${cat.type.toUpperCase()}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit Category',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _openCategoryDialog(cat),
                ),
                IconButton(
                  tooltip: 'Delete Category',
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                  onPressed: () => _confirmDelete(context, cat),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CategoryFormDialog extends ConsumerStatefulWidget {
  final Category? existingCategory;
  final String initialType;

  const CategoryFormDialog({
    super.key,
    this.existingCategory,
    this.initialType = 'expense',
  });

  @override
  ConsumerState<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late String _selectedType;
  late String _selectedIcon;
  late String _selectedColor;
  bool _isSaving = false;

  static const List<String> _availableIcons = [
    'restaurant',
    'shopping_cart',
    'shopping_bag',
    'directions_car',
    'home',
    'apartment',
    'bolt',
    'medical_services',
    'school',
    'work',
    'laptop',
    'trending_up',
    'card_giftcard',
    'attach_money',
    'movie',
    'subscriptions',
    'account_balance',
    'swap_horiz',
    'category',
  ];

  static const List<String> _availableColors = [
    '0xFF10B981', // Emerald
    '0xFF059669', // Dark Green
    '0xFF3B82F6', // Blue
    '0xFF6366F1', // Indigo
    '0xFF8B5CF6', // Purple
    '0xFFEC4899', // Pink
    '0xFFEF4444', // Red / Rose
    '0xFFF59E0B', // Amber
    '0xFF14B8A6', // Teal
    '0xFF06B6D4', // Cyan
    '0xFF64748B', // Slate
  ];

  @override
  void initState() {
    super.initState();
    final cat = widget.existingCategory;
    _nameController = TextEditingController(text: cat?.name ?? '');
    _selectedType = cat?.type ?? widget.initialType;
    _selectedIcon = cat?.icon ?? 'category';
    _selectedColor = cat?.color ?? '0xFF10B981';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'shopping_cart':
        return Icons.shopping_cart_rounded;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'directions_car':
        return Icons.directions_car_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'apartment':
        return Icons.apartment_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      case 'medical_services':
        return Icons.medical_services_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'work':
        return Icons.work_rounded;
      case 'laptop':
        return Icons.laptop_mac_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'card_giftcard':
        return Icons.card_giftcard_rounded;
      case 'attach_money':
        return Icons.attach_money_rounded;
      case 'movie':
        return Icons.movie_rounded;
      case 'subscriptions':
        return Icons.subscriptions_rounded;
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'swap_horiz':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Color _getColor(String colorStr) {
    try {
      if (colorStr.startsWith('0x') || colorStr.startsWith('0X')) {
        return Color(int.parse(colorStr));
      }
      return Color(int.parse('0xFF$colorStr'));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final isEditing = widget.existingCategory != null;
    final catId = widget.existingCategory?.id ?? 'cat_${const Uuid().v4().substring(0, 8)}';

    final category = Category(
      id: catId,
      name: _nameController.text.trim(),
      type: _selectedType,
      icon: _selectedIcon,
      color: _selectedColor,
    );

    bool success;
    if (isEditing) {
      success = await ref.read(categoryManagementProvider.notifier).updateCategory(category);
    } else {
      success = await ref.read(categoryManagementProvider.notifier).createCategory(category);
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Category "${category.name}" saved.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save category.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingCategory != null;
    final currentColor = _getColor(_selectedColor);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(isEditing ? 'Edit Category' : 'New Category'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Preview Badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: currentColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: currentColor.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getIconData(_selectedIcon), color: currentColor, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          _nameController.text.isEmpty
                              ? 'Preview Category'
                              : _nameController.text,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: currentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Category Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                    hintText: 'e.g. Pet Care, Internet, Gym',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter category name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Category Type
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Category Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'expense', child: Text('Expense')),
                    DropdownMenuItem(value: 'income', child: Text('Income')),
                    DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedType = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 18),

                // Icon Picker
                const Text(
                  'Select Icon',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableIcons.map((iconName) {
                    final isSelected = _selectedIcon == iconName;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedIcon = iconName;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? currentColor.withOpacity(0.25)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? currentColor
                                : Colors.grey.withOpacity(0.3),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          _getIconData(iconName),
                          size: 20,
                          color: isSelected ? currentColor : Colors.grey,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // Color Picker
                const Text(
                  'Select Color',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _availableColors.map((colorHex) {
                    final color = _getColor(colorHex);
                    final isSelected = _selectedColor == colorHex;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedColor = colorHex;
                        });
                      },
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }
}
