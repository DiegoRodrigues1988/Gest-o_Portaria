import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Models
class Porteiro {
  final int? id;
  final String nome;
  final String senha;
  final String periodo;

  Porteiro(
      {this.id,
      required this.nome,
      required this.senha,
      required this.periodo});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'senha': senha,
      'periodo': periodo,
    };
  }

  factory Porteiro.fromMap(Map<String, dynamic> map) {
    return Porteiro(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      senha: map['senha'] as String,
      periodo: map['periodo'] as String,
    );
  }
}

class Morador {
  final int? id;
  final String nome;
  final String apartamento;
  final String whatsapp;

  Morador(
      {this.id,
      required this.nome,
      required this.apartamento,
      required this.whatsapp});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'apartamento': apartamento,
      'whatsapp': whatsapp,
    };
  }

  factory Morador.fromMap(Map<String, dynamic> map) {
    return Morador(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      apartamento: map['apartamento'] as String,
      whatsapp: map['whatsapp'] as String,
    );
  }
}

class Encomenda {
  final int? id;
  final String descricao;
  final int idMorador;
  final String dataEntrada;
  final String? dataSaida;
  final String status;
  final String? fotoPath;
  final String? retiradoPor;

  Encomenda({
    this.id,
    required this.descricao,
    required this.idMorador,
    required this.dataEntrada,
    this.dataSaida,
    required this.status,
    this.fotoPath,
    this.retiradoPor,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'descricao': descricao,
      'id_morador': idMorador,
      'data_entrada': dataEntrada,
      'data_saida': dataSaida,
      'status': status,
      'foto_path': fotoPath,
      'retirado_por': retiradoPor,
    };
  }

  factory Encomenda.fromMap(Map<String, dynamic> map) {
    return Encomenda(
      id: map['id'] as int?,
      descricao: map['descricao'] as String,
      idMorador: map['id_morador'] as int,
      dataEntrada: map['data_entrada'] as String,
      dataSaida: map['data_saida'] as String?,
      status: map['status'] as String,
      fotoPath: map['foto_path'] as String?,
      retiradoPor: map['retirado_por'] as String?,
    );
  }
}

/// Database helper: singleton responsible for opening and querying the database.
class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;
  static bool _ffiInitialized = false;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _initFfiForDesktop();

    _database = await _initDatabase();
    return _database!;
  }

  void _initFfiForDesktop() {
    if (Platform.isWindows && !_ffiInitialized) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _ffiInitialized = true;
    }
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'gestao_portaria.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE porteiro (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nome TEXT NOT NULL UNIQUE,
            senha TEXT NOT NULL,
            periodo TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE morador (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nome TEXT NOT NULL,
            apartamento TEXT NOT NULL,
            whatsapp TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE encomenda (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            descricao TEXT NOT NULL,
            id_morador INTEGER NOT NULL,
            data_entrada TEXT NOT NULL,
            data_saida TEXT,
            status TEXT NOT NULL,
            foto_path TEXT,
            retirado_por TEXT,
            FOREIGN KEY (id_morador) REFERENCES morador (id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE encomenda ADD COLUMN foto_path TEXT');
          await db
              .execute('ALTER TABLE encomenda ADD COLUMN retirado_por TEXT');
        }
      },
    );
  }

  /// Porteiro CRUD
  Future<int> insertPorteiro(Porteiro porteiro) async {
    final db = await database;
    return await db.insert('porteiro', porteiro.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Porteiro?> getPorteiroByNameAndSenha(String nome, String senha) async {
    final db = await database;
    final maps = await db.query(
      'porteiro',
      where: 'nome = ? AND senha = ?',
      whereArgs: [nome.trim(), senha],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Porteiro.fromMap(maps.first);
  }

  Future<bool> hasAnyPorteiro() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM porteiro');
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }

  Future<List<Porteiro>> getAllPorteiros() async {
    final db = await database;
    final result = await db.query('porteiro', orderBy: 'nome ASC');
    return result.map((map) => Porteiro.fromMap(map)).toList();
  }

  Future<int> deletePorteiro(int id) async {
    final db = await database;
    return await db.delete('porteiro', where: 'id = ?', whereArgs: [id]);
  }

  /// Morador CRUD
  Future<int> insertMorador(Morador morador) async {
    final db = await database;
    return await db.insert('morador', morador.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Morador>> getAllMoradores() async {
    final db = await database;
    final result = await db.query('morador', orderBy: 'nome ASC');
    return result.map((map) => Morador.fromMap(map)).toList();
  }

  Future<Morador?> getMoradorById(int id) async {
    final db = await database;
    final maps =
        await db.query('morador', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Morador.fromMap(maps.first);
  }

  Future<int> deleteMorador(int id) async {
    final db = await database;
    return await db.delete('morador', where: 'id = ?', whereArgs: [id]);
  }

  /// Encomenda CRUD
  Future<int> insertEncomenda(Encomenda encomenda) async {
    final db = await database;
    return await db.insert('encomenda', encomenda.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Encomenda>> getAllEncomendas() async {
    final db = await database;
    final result = await db.query('encomenda', orderBy: 'data_entrada DESC');
    return result.map((map) => Encomenda.fromMap(map)).toList();
  }

  Future<List<Encomenda>> getEncomendasPendentes() async {
    final db = await database;
    final result = await db.query(
      'encomenda',
      where: 'status = ?',
      whereArgs: ['pendente'],
      orderBy: 'data_entrada DESC',
    );
    return result.map((map) => Encomenda.fromMap(map)).toList();
  }

  /// Retorna encomendas com dados do morador (join), útil para relatórios.
  Future<List<Map<String, dynamic>>> getEncomendasWithMorador() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        e.id,
        e.descricao,
        e.data_entrada,
        e.data_saida,
        e.status,
        e.foto_path,
        e.retirado_por,
        m.id as morador_id,
        m.nome as morador_nome,
        m.apartamento as morador_apartamento,
        m.whatsapp as morador_whatsapp
      FROM encomenda e
      LEFT JOIN morador m ON e.id_morador = m.id
      ORDER BY e.data_entrada DESC
    ''');
    return result;
  }

  Future<int> updateEncomenda(Encomenda encomenda) async {
    final db = await database;
    return await db.update(
      'encomenda',
      encomenda.toMap(),
      where: 'id = ?',
      whereArgs: [encomenda.id],
    );
  }

  Future<int> markEncomendaAsEntregue(int id, String dataSaida,
      {String? retiradoPor}) async {
    final db = await database;
    final updateData = {
      'status': 'entregue',
      'data_saida': dataSaida,
    };

    if (retiradoPor != null) {
      updateData['retirado_por'] = retiradoPor;
    }

    return await db.update(
      'encomenda',
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteEncomenda(int id) async {
    final db = await database;
    return await db.delete('encomenda', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> clearEncomendas() async {
    final db = await database;
    return await db.delete('encomenda');
  }
}
