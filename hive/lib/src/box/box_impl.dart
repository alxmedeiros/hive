import 'dart:async';

import 'package:hive/hive.dart';
import 'package:hive/src/backend/storage_backend.dart';
import 'package:hive/src/binary/frame.dart';
import 'package:hive/src/box/box_base.dart';
import 'package:hive/src/hive_impl.dart';

class BoxImpl<E> extends BoxBase<E> {
  BoxImpl(
    HiveImpl hive,
    String name,
    KeyComparator keyComparator,
    CompactionStrategy compactionStrategy,
    StorageBackend backend,
  ) : super(hive, name, keyComparator, compactionStrategy, backend);

  @override
  final bool lazy = false;

  @override
  Iterable<E> get values {
    checkOpen();

    return keystore.getValues();
  }

  @override
  E get(dynamic key, {E defaultValue}) {
    checkOpen();

    var frame = keystore.get(key);
    if (frame != null) {
      return frame.value;
    } else {
      return defaultValue;
    }
  }

  @override
  E getAt(int index) {
    checkOpen();

    return keystore.getAt(index).value;
  }

  @override
  Future<void> putAll(Map<dynamic, E> kvPairs) {
    var frames = <Frame<E>>[];
    for (var key in kvPairs.keys) {
      frames.add(Frame(key, kvPairs[key]));
    }

    return _writeFrames(frames);
  }

  @override
  Future<void> deleteAll(Iterable<dynamic> keys) {
    var frames = <Frame<E>>[];
    for (var key in keys) {
      if (keystore.containsKey(key)) {
        frames.add(Frame.deleted(key));
      }
    }

    return _writeFrames(frames);
  }

  Future<void> _writeFrames(List<Frame<E>> frames) async {
    checkOpen();

    if (!keystore.beginTransaction(frames)) return;

    try {
      await backend.writeFrames(frames);
      keystore.commitTransaction();
    } catch (e) {
      keystore.cancelTransaction();
      rethrow;
    }

    await performCompactionIfNeeded();
  }

  @override
  Map<dynamic, E> toMap() {
    var map = <dynamic, E>{};
    for (var frame in keystore.frames) {
      map[frame.key] = frame.value;
    }
    return map;
  }
}
