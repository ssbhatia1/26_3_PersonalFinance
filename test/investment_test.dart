import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/data/models/investment.dart';
import 'package:personal_finance/data/repositories/investment_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Investment Model Unit Tests', () {
    test('Calculates profit/loss and ROI percentage correctly', () {
      final inv = Investment(
        id: 'inv-1',
        name: 'Nifty 50 Index Fund',
        type: InvestmentType.mutualFund,
        investedAmount: 50000,
        currentValue: 62500,
        expectedReturnRate: 12.0,
        startDate: DateTime(2025, 1, 1),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(inv.profitLoss, 12500.0);
      expect(inv.profitLossPercentage, 25.0);
      expect(inv.isProfitable, isTrue);
    });

    test('Calculates loss and negative ROI correctly', () {
      final inv = Investment(
        id: 'inv-2',
        name: 'Tech Growth Stock',
        type: InvestmentType.stock,
        investedAmount: 20000,
        currentValue: 16000,
        expectedReturnRate: 15.0,
        startDate: DateTime(2025, 1, 1),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(inv.profitLoss, -4000.0);
      expect(inv.profitLossPercentage, -20.0);
      expect(inv.isProfitable, isFalse);
    });

    test('Calculates expected returns on fixed deposit', () {
      final start = DateTime(2025, 1, 1);
      final maturity = DateTime(2026, 1, 1);
      final fd = Investment(
        id: 'inv-3',
        name: 'HDFC 1-Yr Fixed Deposit',
        type: InvestmentType.fd,
        investedAmount: 100000,
        currentValue: 100000,
        expectedReturnRate: 7.5,
        startDate: start,
        maturityDate: maturity,
        maturityAmount: 107500,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(fd.expectedReturns, 7500.0);
    });

    test('Serializes toMap and fromMap accurately', () {
      final inv = Investment(
        id: 'inv-4',
        name: 'Sovereign Gold Bond',
        type: InvestmentType.bond,
        accountId: 'acc-1',
        investedAmount: 25000,
        currentValue: 27800,
        expectedReturnRate: 2.5,
        startDate: DateTime(2024, 6, 15),
        maturityDate: DateTime(2032, 6, 15),
        frequency: 'One-time',
        maturityAmount: 40000,
        notes: 'RBI SGB 2024-25 Series I',
        status: 'active',
        createdAt: DateTime(2024, 6, 15),
        updatedAt: DateTime(2024, 6, 15),
      );

      final map = inv.toMap();
      final revived = Investment.fromMap(map);

      expect(revived.id, inv.id);
      expect(revived.name, inv.name);
      expect(revived.type, InvestmentType.bond);
      expect(revived.accountId, 'acc-1');
      expect(revived.investedAmount, 25000.0);
      expect(revived.currentValue, 27800.0);
      expect(revived.notes, 'RBI SGB 2024-25 Series I');
    });
  });

  group('InvestmentRepository Integration Tests', () {
    late AppDatabase db;
    late InvestmentRepository repo;

    setUp(() {
      db = AppDatabase.inMemory();
      repo = InvestmentRepository(db);
    });

    test('Creates, retrieves, updates, and summarizes investments', () async {
      final inv1 = Investment(
        id: 'test-inv-1',
        name: 'Fixed Deposit 1',
        type: InvestmentType.fd,
        investedAmount: 50000,
        currentValue: 50000,
        expectedReturnRate: 7.0,
        startDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final inv2 = Investment(
        id: 'test-inv-2',
        name: 'Bluechip Mutual Fund',
        type: InvestmentType.mutualFund,
        investedAmount: 30000,
        currentValue: 36000,
        expectedReturnRate: 12.0,
        startDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.createInvestment(inv1);
      await repo.createInvestment(inv2);

      final all = await repo.getAllInvestments();
      expect(all.length, 2);

      // Verify portfolio summary calculation
      final summary = await repo.getInvestmentSummary();
      expect(summary['totalInvested'], 80000.0);
      expect(summary['totalCurrentValue'], 86000.0);
      expect(summary['totalProfitLoss'], 6000.0);
      expect(summary['activeCount'], 2);

      // Update current market value
      await repo.updateInvestment(inv2.copyWith(currentValue: 39000));
      final updatedSummary = await repo.getInvestmentSummary();
      expect(updatedSummary['totalCurrentValue'], 89000.0);
      expect(updatedSummary['totalProfitLoss'], 9000.0);

      // Soft delete
      await repo.deleteInvestment('test-inv-1');
      final activeList = await repo.getAllInvestments();
      expect(activeList.length, 1);
      expect(activeList.first.id, 'test-inv-2');
    });
  });
}
