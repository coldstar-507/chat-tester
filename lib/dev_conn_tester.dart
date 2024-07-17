import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:async/async.dart' as asyn;
import 'package:chat_tester/chat_tester.dart';
import 'package:convert/convert.dart' as conv;

import 'package:http/http.dart' as http;

import 'types_flatgen_generated.dart' as fg;

final client = http.Client();

const TEXT_TYPE = 0x00;

////// UTILS //////

String strId(fg.PushId pid) {
  return "${pid.prefix}-${pid.timestamp}-${pid.unik}-${pid.place}-${pid.suffix}";
}

fg.PushId makePushId(String userId, String dev, [int? ts]) {
  return fg.PushId(makePushIdObjectBuilder(userId, dev, ts).toBytes());
}

fg.PushIdObjectBuilder makePushIdObjectBuilder(String userId, String dev,
    [int? ts]) {
  return fg.PushIdObjectBuilder(
      prefix: "$userId-$dev",
      place: "us",
      timestamp: ts ?? DateTime.now().millisecondsSinceEpoch,
      unik: randomUnik(),
      suffix: "p");
}

///// RUN /////

void run(String userId, String dev) async {
  final time = int.parse("1719244191786");
  final ref = strId(makePushId(userId, dev, time));

  connectToDev(userId, dev, ref);

  await for (final input in io.stdin) {
    final strIn = utf8.decode(input);
    sendPush(userId, dev, strIn);
  }
}

/// CORE ///

void sendPush(String userId, String dev, String input) async {
  final u8 = utf8.encode(input);
  final fullLen = 1 + 2 + u8.length;
  final payload = Uint8List(fullLen)
    ..[0] = TEXT_TYPE
    ..setRange(1, 3, makeUint16(u8.length))
    ..setRange(3, fullLen, u8);

  final body = fg.PushRequestObjectBuilder(
    pushId: makePushIdObjectBuilder(userId, dev),
    payload: payload,
  ).toBytes();

  final url = Uri.http("localhost:8080", "/push");
  final req = http.Request("POST", url)..bodyBytes = body;
  try {
    final res = await client.send(req);
    print("Push res status=${res.statusCode}");
  } catch (e) {
    print("Error making device push");
  }
}

void connectToDev(String userId, String dev, String ref) async {
  final url = Uri.http("localhost:8080", "/dev-conn/$ref");
  final req = http.Request("GET", url);
  try {
    final res = await client.send(req);
    final br = asyn.ChunkedStreamReader(res.stream);
    print("Starting to listen to conn on dev=$dev from ref=$ref");
    while (true) {
      print("waiting for message");
      final t = (await br.readBytes(1))[0];
      switch (t) {
        case 0x99:
          print("[HEARTBEAT]");
          continue;
        case 0x00:
          final l = readUint16(await br.readBytes(2));
          final payload = await br.readBytes(l);
          print("[TEXT] ${utf8.decode(payload)}");
          continue;
      }
    }
  } catch (e) {
    print("connectToDev error: $e, closing");
  }
}
