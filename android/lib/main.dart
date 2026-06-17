import 'package:flutter/material.dart';

import 'profile/profile_store.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await ProfileStore.load();
  runApp(BottleOfColorsApp(store: store));
}

class BottleOfColorsApp extends StatelessWidget {
  const BottleOfColorsApp({super.key, required this.store});

  final ProfileStore store;

  @override
  Widget build(BuildContext context) {
    return ProfileScope(
      store: store,
      child: MaterialApp(
        title: 'Bottle of Colors',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
