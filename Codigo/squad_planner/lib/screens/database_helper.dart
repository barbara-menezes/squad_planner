import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' as sql;
import 'package:sqflite/sqflite.dart';
import 'package:squad_planner/api/firebase_api.dart';

class DatabaseHelper {
  static Future<sql.Database> db() async {
    return sql.openDatabase(
      'bdfappfirenew.db',
      version: 3,
      onCreate: (sql.Database database, int version) async {
        await createTables(database);
      },
    );
  }

  static Future<void> createTables(sql.Database database) async {
    // Verifique se as tabelas já existem antes de tentar criá-las
    bool itemsTableExists = await database
        .rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='items'")
        .then((result) => result.isNotEmpty);

    bool usersTableExists = await database
        .rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='users'")
        .then((result) => result.isNotEmpty);

    bool userEventsTableExists = await database
        .rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='user_events'")
        .then((result) => result.isNotEmpty);

    bool confirmationsTableExists = await database
        .rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='Confirmations'")
        .then((result) => result.isNotEmpty);

    if (!itemsTableExists ||
        !usersTableExists ||
        !userEventsTableExists ||
        !confirmationsTableExists) {
      await database.transaction((txn) async {
        await txn.execute("""CREATE TABLE items(
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        title TEXT,
        description TEXT,
        endereco TEXT,
        horario TEXT,
        datas TEXT,
        participantes TEXT,
        userId TEXT,
        confirmados INTEGER DEFAULT 0,  -- Corrija o nome da coluna
        createdAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
      """);

        await txn.execute("""CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        user_id TEXT,
        name TEXT,
        email TEXT,
        createdAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
      """);

        await txn.execute("""CREATE TABLE user_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        user_id TEXT,
        event_id INTEGER,
        FOREIGN KEY (event_id) REFERENCES items (id) ON DELETE CASCADE
      )""");

        await txn.execute("""CREATE TABLE Confirmations(
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        eventId INTEGER,
        participantId TEXT,
        FOREIGN KEY (eventId) REFERENCES items (id) ON DELETE CASCADE
      )""");
      });
    }
  }

// id: the id of a item
// title, description: name and description of  activity
// created_at: the time that the item was created. It will be automatically handled by SQLite
  static Future<int> createItem(
    String title,
    String description,
    String endereco,
    String horario,
    String datas,
    String participantes,
    String userId,
    int confirmados,
  ) async {
    final db = await DatabaseHelper.db();

    // Verificar se o evento já foi criado pelo usuário
    final existingEvent = await db.rawQuery('''
    SELECT * FROM items
    WHERE title = ? AND userId = ?
  ''', [title, userId]);

    if (existingEvent.isNotEmpty) {
      // O evento já existe para o usuário
      return -1; // Retornar um valor especial para indicar que o evento não foi criado
    }

    final data = {
      'title': title,
      'description': description,
      'endereco': endereco,
      'horario': horario,
      'datas': datas,
      'participantes': participantes,
      'userId': userId,
      'confirmados': confirmados,
    };

    final id = await db.insert('items', data,
        conflictAlgorithm: sql.ConflictAlgorithm.replace);

    // // Associe o evento ao usuário localmente no SQLite apenas se for o criador
    // await db.insert('user_events', {
    //   'user_id': userId,
    //   'event_id': id,
    // });

    // Notificar participantes
    final participantsList = participantes!.split(',');
    for (String participantEmail in participantsList) {
      if (participantEmail != userId) {
        // Obter o ID do participante com base no e-mail
        final participantId = await getUserIdByEmail(participantEmail);

        if (participantId != null) {
          // Verificar se o evento já foi associado ao participante
          final existingEvent = await db.rawQuery('''
          SELECT * FROM user_events
          WHERE user_id = ? AND event_id = ?
        ''', [participantId, id]);

          // Adicionar o evento associado aos usuários participantes, se não existir
          if (existingEvent.isEmpty) {
            await db.insert('user_events', {
              'user_id': participantId,
              'event_id': id,
            });

            FirebaseApi.sendNotification(
              title!,
              'Novo evento criado: $title',
              userId: participantId,
            );
          }
        }
      }
    }

    return id;
  }

  static Future<String?> getUserIdByEmail(String email) async {
    final db = await DatabaseHelper.db();

    final result = await db.rawQuery('''
    SELECT user_id FROM users
    WHERE email = ?
  ''', [email]);

    if (result.isNotEmpty) {
      return result.first['user_id'] as String;
    } else {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getParticipantEvents(
      String userId) async {
    final db = await DatabaseHelper.db();
    return db.rawQuery('''
    SELECT items.*
    FROM items
    INNER JOIN user_events ON items.id = user_events.event_id
    WHERE user_events.user_id = ?
    ORDER BY items.id
  ''', [userId]);
  }

  static Future<List<Map<String, dynamic>>> getItems(String userId) async {
    final db = await DatabaseHelper.db();
    return db.query('items',
        where: "userId = ?", whereArgs: [userId], orderBy: "id");
  }

  // Get a single item by id
  //We dont use this method, it is for you if you want it.
  static Future<List<Map<String, dynamic>>> getItem(int id) async {
    final db = await DatabaseHelper.db();
    return db.query('items', where: "id = ?", whereArgs: [id], limit: 1);
  }

  static Future<void> createConfirmation(
      int eventId, String participantId) async {
    final db = await DatabaseHelper.db();
    await db.insert(
      'Confirmations',
      {'eventId': eventId, 'participantId': participantId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, dynamic>>> getConfirmations(
      int eventId) async {
    final db = await DatabaseHelper.db();
    return db
        .query('Confirmations', where: 'eventId = ?', whereArgs: [eventId]);
  }

  static Future<void> confirmAttendance(int eventId) async {
    final db = await DatabaseHelper.db();

    await db.rawUpdate('''
    UPDATE items
    SET confirmados = confirmados + 1
    WHERE id = ?
  ''', [eventId]);
  }

  static Future<void> updateConfirmations(
      int eventId, List<String> participants) async {
    final db = await DatabaseHelper.db();

    // Deleta as confirmações existentes para o evento
    await db
        .delete('Confirmations', where: 'eventId = ?', whereArgs: [eventId]);

    // Insere as novas confirmações
    for (var participantId in participants) {
      await db.insert(
        'Confirmations',
        {'eventId': eventId, 'participantId': participantId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Imprime os valores armazenados no banco após a atualização
    final confirmationsAfterUpdate = await db
        .query('Confirmations', where: 'eventId = ?', whereArgs: [eventId]);
    print(
        'Confirmations after update for eventId=$eventId: $confirmationsAfterUpdate');
  }

  // Update an item by id
  static Future<int> updateItem(
    int id,
    String? title,
    String? description,
    String? endereco,
    String? horario,
    String? datas,
    String? participantes,
  ) async {
    final db = await DatabaseHelper.db();

    final data = {
      'title': title,
      'description': description,
      'endereco': endereco,
      'horario': horario,
      'datas': datas,
      'participantes': participantes,
      'createdAt': DateTime.now().toString()
    };

    final result =
        await db.update('items', data, where: "id = ?", whereArgs: [id]);
    return result;
  }

  // Delete
  static Future<void> deleteItem(int id) async {
    final db = await DatabaseHelper.db();
    try {
      await db.delete("items", where: "id = ?", whereArgs: [id]);
    } catch (err) {
      debugPrint("Something went wrong when deleting an item: $err");
    }
  }

  @override
  static Future<void> createUser({
    required String userId,
    required String name,
    required String email,
    // Adicione outros campos conforme necessário
  }) async {
    final db = await DatabaseHelper.db();

    final data = {
      'user_id': userId,
      'name': name,
      'email': email,
      // Adicione outros campos conforme necessário
    };

    await db.insert('users', data,
        conflictAlgorithm: sql.ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await DatabaseHelper.db();
    return db.query('users');
  }
}
