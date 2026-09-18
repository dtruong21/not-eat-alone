import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/firebase/options/firebase_options_stage.dart';
import 'package:not_eat_alone/main_common.dart';

Future<void> main() => bootstrap(
      config: FlavorConfig(flavor: Flavor.stage),
      options: DefaultFirebaseOptions.currentPlatform,
    );
