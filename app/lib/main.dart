import 'package:asb_client/asb_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  await RustLib.init();
  final dir = await getApplicationSupportDirectory();
  final client = await RustClient.open(dir: dir.path);
  final controller = await AppController.load(client: client, supportDir: dir.path);
  runApp(AsbApp(controller: controller));
}
