import 'package:flutter/material.dart';
import 'package:not_eat_alone/core/config/flavor.dart';

class PlaceholderHome extends StatelessWidget {
  const PlaceholderHome({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(FlavorConfig.current.appTitle)),
      body: const Center(child: Text('not-eat-alone — foundation OK')),
    );
  }
}
