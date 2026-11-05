import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final GoRouter _router = GoRouter(
  routes: [GoRoute(path: '/', builder: (context, state) => const Scaffold())],
);

class WeaveApp extends StatelessWidget {
  const WeaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Weave',
      routerConfig: _router,
      theme: ThemeData(fontFamily: 'Geist'),
    );
  }
}
