import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_tables.dart';
import '../../core/security/crypto_utils.dart';
import '../models/user.dart';
import '../models/user_session.dart';

class AuthRepository {
  final AppDatabase _db;
  static const String _prefSessionKey = 'app_session_token';
  static const _uuid = Uuid();

  AuthRepository(this._db);

  Future<Database> get _database => _db.database;

  /// Restores active session if valid token exists in SharedPreferences and SQLite
  Future<User?> restoreSession() async {
    try {
      await _db.ensureTablesAndDemoUser();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_prefSessionKey);
      if (token == null || token.isEmpty) return null;

      final db = await _database;
      final sessionRows = await db.query(
        DatabaseTables.userSessions,
        where: 'token = ?',
        whereArgs: [token],
        limit: 1,
      );

      if (sessionRows.isEmpty) {
        await prefs.remove(_prefSessionKey);
        return null;
      }

      final session = UserSession.fromMap(sessionRows.first);
      if (session.isExpired) {
        await db.delete(
          DatabaseTables.userSessions,
          where: 'token = ?',
          whereArgs: [token],
        );
        await prefs.remove(_prefSessionKey);
        return null;
      }

      final userRows = await db.query(
        DatabaseTables.users,
        where: 'id = ?',
        whereArgs: [session.userId],
        limit: 1,
      );

      if (userRows.isEmpty) {
        await prefs.remove(_prefSessionKey);
        return null;
      }

      return User.fromMap(userRows.first);
    } catch (_) {
      return null;
    }
  }

  /// Authenticates user with username/email and password
  Future<User> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final cleanInput = usernameOrEmail.trim().toLowerCase();
    if (cleanInput.isEmpty) {
      throw Exception('Please enter your email or username.');
    }
    if (password.isEmpty) {
      throw Exception('Please enter your password.');
    }

    // Ensure users and session tables and demo seed user are present
    await _db.ensureTablesAndDemoUser();

    final db = await _database;
    final rows = await db.query(
      DatabaseTables.users,
      where: 'LOWER(email) = ? OR LOWER(username) = ?',
      whereArgs: [cleanInput, cleanInput],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('Account not found. Please check your credentials or sign up.');
    }

    final user = User.fromMap(rows.first);
    final isValid = CryptoUtils.verifyPassword(password, user.salt, user.passwordHash);
    if (!isValid) {
      throw Exception('Incorrect password. Please try again.');
    }

    // Generate secure session token (30 days validity)
    final token = CryptoUtils.generateSessionToken();
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(days: 30));

    final session = UserSession(
      token: token,
      userId: user.id,
      createdAt: now,
      expiresAt: expiresAt,
    );

    await db.insert(
      DatabaseTables.userSessions,
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Save session in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSessionKey, token);

    return user;
  }

  /// Registers a new user account
  Future<User> register({
    required String email,
    required String username,
    required String password,
    required String fullName,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanUsername = username.trim().toLowerCase();
    final cleanName = fullName.trim();

    if (cleanEmail.isEmpty || !cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      throw Exception('Please enter a valid email address.');
    }
    if (cleanUsername.isEmpty || cleanUsername.length < 3) {
      throw Exception('Username must be at least 3 characters.');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters long.');
    }
    if (cleanName.isEmpty) {
      throw Exception('Please enter your full name.');
    }

    await _db.ensureTablesAndDemoUser();
    final db = await _database;

    // Check duplicate email
    final emailExists = await db.query(
      DatabaseTables.users,
      where: 'LOWER(email) = ?',
      whereArgs: [cleanEmail],
      limit: 1,
    );
    if (emailExists.isNotEmpty) {
      throw Exception('An account with this email address already exists.');
    }

    // Check duplicate username
    final usernameExists = await db.query(
      DatabaseTables.users,
      where: 'LOWER(username) = ?',
      whereArgs: [cleanUsername],
      limit: 1,
    );
    if (usernameExists.isNotEmpty) {
      throw Exception('This username is already taken. Please choose another.');
    }

    final salt = CryptoUtils.generateSalt();
    final passwordHash = CryptoUtils.hashPassword(password, salt);
    final now = DateTime.now();

    final newUser = User(
      id: _uuid.v4(),
      email: cleanEmail,
      username: cleanUsername,
      fullName: cleanName,
      passwordHash: passwordHash,
      salt: salt,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert(DatabaseTables.users, newUser.toMap());

    // Automatically create session
    final token = CryptoUtils.generateSessionToken();
    final expiresAt = now.add(const Duration(days: 30));
    final session = UserSession(
      token: token,
      userId: newUser.id,
      createdAt: now,
      expiresAt: expiresAt,
    );
    await db.insert(
      DatabaseTables.userSessions,
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSessionKey, token);

    return newUser;
  }

  /// Generates a 6-digit password reset token valid for 15 minutes
  Future<String> requestPasswordReset(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) {
      throw Exception('Please enter your email address.');
    }

    await _db.ensureTablesAndDemoUser();
    final db = await _database;
    final rows = await db.query(
      DatabaseTables.users,
      where: 'LOWER(email) = ?',
      whereArgs: [cleanEmail],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('No account associated with this email address.');
    }

    final resetToken = CryptoUtils.generateResetToken();
    final expiry = DateTime.now().add(const Duration(minutes: 15));

    await db.update(
      DatabaseTables.users,
      {
        'reset_token': resetToken,
        'reset_token_expiry': expiry.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'LOWER(email) = ?',
      whereArgs: [cleanEmail],
    );

    return resetToken;
  }

  /// Verifies token and updates password
  Future<void> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanToken = token.trim();

    if (newPassword.length < 6) {
      throw Exception('New password must be at least 6 characters long.');
    }

    final db = await _database;
    final rows = await db.query(
      DatabaseTables.users,
      where: 'LOWER(email) = ?',
      whereArgs: [cleanEmail],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('Account not found.');
    }

    final user = User.fromMap(rows.first);
    if (user.resetToken == null || user.resetToken != cleanToken) {
      throw Exception('Invalid verification code. Please check and try again.');
    }

    if (user.resetTokenExpiry == null || DateTime.now().isAfter(user.resetTokenExpiry!)) {
      throw Exception('Verification code has expired. Please request a new one.');
    }

    // Update password with fresh salt
    final newSalt = CryptoUtils.generateSalt();
    final newHash = CryptoUtils.hashPassword(newPassword, newSalt);

    await db.update(
      DatabaseTables.users,
      {
        'password_hash': newHash,
        'salt': newSalt,
        'reset_token': null,
        'reset_token_expiry': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  /// Logs out user by clearing session
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_prefSessionKey);
    if (token != null) {
      final db = await _database;
      await db.delete(
        DatabaseTables.userSessions,
        where: 'token = ?',
        whereArgs: [token],
      );
      await prefs.remove(_prefSessionKey);
    }
  }

  /// Tokenizes sensitive data and records surrogate token in database
  Future<Map<String, String>> tokenizeSensitiveData({
    required String userId,
    required String sensitiveRawString,
  }) async {
    final result = CryptoUtils.tokenizeSensitiveReference(sensitiveRawString);
    final db = await _database;
    final tokenId = _uuid.v4();

    await db.insert(
      DatabaseTables.sensitiveTokens,
      {
        'token_id': tokenId,
        'user_id': userId,
        'masked_value': result['maskedDisplay']!,
        'tokenized_surrogate': result['surrogateToken']!,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return result;
  }

  /// Updates user profile details (full name, email, username)
  Future<User> updateProfile({
    required String userId,
    required String fullName,
    required String email,
    required String username,
  }) async {
    final cleanName = fullName.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanUsername = username.trim().toLowerCase();

    if (cleanName.isEmpty) {
      throw Exception('Full name cannot be empty.');
    }
    if (cleanEmail.isEmpty || !cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      throw Exception('Please enter a valid email address.');
    }
    if (cleanUsername.isEmpty || cleanUsername.length < 3) {
      throw Exception('Username must be at least 3 characters long.');
    }

    final db = await _database;

    // Verify user exists
    final currentRows = await db.query(
      DatabaseTables.users,
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (currentRows.isEmpty) {
      throw Exception('User account not found.');
    }

    final currentUser = User.fromMap(currentRows.first);

    // Check email uniqueness if email changed
    if (cleanEmail != currentUser.email.toLowerCase()) {
      final duplicateEmail = await db.query(
        DatabaseTables.users,
        where: 'LOWER(email) = ? AND id != ?',
        whereArgs: [cleanEmail, userId],
        limit: 1,
      );
      if (duplicateEmail.isNotEmpty) {
        throw Exception('An account with this email address already exists.');
      }
    }

    // Check username uniqueness if username changed
    if (cleanUsername != currentUser.username.toLowerCase()) {
      final duplicateUsername = await db.query(
        DatabaseTables.users,
        where: 'LOWER(username) = ? AND id != ?',
        whereArgs: [cleanUsername, userId],
        limit: 1,
      );
      if (duplicateUsername.isNotEmpty) {
        throw Exception('This username is already taken. Please choose another.');
      }
    }

    final now = DateTime.now();
    await db.update(
      DatabaseTables.users,
      {
        'full_name': cleanName,
        'email': cleanEmail,
        'username': cleanUsername,
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );

    return currentUser.copyWith(
      fullName: cleanName,
      email: cleanEmail,
      username: cleanUsername,
      updatedAt: now,
    );
  }

  /// Changes user password with current password verification
  Future<User> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword.isEmpty) {
      throw Exception('Please enter your current password.');
    }
    if (newPassword.length < 6) {
      throw Exception('New password must be at least 6 characters long.');
    }

    final db = await _database;
    final rows = await db.query(
      DatabaseTables.users,
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('User account not found.');
    }

    final user = User.fromMap(rows.first);
    final isCurrentValid = CryptoUtils.verifyPassword(currentPassword, user.salt, user.passwordHash);
    if (!isCurrentValid) {
      throw Exception('Current password is incorrect. Please try again.');
    }

    final newSalt = CryptoUtils.generateSalt();
    final newHash = CryptoUtils.hashPassword(newPassword, newSalt);
    final now = DateTime.now();

    await db.update(
      DatabaseTables.users,
      {
        'password_hash': newHash,
        'salt': newSalt,
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );

    return user.copyWith(
      passwordHash: newHash,
      salt: newSalt,
      updatedAt: now,
    );
  }
}
