import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/features/meal/data/repositories/meal_repository_impl.dart';
import 'package:not_eat_alone/features/meal/domain/repositories/meal_repository.dart';

final mealRepositoryProvider = Provider<MealRepository>((ref) => MealRepositoryImpl());
