import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/core/security/crypto_utils.dart';
import 'package:personal_finance/data/models/account.dart';
import 'package:personal_finance/data/repositories/account_repository.dart';
import 'package:personal_finance/data/repositories/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase testDbManager;
  late AuthRepository authRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    testDbManager = AppDatabase.inMemory();
    authRepo = AuthRepository(testDbManager);
  });

  tearDown(() async {
    await testDbManager.close();
  });

  group('CryptoUtils Security & Tokenization', () {
    test('generateSalt returns cryptographically unique random salts', () {
      final salt1 = CryptoUtils.generateSalt();
      final salt2 = CryptoUtils.generateSalt();

      expect(salt1.isNotEmpty, isTrue);
      expect(salt2.isNotEmpty, isTrue);
      expect(salt1, isNot(equals(salt2)));
    });

    test('hashPassword produces identical hash for same salt and password', () {
      const password = 'Secur3Password!2026';
      const salt = 'random_salt_12345';

      final hash1 = CryptoUtils.hashPassword(password, salt);
      final hash2 = CryptoUtils.hashPassword(password, salt);

      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64)); // SHA-256 hex length
    });

    test('verifyPassword confirms valid credentials and rejects incorrect ones', () {
      const password = 'MySuperSecretPassword';
      final salt = CryptoUtils.generateSalt();
      final hash = CryptoUtils.hashPassword(password, salt);

      expect(CryptoUtils.verifyPassword(password, salt, hash), isTrue);
      expect(CryptoUtils.verifyPassword('WrongPassword', salt, hash), isFalse);
    });

    test('generateSessionToken produces 256-bit hexadecimal string', () {
      final token = CryptoUtils.generateSessionToken();
      expect(token.length, equals(64));
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(token), isTrue);
    });

    test('generateResetToken generates 6-digit numeric string', () {
      final code = CryptoUtils.generateResetToken();
      expect(code.length, equals(64 < 6 ? 64 : 6));
      expect(int.tryParse(code), isNotNull);
      expect(int.parse(code), inInclusiveRange(100000, 999999));
    });

    test('tokenizeSensitiveReference masks and generates surrogate token', () {
      const rawCard = '4111 2222 3333 9876';
      final tokenResult = CryptoUtils.tokenizeSensitiveReference(rawCard);

      expect(tokenResult['maskedDisplay'], equals('•••• 9876'));
      expect(tokenResult['surrogateToken']!.startsWith('tok_'), isTrue);
    });
  });

  group('AuthRepository Registration & Authentication', () {
    test('register successfully creates a new user and session', () async {
      final user = await authRepo.register(
        email: 'alice@example.com',
        username: 'alice_invest',
        password: 'Password123!',
        fullName: 'Alice Smith',
      );

      expect(user.id.isNotEmpty, isTrue);
      expect(user.email, equals('alice@example.com'));
      expect(user.username, equals('alice_invest'));
      expect(user.fullName, equals('Alice Smith'));

      // Verify password stored is hashed, not plain text
      expect(user.passwordHash, isNot(contains('Password123!')));
      expect(CryptoUtils.verifyPassword('Password123!', user.salt, user.passwordHash), isTrue);
    });

    test('register rejects duplicate email address', () async {
      await authRepo.register(
        email: 'bob@example.com',
        username: 'bob1',
        password: 'Password123!',
        fullName: 'Bob Brown',
      );

      expect(
        () => authRepo.register(
          email: 'bob@example.com',
          username: 'bob2',
          password: 'Password456!',
          fullName: 'Bob Brown Junior',
        ),
        throwsA(predicate((e) => e.toString().contains('already exists'))),
      );
    });

    test('register rejects duplicate username', () async {
      await authRepo.register(
        email: 'charlie1@example.com',
        username: 'charlie',
        password: 'Password123!',
        fullName: 'Charlie One',
      );

      expect(
        () => authRepo.register(
          email: 'charlie2@example.com',
          username: 'charlie',
          password: 'Password456!',
          fullName: 'Charlie Two',
        ),
        throwsA(predicate((e) => e.toString().contains('already taken'))),
      );
    });

    test('login succeeds with email or username', () async {
      await authRepo.register(
        email: 'dan@example.com',
        username: 'dan_trader',
        password: 'TradePassword!2026',
        fullName: 'Dan Trader',
      );

      // Login using email
      final userByEmail = await authRepo.login(
        usernameOrEmail: 'dan@example.com',
        password: 'TradePassword!2026',
      );
      expect(userByEmail.id.isNotEmpty, isTrue);

      // Login using username
      final userByUsername = await authRepo.login(
        usernameOrEmail: 'dan_trader',
        password: 'TradePassword!2026',
      );
      expect(userByUsername.id, equals(userByEmail.id));
    });

    test('login fails with wrong password or unknown user', () async {
      await authRepo.register(
        email: 'eve@example.com',
        username: 'eve_saver',
        password: 'EveSecretPassword',
        fullName: 'Eve Adams',
      );

      expect(
        () => authRepo.login(
          usernameOrEmail: 'eve@example.com',
          password: 'WrongPassword!',
        ),
        throwsA(predicate((e) => e.toString().contains('Incorrect password'))),
      );

      expect(
        () => authRepo.login(
          usernameOrEmail: 'nonexistent@example.com',
          password: 'Password123',
        ),
        throwsA(predicate((e) => e.toString().contains('Account not found'))),
      );
    });

    test('password reset request generates verification code and updates password', () async {
      await authRepo.register(
        email: 'frank@example.com',
        username: 'frank_h',
        password: 'OldPassword123',
        fullName: 'Frank Herbert',
      );

      // Request reset
      final code = await authRepo.requestPasswordReset('frank@example.com');
      expect(code.length, equals(6));

      // Reset with valid code
      await authRepo.resetPassword(
        email: 'frank@example.com',
        token: code,
        newPassword: 'BrandNewPassword456!',
      );

      // Verify login with new password succeeds
      final user = await authRepo.login(
        usernameOrEmail: 'frank@example.com',
        password: 'BrandNewPassword456!',
      );
      expect(user.id.isNotEmpty, isTrue);

      // Verify login with old password fails
      expect(
        () => authRepo.login(
          usernameOrEmail: 'frank@example.com',
          password: 'OldPassword123',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('tokenizeSensitiveData securely stores surrogate and masked representation', () async {
      final user = await authRepo.register(
        email: 'grace@example.com',
        username: 'grace_hopper',
        password: 'GracePassword123!',
        fullName: 'Grace Hopper',
      );

      final tokenResult = await authRepo.tokenizeSensitiveData(
        userId: user.id,
        sensitiveRawString: '9876 5432 1098 7654',
      );

      expect(tokenResult['maskedDisplay'], equals('•••• 7654'));
      expect(tokenResult['surrogateToken']!.startsWith('tok_'), isTrue);
    });

    test('logout clears session from database and preferences', () async {
      final user = await authRepo.register(
        email: 'helen@example.com',
        username: 'helen_k',
        password: 'HelenPassword123!',
        fullName: 'Helen Keller',
      );

      final restoredBefore = await authRepo.restoreSession();
      expect(restoredBefore?.id, equals(user.id));

      await authRepo.logout();

      final restoredAfter = await authRepo.restoreSession();
      expect(restoredAfter, isNull);
    });

    test('login succeeds with seeded default demo credentials (demouser / demo123)', () async {
      final demoUser = await authRepo.login(
        usernameOrEmail: 'demouser',
        password: 'demo123',
      );
      expect(demoUser.username, equals('demouser'));
      expect(demoUser.email, equals('demo@personalfinance.local'));
    });
  });

  group('Account Tokenization & Security', () {
    late AccountRepository accountRepo;

    setUp(() {
      accountRepo = AccountRepository(testDbManager);
    });

    test('generateAccountToken creates valid cryptographic surrogate token', () {
      final token = CryptoUtils.generateAccountToken();
      expect(token.startsWith('tok_acc_'), isTrue);
      expect(CryptoUtils.isAccountTokenValid(token), isTrue);
    });

    test('Account model provides valid fallback token when accountToken is null', () {
      const account = Account(
        id: 'acc-test-12345678',
        name: 'Test Checking',
        type: 'Bank Account',
        openingBalance: 1000.0,
        currentBalance: 1000.0,
      );
      expect(account.token.startsWith('tok_acc_'), isTrue);
    });

    test('createAccount automatically generates surrogate token if none provided', () async {
      const newAcc = Account(
        id: 'acc_auto_token_test',
        name: 'Auto Token Bank',
        type: 'Savings',
        openingBalance: 25000.0,
        currentBalance: 25000.0,
        maskedReference: '1234 5678 9012 3456',
      );

      await accountRepo.createAccount(newAcc);
      final retrieved = await accountRepo.getAccountById('acc_auto_token_test');
      expect(retrieved, isNotNull);
      expect(retrieved!.accountToken, isNotNull);
      expect(retrieved.token.startsWith('tok_'), isTrue);

      // Verify getAccountByToken retrieves the account
      final byToken = await accountRepo.getAccountByToken(retrieved.token);
      expect(byToken, isNotNull);
      expect(byToken!.id, equals('acc_auto_token_test'));
    });

    test('rotateAccountToken updates account token with a new surrogate token', () async {
      const testAcc = Account(
        id: 'acc_rotate_test',
        name: 'Rotation Bank',
        type: 'Checking',
        openingBalance: 5000.0,
        currentBalance: 5000.0,
      );

      await accountRepo.createAccount(testAcc);
      final original = await accountRepo.getAccountById('acc_rotate_test');
      final originalToken = original!.token;

      final rotated = await accountRepo.rotateAccountToken('acc_rotate_test');
      expect(rotated.token, isNot(equals(originalToken)));
      expect(rotated.token.startsWith('tok_acc_'), isTrue);
    });
  });
}

