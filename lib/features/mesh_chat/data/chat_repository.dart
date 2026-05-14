import '../domain/message_model.dart';
import 'chat_database.dart';

class ChatRepository {
  final ChatDatabase _database;

  ChatRepository({ChatDatabase? database})
    : _database = database ?? ChatDatabase.instance;

  Future<void> saveMessage(MessageModel message) async {
    await _database.insertMessage(message);
  }

  Future<List<MessageModel>> getPublicMessages() async {
    return await _database.getPublicMessages();
  }

  Future<List<MessageModel>> getDmMessages(String peerId) async {
    return await _database.getDmMessages(peerId);
  }

  Future<int> clearOldMessages() async {
    return await _database.deleteOldMessages();
  }

  Future<bool> hasMessage(String id) async {
    return await _database.messageExists(id);
  }
}
