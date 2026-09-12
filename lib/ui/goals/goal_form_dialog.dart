import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/financial_goal.dart';
import '../../providers/account_provider.dart';
import '../../providers/goal_provider.dart';

class GoalFormDialog extends ConsumerStatefulWidget {
  final FinancialGoal? goalToEdit;

  const GoalFormDialog({super.key, this.goalToEdit});

  @override
  ConsumerState<GoalFormDialog> createState() => _GoalFormDialogState();
}

class _GoalFormDialogState extends ConsumerState<GoalFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  late TextEditingController _nameController;
  late TextEditingController _targetController;
  late TextEditingController _currentController;
  DateTime _targetDate = DateTime.now().add(const Duration(days: 365));
  String? _linkedAccountId;

  @override
  void initState() {
    super.initState();
    final g = widget.goalToEdit;
    _nameController = TextEditingController(text: g?.name ?? '');
    _targetController = TextEditingController(text: g != null ? g.targetAmount.toString() : '');
    _currentController = TextEditingController(text: g != null ? g.currentAmount.toString() : '0.0');

    if (g != null) {
      _targetDate = g.targetDate;
      _linkedAccountId = g.linkedAccountId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _currentController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final target = double.tryParse(_targetController.text.trim()) ?? 0.0;
    final current = double.tryParse(_currentController.text.trim()) ?? 0.0;

    if (target <= 0) return;

    if (widget.goalToEdit != null) {
      final updated = widget.goalToEdit!.copyWith(
        name: name,
        targetAmount: target,
        currentAmount: current,
        targetDate: _targetDate,
        linkedAccountId: _linkedAccountId,
        isCompleted: current >= target,
      );
      await ref.read(goalProvider.notifier).updateGoal(updated);
    } else {
      final newGoal = FinancialGoal(
        id: _uuid.v4(),
        name: name,
        targetAmount: target,
        currentAmount: current,
        targetDate: _targetDate,
        linkedAccountId: _linkedAccountId,
        isCompleted: current >= target,
      );
      await ref.read(goalProvider.notifier).createGoal(newGoal);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountProvider).accounts;
    final isEditing = widget.goalToEdit != null;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? 'Edit Financial Goal' : 'Create Financial Goal',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Goal Target Name *',
                      hintText: 'e.g. Emergency Fund, Vacation, Car',
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _targetController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Target Amount *',
                      hintText: '0.00',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter amount';
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) return 'Must be greater than 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _currentController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Current Saved Amount',
                      hintText: '0.00',
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String?>(
                    value: accounts.any((a) => a.id == _linkedAccountId) ? _linkedAccountId : null,
                    decoration: const InputDecoration(
                      labelText: 'Linked Savings Account (Optional)',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('None / General Savings')),
                      ...accounts.map((a) => DropdownMenuItem<String?>(value: a.id, child: Text(a.name))),
                    ],
                    onChanged: (v) => setState(() => _linkedAccountId = v),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withAlpha(80)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.flag_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text('Target Date: ${_targetDate.day}/${_targetDate.month}/${_targetDate.year}'),
                            ],
                          ),
                          const Icon(Icons.edit_calendar_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _save,
                        child: Text(isEditing ? 'Save' : 'Create Goal'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
