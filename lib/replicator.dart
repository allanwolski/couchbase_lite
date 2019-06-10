import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';

import 'replicator_configuration.dart';
import 'listener_token.dart';

typedef ListenerCallback = Function(ReplicatorChange);

enum ReplicatorActivityLevel { busy, idle, offline, stopped, connecting }

class Replicator {
  static const JSONMethodCodec _jsonMethod = const JSONMethodCodec();
  static const MethodChannel _channel = const MethodChannel(
      'com.saltechsystems.couchbase_lite/json', _jsonMethod);
  static const EventChannel _replicationEventChannel = const EventChannel(
      "com.saltechsystems.couchbase_lite/replicationEventChannel");
  final Stream _replicationStream =
      _replicationEventChannel.receiveBroadcastStream();

  final replicatorId = Uuid().v1();
  Map<ListenerToken, StreamSubscription> tokens = {};

  final ReplicatorConfiguration config;

  Replicator(this.config);

  Future<void> start() async {
    await _channel.invokeMethod('startReplicator', this);
  }

  Future<void> stop() async {
    await _channel.invokeMethod('stopReplicator', this);
  }

  ListenerToken addChangeListener(ListenerCallback callback) {
    var token = ListenerToken();
    tokens[token] = _replicationStream
        .where((data) => data["replicator"] == replicatorId)
        .listen((data) {
      var activity = activityFromString(data["activity"]);
      String error = null;
      if (data["error"] is String) {
        error = data["error"];
      }

      callback(
          ReplicatorChange(this, ReplicatorStatus._internal(activity, error)));
    });
    return token;
  }

  Future<ListenerToken> removeChangeListener(ListenerToken token) async {
    var subscription = tokens.remove(token);

    if (subscription != null) {
      subscription.cancel();
    }

    return token;
  }

  ReplicatorActivityLevel activityFromString(String _status) {
    switch (_status) {
      case "BUSY":
        return ReplicatorActivityLevel.busy;
        break;
      case "IDLE":
        return ReplicatorActivityLevel.idle;
        break;
      case "OFFLINE":
        return ReplicatorActivityLevel.offline;
        break;
      case "STOPPED":
        return ReplicatorActivityLevel.stopped;
        break;
      case "CONNECTING":
        return ReplicatorActivityLevel.connecting;
        break;
    }

    return null;
  }

  Map<String, dynamic> toJson() {
    return {"replicatorId": replicatorId, "config": config};
  }
}

class ReplicatorStatus {
  final ReplicatorActivityLevel activity;
  final String error;

  ReplicatorStatus._internal(this.activity, this.error);
}

class ReplicatorChange {
  final Replicator replicator;
  final ReplicatorStatus status;

  ReplicatorChange(this.replicator, this.status);
}
