import 'package:flutter/material.dart';

import 'app.dart';
import 'history_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TriagemApp(inicio: InicioHistorico()));
}
