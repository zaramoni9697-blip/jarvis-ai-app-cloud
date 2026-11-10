import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';

class DatabaseService {
  static Database? _db;
  static const String _dbName = 'jarvis_local.db';
  static const int _version = 1;

  static Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    
    return await openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        remember_session INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        last_login TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE api_keys (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        provider TEXT NOT NULL,
        encrypted_key TEXT NOT NULL,
        model TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (profile_id) REFERENCES profiles (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        session_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (profile_id) REFERENCES profiles (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE memories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        key_name TEXT NOT NULL,
        value TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (profile_id) REFERENCES profiles (id)
      )
    ''');
  }

  // ── Password hashing (SHA-256 + salt) ──
  static String generateSalt() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final bytes = utf8.encode(timestamp + 'jarvis_salt_v1');
    return sha256.convert(bytes).toString().substring(0, 32);
  }

  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt + 'jarvis_pepper_9002');
    return sha256.convert(bytes).toString();
  }

  // ── Profile CRUD ──
  static Future<int> createProfile({
    required String fullName,
    required String email,
    required String password,
    bool rememberSession = false,
  }) async {
    final db = await database;
    final salt = generateSalt();
    final hash = hashPassword(password, salt);
    
    return await db.insert('profiles', {
      'full_name': fullName,
      'email': email.toLowerCase().trim(),
      'password_hash': hash,
      'salt': salt,
      'remember_session': rememberSession ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<Map<String, dynamic>?> authenticateProfile({
    required String email,
    required String password,
  }) async {
    final db = await database;
    final results = await db.query(
      'profiles',
      where: 'email = ?',
      whereArgs: [email.toLowerCase().trim()],
    );
    
    if (results.isEmpty) return null;
    
    final profile = results.first;
    final hash = hashPassword(password, profile['salt'] as String);
    
    if (hash != profile['password_hash']) return null;
    
    // Update last login
    await db.update(
      'profiles',
      {'last_login': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [profile['id']],
    );
    
    return profile;
  }

  static Future<bool> emailExists(String email) async {
    final db = await database;
    final results = await db.query(
      'profiles',
      where: 'email = ?',
      whereArgs: [email.toLowerCase().trim()],
    );
    return results.isNotEmpty;
  }

  // ── API Key storage ──
  static Future<void> saveApiKey({
    required int profileId,
    required String provider,
    required String apiKey,
    String? model,
  }) async {
    final db = await database;
    
    // Delete old key for same provider
    await db.delete(
      'api_keys',
      where: 'profile_id = ? AND provider = ?',
      whereArgs: [profileId, provider],
    );
    
    // Simple base64 encoding (in production use flutter_secure_storage)
    final encodedKey = base64Encode(utf8.encode(apiKey));
    
    await db.insert('api_keys', {
      'profile_id': profileId,
      'provider': provider,
      'encrypted_key': encodedKey,
      'model': model,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<String?> getApiKey(int profileId, String provider) async {
    final db = await database;
    final results = await db.query(
      'api_keys',
      where: 'profile_id = ? AND provider = ?',
      whereArgs: [profileId, provider],
    );
    
    if (results.isEmpty) return null;
    
    final encoded = results.first['encrypted_key'] as String;
    return utf8.decode(base64Decode(encoded));
  }

  // ── Chat history ──
  static Future<void> saveChatMessage({
    required int profileId,
    required String sessionId,
    required String role,
    required String content,
  }) async {
    final db = await database;
    await db.insert('chat_history', {
      'profile_id': profileId,
      'session_id': sessionId,
      'role': role,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getChatHistory(
    int profileId,
    String sessionId,
  ) async {
    final db = await database;
    return await db.query(
      'chat_history',
      where: 'profile_id = ? AND session_id = ?',
      whereArgs: [profileId, sessionId],
      orderBy: 'timestamp ASC',
    );
  }

  static Future<List<Map<String, dynamic>>> getRecentSessions(
    int profileId,
  ) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT session_id, 
             MIN(timestamp) as started_at,
             COUNT(*) as message_count,
             (SELECT content FROM chat_history ch2 
              WHERE ch2.session_id = ch.session_id 
              AND ch2.role = 'user'
              ORDER BY ch2.timestamp ASC LIMIT 1) as first_message
      FROM chat_history ch
      WHERE profile_id = ?
      GROUP BY session_id
      ORDER BY started_at DESC
      LIMIT 20
    ''', [profileId]);
  }
}
