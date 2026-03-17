// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_db.dart';

// ignore_for_file: type=lint
class $DevicePositionsTable extends DevicePositions
    with TableInfo<$DevicePositionsTable, DevicePosition> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DevicePositionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceNameMeta = const VerificationMeta(
    'deviceName',
  );
  @override
  late final GeneratedColumn<String> deviceName = GeneratedColumn<String>(
    'device_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIndexMeta = const VerificationMeta(
    'chapterIndex',
  );
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
    'chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionSecondsMeta = const VerificationMeta(
    'positionSeconds',
  );
  @override
  late final GeneratedColumn<double> positionSeconds = GeneratedColumn<double>(
    'position_seconds',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookId,
    deviceName,
    chapterIndex,
    positionSeconds,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'device_positions';
  @override
  VerificationContext validateIntegrity(
    Insertable<DevicePosition> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('device_name')) {
      context.handle(
        _deviceNameMeta,
        deviceName.isAcceptableOrUnknown(data['device_name']!, _deviceNameMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceNameMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
        _chapterIndexMeta,
        chapterIndex.isAcceptableOrUnknown(
          data['chapter_index']!,
          _chapterIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('position_seconds')) {
      context.handle(
        _positionSecondsMeta,
        positionSeconds.isAcceptableOrUnknown(
          data['position_seconds']!,
          _positionSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_positionSecondsMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId, deviceName};
  @override
  DevicePosition map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DevicePosition(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      deviceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_name'],
      )!,
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      )!,
      positionSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}position_seconds'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DevicePositionsTable createAlias(String alias) {
    return $DevicePositionsTable(attachedDatabase, alias);
  }
}

class DevicePosition extends DataClass implements Insertable<DevicePosition> {
  final String bookId;
  final String deviceName;
  final int chapterIndex;
  final double positionSeconds;
  final String updatedAt;
  const DevicePosition({
    required this.bookId,
    required this.deviceName,
    required this.chapterIndex,
    required this.positionSeconds,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['device_name'] = Variable<String>(deviceName);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['position_seconds'] = Variable<double>(positionSeconds);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  DevicePositionsCompanion toCompanion(bool nullToAbsent) {
    return DevicePositionsCompanion(
      bookId: Value(bookId),
      deviceName: Value(deviceName),
      chapterIndex: Value(chapterIndex),
      positionSeconds: Value(positionSeconds),
      updatedAt: Value(updatedAt),
    );
  }

  factory DevicePosition.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DevicePosition(
      bookId: serializer.fromJson<String>(json['bookId']),
      deviceName: serializer.fromJson<String>(json['deviceName']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      positionSeconds: serializer.fromJson<double>(json['positionSeconds']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'deviceName': serializer.toJson<String>(deviceName),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'positionSeconds': serializer.toJson<double>(positionSeconds),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  DevicePosition copyWith({
    String? bookId,
    String? deviceName,
    int? chapterIndex,
    double? positionSeconds,
    String? updatedAt,
  }) => DevicePosition(
    bookId: bookId ?? this.bookId,
    deviceName: deviceName ?? this.deviceName,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    positionSeconds: positionSeconds ?? this.positionSeconds,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DevicePosition copyWithCompanion(DevicePositionsCompanion data) {
    return DevicePosition(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      deviceName: data.deviceName.present
          ? data.deviceName.value
          : this.deviceName,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      positionSeconds: data.positionSeconds.present
          ? data.positionSeconds.value
          : this.positionSeconds,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DevicePosition(')
          ..write('bookId: $bookId, ')
          ..write('deviceName: $deviceName, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(bookId, deviceName, chapterIndex, positionSeconds, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DevicePosition &&
          other.bookId == this.bookId &&
          other.deviceName == this.deviceName &&
          other.chapterIndex == this.chapterIndex &&
          other.positionSeconds == this.positionSeconds &&
          other.updatedAt == this.updatedAt);
}

class DevicePositionsCompanion extends UpdateCompanion<DevicePosition> {
  final Value<String> bookId;
  final Value<String> deviceName;
  final Value<int> chapterIndex;
  final Value<double> positionSeconds;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const DevicePositionsCompanion({
    this.bookId = const Value.absent(),
    this.deviceName = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.positionSeconds = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DevicePositionsCompanion.insert({
    required String bookId,
    required String deviceName,
    required int chapterIndex,
    required double positionSeconds,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       deviceName = Value(deviceName),
       chapterIndex = Value(chapterIndex),
       positionSeconds = Value(positionSeconds),
       updatedAt = Value(updatedAt);
  static Insertable<DevicePosition> custom({
    Expression<String>? bookId,
    Expression<String>? deviceName,
    Expression<int>? chapterIndex,
    Expression<double>? positionSeconds,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (deviceName != null) 'device_name': deviceName,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (positionSeconds != null) 'position_seconds': positionSeconds,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DevicePositionsCompanion copyWith({
    Value<String>? bookId,
    Value<String>? deviceName,
    Value<int>? chapterIndex,
    Value<double>? positionSeconds,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return DevicePositionsCompanion(
      bookId: bookId ?? this.bookId,
      deviceName: deviceName ?? this.deviceName,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (deviceName.present) {
      map['device_name'] = Variable<String>(deviceName.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (positionSeconds.present) {
      map['position_seconds'] = Variable<double>(positionSeconds.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DevicePositionsCompanion(')
          ..write('bookId: $bookId, ')
          ..write('deviceName: $deviceName, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DevicePositionsTable devicePositions = $DevicePositionsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [devicePositions];
}

typedef $$DevicePositionsTableCreateCompanionBuilder =
    DevicePositionsCompanion Function({
      required String bookId,
      required String deviceName,
      required int chapterIndex,
      required double positionSeconds,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$DevicePositionsTableUpdateCompanionBuilder =
    DevicePositionsCompanion Function({
      Value<String> bookId,
      Value<String> deviceName,
      Value<int> chapterIndex,
      Value<double> positionSeconds,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$DevicePositionsTableFilterComposer
    extends Composer<_$AppDatabase, $DevicePositionsTable> {
  $$DevicePositionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get positionSeconds => $composableBuilder(
    column: $table.positionSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DevicePositionsTableOrderingComposer
    extends Composer<_$AppDatabase, $DevicePositionsTable> {
  $$DevicePositionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get positionSeconds => $composableBuilder(
    column: $table.positionSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DevicePositionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DevicePositionsTable> {
  $$DevicePositionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<double> get positionSeconds => $composableBuilder(
    column: $table.positionSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DevicePositionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DevicePositionsTable,
          DevicePosition,
          $$DevicePositionsTableFilterComposer,
          $$DevicePositionsTableOrderingComposer,
          $$DevicePositionsTableAnnotationComposer,
          $$DevicePositionsTableCreateCompanionBuilder,
          $$DevicePositionsTableUpdateCompanionBuilder,
          (
            DevicePosition,
            BaseReferences<
              _$AppDatabase,
              $DevicePositionsTable,
              DevicePosition
            >,
          ),
          DevicePosition,
          PrefetchHooks Function()
        > {
  $$DevicePositionsTableTableManager(
    _$AppDatabase db,
    $DevicePositionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DevicePositionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DevicePositionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DevicePositionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> deviceName = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<double> positionSeconds = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DevicePositionsCompanion(
                bookId: bookId,
                deviceName: deviceName,
                chapterIndex: chapterIndex,
                positionSeconds: positionSeconds,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required String deviceName,
                required int chapterIndex,
                required double positionSeconds,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DevicePositionsCompanion.insert(
                bookId: bookId,
                deviceName: deviceName,
                chapterIndex: chapterIndex,
                positionSeconds: positionSeconds,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DevicePositionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DevicePositionsTable,
      DevicePosition,
      $$DevicePositionsTableFilterComposer,
      $$DevicePositionsTableOrderingComposer,
      $$DevicePositionsTableAnnotationComposer,
      $$DevicePositionsTableCreateCompanionBuilder,
      $$DevicePositionsTableUpdateCompanionBuilder,
      (
        DevicePosition,
        BaseReferences<_$AppDatabase, $DevicePositionsTable, DevicePosition>,
      ),
      DevicePosition,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DevicePositionsTableTableManager get devicePositions =>
      $$DevicePositionsTableTableManager(_db, _db.devicePositions);
}
