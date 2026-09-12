import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class CryptoUtils {
  CryptoUtils._();

  static final Random _secureRandom = Random.secure();

  /// Generates a cryptographically secure random salt encoded in base64
  static String generateSalt([int length = 16]) {
    final values = List<int>.generate(length, (_) => _secureRandom.nextInt(256));
    return base64Url.encode(values);
  }

  /// Hashes a password with a cryptographic salt using multi-round SHA-256
  static String hashPassword(String password, String salt, {int iterations = 1000}) {
    var key = utf8.encode('$password::$salt');
    var digest = sha256.convert(key);

    for (int i = 1; i < iterations; i++) {
      digest = sha256.convert(digest.bytes + key);
    }

    return digest.toString();
  }

  /// Verifies a plain text password against a stored salt and hash
  static bool verifyPassword(String password, String salt, String expectedHash) {
    final calculated = hashPassword(password, salt);
    return calculated == expectedHash;
  }

  /// Generates a 256-bit secure session authentication token
  static String generateSessionToken() {
    final values = List<int>.generate(32, (_) => _secureRandom.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Generates a 6-digit verification code token for password resets
  static String generateResetToken() {
    final code = 100000 + _secureRandom.nextInt(900000);
    return code.toString();
  }

  /// Tokenizes and masks sensitive identifiers (e.g. card/bank numbers)
  /// Returns a map with 'surrogateToken' and 'maskedDisplay'
  static Map<String, String> tokenizeSensitiveReference(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s+'), '');
    final lastFour = cleaned.length >= 4 ? cleaned.substring(cleaned.length - 4) : cleaned;
    final masked = '•••• $lastFour';

    final hash = sha256.convert(utf8.encode(cleaned)).toString().substring(0, 16);
    final surrogate = 'tok_${DateTime.now().millisecondsSinceEpoch}_$hash';

    return {
      'surrogateToken': surrogate,
      'maskedDisplay': masked,
    };
  }

  /// Generates a cryptographically unique surrogate token for financial accounts
  static String generateAccountToken([String? prefix]) {
    final hex = generateSessionToken().substring(0, 16);
    final p = prefix ?? 'tok_acc';
    return '${p}_${DateTime.now().millisecondsSinceEpoch}_$hex';
  }

  /// Validates format of an account token
  static bool isAccountTokenValid(String? token) {
    if (token == null || token.isEmpty) return false;
    return token.startsWith('tok_') && token.length >= 10;
  }
}

