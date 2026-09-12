enum BudgetStrategyType {
  fiftyThirtyTwenty,
  zeroBased,
  payYourselfFirst,
  envelope,
  custom,
}

extension BudgetStrategyTypeExt on BudgetStrategyType {
  String get displayName {
    switch (this) {
      case BudgetStrategyType.fiftyThirtyTwenty:
        return '50/30/20 Rule';
      case BudgetStrategyType.zeroBased:
        return 'Zero-Based';
      case BudgetStrategyType.payYourselfFirst:
        return 'Pay Yourself First';
      case BudgetStrategyType.envelope:
        return 'Category Envelopes';
      case BudgetStrategyType.custom:
        return 'Custom Proportional';
    }
  }

  String get shortName {
    switch (this) {
      case BudgetStrategyType.fiftyThirtyTwenty:
        return '50/30/20';
      case BudgetStrategyType.zeroBased:
        return 'Zero-Based';
      case BudgetStrategyType.payYourselfFirst:
        return 'Reverse';
      case BudgetStrategyType.envelope:
        return 'Envelopes';
      case BudgetStrategyType.custom:
        return 'Custom';
    }
  }

  String get description {
    switch (this) {
      case BudgetStrategyType.fiftyThirtyTwenty:
        return '50% Essential Needs, 30% Discretionary Wants, 20% Savings & Debt Repayment.';
      case BudgetStrategyType.zeroBased:
        return 'Every unit of income is given a job so Total Income - (Expenses + Savings) = 0.';
      case BudgetStrategyType.payYourselfFirst:
        return 'Prioritizes setting aside savings & investments first; live freely on the remainder.';
      case BudgetStrategyType.envelope:
        return 'Classic envelope system with dedicated fixed spending caps for each category.';
      case BudgetStrategyType.custom:
        return 'User-customized proportional percentage targets across budget buckets.';
    }
  }
}

enum BudgetBucket {
  needs,
  wants,
  savingsDebt,
}

extension BudgetBucketExt on BudgetBucket {
  String get displayName {
    switch (this) {
      case BudgetBucket.needs:
        return 'Needs (Essentials)';
      case BudgetBucket.wants:
        return 'Wants (Discretionary)';
      case BudgetBucket.savingsDebt:
        return 'Savings & Debt';
    }
  }
}

class BudgetStrategyHelper {
  BudgetStrategyHelper._();

  /// Classifies a category id or name into Needs, Wants, or Savings/Debt
  static BudgetBucket classifyCategory(String? categoryId, String? categoryName) {
    final id = (categoryId ?? '').toLowerCase();
    final name = (categoryName ?? '').toLowerCase();

    // Savings & Debt
    if (id.contains('emi') ||
        id.contains('loan') ||
        id.contains('invest') ||
        name.contains('loan') ||
        name.contains('emi') ||
        name.contains('invest') ||
        name.contains('savings') ||
        name.contains('debt')) {
      return BudgetBucket.savingsDebt;
    }

    // Needs (Essentials)
    if (id.contains('grocer') ||
        id.contains('rent') ||
        id.contains('utilit') ||
        id.contains('transport') ||
        id.contains('fuel') ||
        id.contains('health') ||
        id.contains('medical') ||
        id.contains('educat') ||
        name.contains('grocer') ||
        name.contains('rent') ||
        name.contains('housing') ||
        name.contains('utilit') ||
        name.contains('bill') ||
        name.contains('transport') ||
        name.contains('fuel') ||
        name.contains('health') ||
        name.contains('medical') ||
        name.contains('educat')) {
      return BudgetBucket.needs;
    }

    // Default to Wants (Discretionary)
    return BudgetBucket.wants;
  }

  /// Calculates target allocation percentages based on active strategy
  static Map<BudgetBucket, double> getStrategyTargetPercentages(
    BudgetStrategyType strategy, {
    Map<BudgetBucket, double>? customPercentages,
  }) {
    switch (strategy) {
      case BudgetStrategyType.fiftyThirtyTwenty:
        return {
          BudgetBucket.needs: 50.0,
          BudgetBucket.wants: 30.0,
          BudgetBucket.savingsDebt: 20.0,
        };
      case BudgetStrategyType.zeroBased:
        return {
          BudgetBucket.needs: 50.0,
          BudgetBucket.wants: 25.0,
          BudgetBucket.savingsDebt: 25.0,
        };
      case BudgetStrategyType.payYourselfFirst:
        return {
          BudgetBucket.savingsDebt: 30.0,
          BudgetBucket.needs: 45.0,
          BudgetBucket.wants: 25.0,
        };
      case BudgetStrategyType.envelope:
        return {
          BudgetBucket.needs: 50.0,
          BudgetBucket.wants: 35.0,
          BudgetBucket.savingsDebt: 15.0,
        };
      case BudgetStrategyType.custom:
        return customPercentages ??
            {
              BudgetBucket.needs: 50.0,
              BudgetBucket.wants: 30.0,
              BudgetBucket.savingsDebt: 20.0,
            };
    }
  }

  /// Computes strategy adherence score (0 - 100%)
  static double computeComplianceScore({
    required double targetNeeds,
    required double actualNeeds,
    required double targetWants,
    required double actualWants,
    required double targetSavings,
    required double actualSavings,
  }) {
    if (targetNeeds <= 0 && targetWants <= 0 && targetSavings <= 0) return 100.0;

    double score = 100.0;

    // Penalty for overspending on Needs
    if (actualNeeds > targetNeeds && targetNeeds > 0) {
      final overPct = ((actualNeeds - targetNeeds) / targetNeeds) * 100;
      score -= overPct.clamp(0.0, 35.0);
    }

    // Penalty for overspending on Wants
    if (actualWants > targetWants && targetWants > 0) {
      final overPct = ((actualWants - targetWants) / targetWants) * 100;
      score -= (overPct * 1.2).clamp(0.0, 45.0);
    }

    // Penalty for underfunding Savings
    if (actualSavings < targetSavings && targetSavings > 0) {
      final underPct = ((targetSavings - actualSavings) / targetSavings) * 100;
      score -= (underPct * 0.8).clamp(0.0, 30.0);
    }

    return score.clamp(0.0, 100.0);
  }
}
