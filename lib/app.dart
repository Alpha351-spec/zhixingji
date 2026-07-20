import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'shared/navigation/main_scaffold.dart';

/// 应用根组件
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '知行计',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainScaffold(),
    );
  }
}
