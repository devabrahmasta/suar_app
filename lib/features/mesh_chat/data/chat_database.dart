import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../domain/message_model.dart';

class ChatDatabase {
  ChatDatabase._init();
  static final ChatDatabase instance = ChatDatabase._init();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('suar_chat.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE messages (
      id TEXT PRIMARY KEY,
      senderId TEXT NOT NULL,
      senderName TEXT NOT NULL,
      content TEXT NOT NULL,
      timestamp INTEGER NOT NULL,
      type TEXT NOT NULL,
      peerId TEXT,
      hopCount INTEGER NOT NULL
    )
    ''');
  }

  Future<void> insertMessage(MessageModel message) async {
    print('💾 [DB] Simpan pesan id: ${message.id}, type: ${message.type}');
    final db = await instance.database;
    await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MessageModel>> getPublicMessages() async {
    final db = await instance.database;
    final maps = await db.query(
      'messages',
      where: 'type = ?',
      whereArgs: [MessageType.public.name],
      orderBy: 'timestamp ASC',
    );

    return maps.map((map) => MessageModel.fromMap(map)).toList();
  }

  Future<List<MessageModel>> getDmMessages(String myDeviceId, String peerId) async {
    final db = await instance.database;
    // get messages where (type is dm) AND (peerId is peerId OR senderId is peerId)
    // to capture both incoming and outgoing DM with that peer
    final maps = await db.query(
      'messages',
      where: 'type = ? AND ((senderId = ? AND peerId = ?) OR (senderId = ? AND peerId = ?))',
      whereArgs: [MessageType.dm.name, myDeviceId, peerId, peerId, myDeviceId],
      orderBy: 'timestamp ASC',
    );
    print('🔍 [DB] Query DM: myDeviceId=$myDeviceId, peerId=$peerId, hasil: ${maps.length} pesan');

    return maps.map((map) => MessageModel.fromMap(map)).toList();
  }

  Future<int> deleteOldMessages() async {
    final db = await instance.database;
    final cutoff = DateTime.now()
        .subtract(const Duration(hours: 24))
        .millisecondsSinceEpoch;
    return await db.delete(
      'messages',
      where: 'timestamp < ?',
      whereArgs: [cutoff],
    );
  }

  Future<bool> messageExists(String id) async {
    final db = await instance.database;
    final result = await db.query(
      'messages',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty;
  }
}
