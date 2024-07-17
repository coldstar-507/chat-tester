import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:async/async.dart' as asyn;
import 'package:convert/convert.dart' as conv;

import 'types_flatgen_generated.dart' as fg;

// const root = "group1";
// const dev = "dev0";

final rand = math.Random();

int ts() => DateTime.now().millisecondsSinceEpoch;

bool before = true;
String ref = "1718814080989-9b6747abad18f58a-group0-us-c";
Future<void> sendScrollReq(io.Socket soc) async {
  final ref_ = utf8.encode(ref);
  final l = 1 + ref_.length;
  final fullLen = 3 + l;
  final buf = Uint8List(fullLen)
    ..[0] = 0x02
    ..setRange(1, 3, makeUint16(l))
    ..[3] = before ? 0x01 : 0x00
    ..setRange(4, fullLen, ref_);
  soc.add(buf);
  await soc.flush();
}

int readUint16(Uint8List d) {
  final i1 = ByteData.sublistView(d).getUint16(0);
  // var i2 = d.buffer.asByteData().getUint16(0);
  // print("i1=$i1, i2=$i2");
  return i1;
}

String randomUnik([int len = 8]) {
  final buf = Uint8List(len);
  for (int i = 0; i < len; i++) {
    buf[i] = rand.nextInt(256);
  }
  return conv.hex.encode(buf);
}

Uint8List makeUint16(int l) {
  return Uint8List(2)..buffer.asByteData().setUint16(0, l);
}

Uint8List makeChat(String root, String input) {
  return fg.MessageEvent2ObjectBuilder(
          chatId: fg.MessageIdObjectBuilder(
                  place: "us",
                  unik: randomUnik(),
                  timestamp: ts(),
                  root: root,
                  suffix: "c")
              .toBytes(),
          type: 0x00,
          root: root,
          txt: input,
          senderId: "scott",
          timestamp: ts())
      .toBytes();
}

String asStr(fg.MessageId mid) {
  final sbuf = StringBuffer()
    ..writeAll(
      [
        mid.timestamp,
        mid.unik,
        mid.root,
        mid.place,
        mid.suffix,
      ],
      "-",
    );
  return sbuf.toString();
}

void listenToMessages(io.Socket soc) async {
  final br = asyn.ChunkedStreamReader(soc);
  int t, l;
  Uint8List payload;
  while (true) {
    print("wating for message");
    t = (await br.readBytes(1))[0];
    print("CHAT_HEADER=$t");
    l = readUint16(await br.readBytes(2));
    print("PAYLOAD_LENGTH=$l");
    payload = await br.readBytes(l);
    print("payload len=${payload.length}");
    assert(payload.length == l);
    if (t == 0x01) {
      print("Message Sent!");
      final l2 = l ~/ 2;
      // print("payload=$payload");
      final pre = payload.sublist(0, l2);
      final pos = payload.sublist(l2);
      final preId = utf8.decode(pre);
      final posId = utf8.decode(pos);

      print("""
        preId=$preId prelen=${pre.length} strlen=${preId.length}
        posId=$posId poslen=${pos.length} strlen=${posId.length}""");

      // final preId = fg.MessageId(pre);
      // final posId = fg.MessageId(pos);
      // print("""
      //   pre=${asStr(preId)} prelen=${pre.length} strlen=${asStr(preId).length}
      //   pos=${asStr(posId)} poslen=${pos.length} strlen=${asStr(posId).length}""");

      // print("pre=${utf8.decode(pre)}\npos=${utf8.decode(pos)}");
    } else if (t == 0x04) {
      print("SCROLL DONE MY NIGGA");
    }
  }
}

void connect(String root, String dev) async {
  final soc = await io.Socket.connect("localhost", 11002);
  // send incomming messages to event queue

  listenToMessages(soc);

  // initialize chat conn
  final payload = utf8.encode("$root $dev");
  soc.add(makeUint16(payload.length));
  soc.add(payload);
  await soc.flush();

  await readInput(soc, root);
  await soc.close();
}

Future<void> readInput(io.Socket soc, String root) async {
  print("reading input");
  await for (final input in io.stdin) {
    final str = utf8.decode(input);
    final msg = makeChat(root, str);
    print("input = $str");
    if (str == "quit\n") break;
    if (str == "scroll\n") {
      await sendScrollReq(soc);
    } else {
      soc.add(const [0x00]);
      soc.add(makeUint16(msg.length));
      soc.add(msg);
      await soc.flush();
    }
  }
  print("exiting");
}
