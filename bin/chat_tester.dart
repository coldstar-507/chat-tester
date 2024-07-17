import 'package:chat_tester/chat_tester.dart' as chat_tester;
import 'package:chat_tester/dev_conn_tester.dart' as dev_conn_tester;


// device connection tester
// takes the device in argument
// then listens for input to sent text events to device
void main(List<String> arguments) {
  final (userSecret, dev) = (arguments[0], arguments[1]);
  print("userSecret=$userSecret, dev=$dev");
  return dev_conn_tester.run(userSecret, dev);
}


// chat connection tester
// takes the root and the device as argument
// then listens to input to broadcast messages to the root
// void main(List<String> arguments) {
//   print("arguments: $arguments");
//   return chat_tester.connect(arguments[0], arguments[1]);
// }
