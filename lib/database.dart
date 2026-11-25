import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'image_storage.dart';

String _derivePasswordHash(Map<String, String> input) {
  const iterations = 210000;
  final salt = base64Url.decode(input['salt']!);
  final hmac = Hmac(sha256, utf8.encode(input['password']!));
  final block = Uint8List(salt.length + 4)..setRange(0, salt.length, salt);
  block[block.length - 1] = 1;
  var u = Uint8List.fromList(hmac.convert(block).bytes);
  final result = Uint8List.fromList(u);
  for (var i = 1; i < iterations; i++) {
    u = Uint8List.fromList(hmac.convert(u).bytes);
    for (var j = 0; j < result.length; j++) {
      result[j] ^= u[j];
    }
  }
  return base64Url.encode(result);
}

class FindItDatabase {
  FindItDatabase._();
  static final FindItDatabase instance = FindItDatabase._();
  Database? _database;
  Future<Database>? _opening;

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_opening != null) return _opening!;
    final opening = _openDatabase();
    _opening = opening;
    try {
      _database = await opening;
      return _database!;
    } finally {
      _opening = null;
    }
  }

  Future<Database> _openDatabase() async {
    final directory = await getDatabasesPath();
    return openDatabase(
      p.join(directory, 'findit.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            full_name TEXT NOT NULL,
            student_id TEXT NOT NULL,
            email TEXT NOT NULL COLLATE NOCASE UNIQUE,
            password_hash TEXT NOT NULL,
            profile_image_path TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await _createRemainingTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE users ADD COLUMN profile_image_path TEXT',
          );
        }
      },
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _createRemainingTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        item_name TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        image_path TEXT,
        item_type TEXT NOT NULL CHECK(item_type IN ('Lost', 'Found')),
        item_date TEXT NOT NULL,
        location TEXT NOT NULL,
        storage_location TEXT,
        status TEXT NOT NULL DEFAULT 'Active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX items_type_status_idx ON items(item_type, status)',
    );
    await db.execute('CREATE INDEX items_user_idx ON items(user_id)');
    await db.execute('''
      CREATE TABLE conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user1_id INTEGER NOT NULL,
        user2_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(user1_id, user2_id),
        FOREIGN KEY(user1_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY(user2_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_id INTEGER NOT NULL,
        sender_id INTEGER NOT NULL,
        message TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
        FOREIGN KEY(sender_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX messages_conversation_idx ON messages(conversation_id, created_at)',
    );
    await db.execute('''
      CREATE TABLE notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE item_matches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lost_item_id INTEGER NOT NULL,
        found_item_id INTEGER NOT NULL,
        match_score REAL NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(lost_item_id, found_item_id),
        FOREIGN KEY(lost_item_id) REFERENCES items(id) ON DELETE CASCADE,
        FOREIGN KEY(found_item_id) REFERENCES items(id) ON DELETE CASCADE
      )
    ''');
  }

  static String _now() => DateTime.now().toIso8601String();

  static Future<String> _makePasswordRecord(String password) async {
    final random = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
    final encodedSalt = base64Url.encode(salt);
    final hash = await compute(_derivePasswordHash, {
      'password': password,
      'salt': encodedSalt,
    });
    return '$encodedSalt:$hash';
  }

  static Future<bool> _verifyPassword(String password, String record) async {
    final parts = record.split(':');
    if (parts.length != 2) return false;
    final actualHash = await compute(_derivePasswordHash, {
      'password': password,
      'salt': parts[0],
    });
    final actual = utf8.encode(actualHash);
    final expected = utf8.encode(parts[1]);
    if (actual.length != expected.length) return false;
    var difference = 0;
    for (var i = 0; i < actual.length; i++) {
      difference |= actual[i] ^ expected[i];
    }
    return difference == 0;
  }

  Future<int> register({
    required String fullName,
    required String studentId,
    required String email,
    required String password,
  }) async {
    final db = await database;
    return db.insert('users', {
      'full_name': fullName.trim(),
      'student_id': studentId.trim(),
      'email': email.trim().toLowerCase(),
      'password_hash': await _makePasswordRecord(password),
      'created_at': _now(),
    });
  }

  Future<Map<String, Object?>?> login(String email, String password) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty ||
        !await _verifyPassword(
          password,
          rows.first['password_hash'] as String,
        )) {
      return null;
    }
    return rows.first;
  }

  Future<Map<String, Object?>?> userById(int id) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> updateProfile(int id, Map<String, Object?> values) async {
    final db = await database;
    await db.update('users', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> changePassword(
    int id,
    String currentPassword,
    String newPassword,
  ) async {
    final db = await database;
    final user = await userById(id);
    if (user == null ||
        !await _verifyPassword(
          currentPassword,
          user['password_hash'] as String,
        )) {
      return false;
    }
    await db.update(
      'users',
      {'password_hash': await _makePasswordRecord(newPassword)},
      where: 'id = ?',
      whereArgs: [id],
    );
    return true;
  }

  Future<int> saveItem(Map<String, Object?> values, {int? id}) async {
    final db = await database;
    final now = _now();
    return db.transaction((txn) async {
      if (id == null) {
        final newId = await txn.insert('items', {
          ...values,
          'created_at': now,
          'updated_at': now,
        });
        await _findMatches(txn, newId);
        return newId;
      }
      final changed = await txn.update(
        'items',
        {...values, 'updated_at': now},
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, values['user_id']],
      );
      if (changed == 0) {
        throw StateError('This report no longer exists or you do not own it.');
      }
      await txn.delete(
        'item_matches',
        where: 'lost_item_id = ? OR found_item_id = ?',
        whereArgs: [id, id],
      );
      await _findMatches(txn, id);
      return id;
    });
  }

  Future<void> deleteItem(int id, int ownerId) async {
    final db = await database;
    await db.delete(
      'items',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, ownerId],
    );
  }

  Future<void> updateItemStatus(int id, int ownerId, String status) async {
    final db = await database;
    await db.transaction((txn) async {
      final changed = await txn.update(
        'items',
        {'status': status, 'updated_at': _now()},
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, ownerId],
      );
      if (changed > 0) {
        final rows = await txn.query('items', where: 'id = ?', whereArgs: [id]);
        if (rows.isNotEmpty) {
          final item = rows.first;
          await _notify(
            txn,
            item['user_id'] as int,
            status == 'Returned' ? 'Item returned' : 'Item status updated',
            '"${item['item_name']}" is now marked $status.',
          );
          final matches = await txn.rawQuery(
            '''
            SELECT CASE WHEN lost_item_id = ? THEN found_item_id ELSE lost_item_id END AS item_id
            FROM item_matches WHERE lost_item_id = ? OR found_item_id = ?
            ''',
            [id, id, id],
          );
          final notifiedUsers = <int>{item['user_id'] as int};
          for (final match in matches) {
            final counterpart = await txn.query(
              'items',
              columns: ['user_id'],
              where: 'id = ?',
              whereArgs: [match['item_id']],
            );
            if (counterpart.isEmpty) continue;
            final userId = counterpart.first['user_id'] as int;
            if (notifiedUsers.add(userId)) {
              await _notify(
                txn,
                userId,
                status == 'Returned'
                    ? 'Possible match returned'
                    : 'Matched item updated',
                'A possible match for "${item['item_name']}" is now marked $status.',
              );
            }
          }
        }
      }
    });
  }

  Future<List<Map<String, Object?>>> searchItems({
    String query = '',
    String category = 'All',
    String type = 'All',
    DateTime? date,
    String location = '',
    int? excludeUserId,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (query.trim().isNotEmpty) {
      where.add('(i.item_name LIKE ? OR i.description LIKE ?)');
      args.addAll(['%${query.trim()}%', '%${query.trim()}%']);
    }
    if (category != 'All') {
      where.add('i.category = ?');
      args.add(category);
    }
    if (type != 'All') {
      where.add('i.item_type = ?');
      args.add(type);
    }
    if (date != null) {
      where.add('date(i.item_date) = date(?)');
      args.add(date.toIso8601String());
    }
    if (location.trim().isNotEmpty) {
      where.add('i.location LIKE ?');
      args.add('%${location.trim()}%');
    }
    if (excludeUserId != null) {
      where.add('i.user_id != ?');
      args.add(excludeUserId);
    }
    final result = await db.rawQuery('''
      SELECT i.*, u.full_name AS reporter_name,
        EXISTS(
          SELECT 1 FROM item_matches m
          WHERE m.lost_item_id = i.id OR m.found_item_id = i.id
        ) AS has_match
      FROM items i JOIN users u ON u.id = i.user_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY i.created_at DESC
    ''', args);
    return result;
  }

  Future<List<Map<String, Object?>>> myItems(int userId) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT i.*, u.full_name AS reporter_name,
        EXISTS(
          SELECT 1 FROM item_matches m
          WHERE m.lost_item_id = i.id OR m.found_item_id = i.id
        ) AS has_match
      FROM items i JOIN users u ON u.id = i.user_id
      WHERE i.user_id = ? ORDER BY i.created_at DESC
    ''',
      [userId],
    );
  }

  Future<List<int>> itemCounts() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        SUM(CASE WHEN item_type = 'Lost' AND status != 'Returned' THEN 1 ELSE 0 END) AS lost,
        SUM(CASE WHEN item_type = 'Found' AND status != 'Returned' THEN 1 ELSE 0 END) AS found,
        SUM(CASE WHEN status = 'Returned' THEN 1 ELSE 0 END) AS returned
      FROM items
    ''');
    final row = rows.first;
    return [
      row['lost'] as int? ?? 0,
      row['found'] as int? ?? 0,
      row['returned'] as int? ?? 0,
    ];
  }

  Future<List<Map<String, Object?>>> matchesForItem(int itemId) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT m.match_score, i.*, u.full_name AS reporter_name
      FROM item_matches m
      JOIN items i ON i.id = CASE WHEN m.lost_item_id = ? THEN m.found_item_id ELSE m.lost_item_id END
      JOIN users u ON u.id = i.user_id
      WHERE m.lost_item_id = ? OR m.found_item_id = ?
      ORDER BY m.match_score DESC
    ''',
      [itemId, itemId, itemId],
    );
  }

  Future<void> _findMatches(DatabaseExecutor db, int itemId) async {
    final rows = await db.rawQuery(
      '''
      SELECT i.*, u.full_name AS reporter_name FROM items i
      JOIN users u ON u.id = i.user_id WHERE i.id = ?
    ''',
      [itemId],
    );
    if (rows.isEmpty) return;
    final item = rows.first;
    final oppositeType = item['item_type'] == 'Lost' ? 'Found' : 'Lost';
    final candidates = await db.rawQuery(
      '''
      SELECT i.*, u.full_name AS reporter_name FROM items i
      JOIN users u ON u.id = i.user_id
      WHERE i.item_type = ? AND i.status != 'Returned' AND i.id != ?
    ''',
      [oppositeType, itemId],
    );
    for (final candidate in candidates) {
      final score = _matchScore(item, candidate);
      if (score < 0.30) continue;
      final lostId = item['item_type'] == 'Lost'
          ? itemId
          : candidate['id'] as int;
      final foundId = item['item_type'] == 'Found'
          ? itemId
          : candidate['id'] as int;
      final existing = await db.query(
        'item_matches',
        where: 'lost_item_id = ? AND found_item_id = ?',
        whereArgs: [lostId, foundId],
      );
      if (existing.isNotEmpty) continue;
      await db.insert('item_matches', {
        'lost_item_id': lostId,
        'found_item_id': foundId,
        'match_score': score,
        'created_at': _now(),
      });
      await _notify(
        db,
        item['user_id'] as int,
        'Possible item match',
        'A ${oppositeType.toLowerCase()} report may match "${item['item_name']}".',
      );
      await _notify(
        db,
        candidate['user_id'] as int,
        'Possible item match',
        'A ${item['item_type'].toString().toLowerCase()} report may match "${candidate['item_name']}".',
      );
    }
  }

  double _matchScore(Map<String, Object?> a, Map<String, Object?> b) {
    var score = 0.0;
    final nameA = (a['item_name'] as String).toLowerCase();
    final nameB = (b['item_name'] as String).toLowerCase();
    if (nameA == nameB) {
      score += 0.45;
    } else {
      final tokensA = nameA
          .split(RegExp(r'\W+'))
          .where((e) => e.length > 2)
          .toSet();
      final tokensB = nameB
          .split(RegExp(r'\W+'))
          .where((e) => e.length > 2)
          .toSet();
      if (tokensA.intersection(tokensB).isNotEmpty) score += 0.25;
    }
    if (a['category'] == b['category']) score += 0.2;
    if ((a['location'] as String).toLowerCase() ==
        (b['location'] as String).toLowerCase()) {
      score += 0.2;
    }
    final descriptionA = (a['description'] as String).toLowerCase();
    final descriptionB = (b['description'] as String).toLowerCase();
    final wordsA = descriptionA
        .split(RegExp(r'\W+'))
        .where((e) => e.length > 3)
        .toSet();
    final wordsB = descriptionB
        .split(RegExp(r'\W+'))
        .where((e) => e.length > 3)
        .toSet();
    if (wordsA.intersection(wordsB).isNotEmpty) score += 0.1;
    final dateA = DateTime.tryParse(a['item_date'] as String);
    final dateB = DateTime.tryParse(b['item_date'] as String);
    if (dateA != null &&
        dateB != null &&
        dateA.difference(dateB).inDays.abs() <= 7) {
      score += 0.05;
    }
    return score.clamp(0, 1).toDouble();
  }

  Future<void> _notify(
    DatabaseExecutor db,
    int userId,
    String title,
    String message,
  ) async {
    await db.insert('notifications', {
      'user_id': userId,
      'title': title,
      'message': message,
      'is_read': 0,
      'created_at': _now(),
    });
  }

  Future<List<Map<String, Object?>>> notifications(int userId) async {
    final db = await database;
    return db.query(
      'notifications',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> markNotificationsRead(int userId) async {
    final db = await database;
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<int> unreadNotificationCount(int userId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM notifications WHERE user_id = ? AND is_read = 0',
      [userId],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> conversation(int currentUserId, int otherUserId) async {
    final db = await database;
    final first = min(currentUserId, otherUserId);
    final second = max(currentUserId, otherUserId);
    final rows = await db.query(
      'conversations',
      where: 'user1_id = ? AND user2_id = ?',
      whereArgs: [first, second],
    );
    if (rows.isNotEmpty) return rows.first['id'] as int;
    return db.insert('conversations', {
      'user1_id': first,
      'user2_id': second,
      'created_at': _now(),
    });
  }

  Future<void> sendMessage(
    int conversationId,
    int senderId,
    int recipientId,
    String text,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('messages', {
        'conversation_id': conversationId,
        'sender_id': senderId,
        'message': text.trim(),
        'created_at': _now(),
      });
      await _notify(
        txn,
        recipientId,
        'New message',
        'You received a new message.',
      );
    });
  }

  Future<List<Map<String, Object?>>> messages(int conversationId) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT m.*, u.full_name AS sender_name FROM messages m
      JOIN users u ON u.id = m.sender_id
      WHERE m.conversation_id = ? ORDER BY m.created_at
    ''',
      [conversationId],
    );
  }

  Future<List<Map<String, Object?>>> conversationsFor(int userId) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT c.id AS conversation_id, u.id AS other_user_id, u.full_name, u.profile_image_path,
        (SELECT message FROM messages m WHERE m.conversation_id = c.id ORDER BY created_at DESC LIMIT 1) AS last_message,
        (SELECT created_at FROM messages m WHERE m.conversation_id = c.id ORDER BY created_at DESC LIMIT 1) AS last_message_at
      FROM conversations c
      JOIN users u ON u.id = CASE WHEN c.user1_id = ? THEN c.user2_id ELSE c.user1_id END
      WHERE c.user1_id = ? OR c.user2_id = ?
      ORDER BY COALESCE(last_message_at, c.created_at) DESC
    ''',
      [userId, userId, userId],
    );
  }

  Future<String> saveImage(XFile image) {
    return persistImage(image);
  }
}
