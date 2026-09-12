import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Financial Runway Calculation Logic Tests', () {
    test('Calculates financial runway days correctly based on balance and outflow', () {
      const liquidBalance = 90000.0; // 90,000 INR
      const daysInPeriod = 30;
      const totalOutflow = 30000.0; // 30,000 INR in 30 days

      final avgDailyOutflow = totalOutflow / daysInPeriod; // 1,000 INR/day
      final runwayDays = (liquidBalance / avgDailyOutflow).round();

      expect(avgDailyOutflow, 1000.0);
      expect(runwayDays, 90); // 90 days of runway
    });

    test('Handles zero outflow as infinite runway without division by zero', () {
      const liquidBalance = 50000.0;
      const totalOutflow = 0.0;
      const daysInPeriod = 30;

      final avgDailyOutflow = totalOutflow / daysInPeriod;
      final runwayDays = avgDailyOutflow > 0 ? (liquidBalance / avgDailyOutflow).round() : null;

      expect(runwayDays, isNull);
    });

    test('Calculates weekly and monthly inflow/outflow averages', () {
      const daysInPeriod = 10;
      const totalInflow = 50000.0;
      const totalOutflow = 20000.0;

      final avgDailyInflow = totalInflow / daysInPeriod; // 5000
      final avgDailyOutflow = totalOutflow / daysInPeriod; // 2000

      final avgWeeklyInflow = avgDailyInflow * 7; // 35000
      final avgWeeklyOutflow = avgDailyOutflow * 7; // 14000

      final avgMonthlyInflow = avgDailyInflow * 30.4375; // 152187.5
      final avgMonthlyOutflow = avgDailyOutflow * 30.4375; // 60875.0

      expect(avgWeeklyInflow, 35000.0);
      expect(avgWeeklyOutflow, 14000.0);
      expect(avgMonthlyInflow, 152187.5);
      expect(avgMonthlyOutflow, 60875.0);
    });
  });
}
