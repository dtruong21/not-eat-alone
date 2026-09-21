import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/domain/repositories/restaurant_search_repository.dart';

/// In-memory stand-in for a future Google Places-backed datasource.
///
/// Holds a fixed list of real Paris restaurants and filters them in memory.
/// Deliberately has no `firebase` import — this is a pure data-layer fake.
class FakeRestaurantSearchDataSource implements RestaurantSearchRepository {
  static const List<Restaurant> _restaurants = [
    Restaurant(
      placeId: 'fake_001',
      name: 'Le Comptoir du Relais',
      address: "9 Carrefour de l'Odéon, 75006 Paris",
      lat: 48.8517,
      lng: 2.3389,
    ),
    Restaurant(
      placeId: 'fake_002',
      name: 'Bistrot Paul Bert',
      address: '18 Rue Paul Bert, 75011 Paris',
      lat: 48.8534,
      lng: 2.3839,
    ),
    Restaurant(
      placeId: 'fake_003',
      name: 'Septime',
      address: '80 Rue de Charonne, 75011 Paris',
      lat: 48.8558,
      lng: 2.3799,
    ),
    Restaurant(
      placeId: 'fake_004',
      name: 'Le Chateaubriand',
      address: '129 Avenue Parmentier, 75011 Paris',
      lat: 48.8657,
      lng: 2.3746,
    ),
    Restaurant(
      placeId: 'fake_005',
      name: 'Breizh Café',
      address: '109 Rue Vieille du Temple, 75003 Paris',
      lat: 48.8634,
      lng: 2.3625,
    ),
    Restaurant(
      placeId: 'fake_006',
      name: "L'Ami Jean",
      address: '27 Rue Malar, 75007 Paris',
      lat: 48.8595,
      lng: 2.3054,
    ),
    Restaurant(
      placeId: 'fake_007',
      name: 'Chez Georges',
      address: '1 Rue du Mail, 75002 Paris',
      lat: 48.8677,
      lng: 2.3417,
    ),
    Restaurant(
      placeId: 'fake_008',
      name: 'Le Baratin',
      address: '3 Rue Jouye-Rouve, 75020 Paris',
      lat: 48.8721,
      lng: 2.3865,
    ),
    Restaurant(
      placeId: 'fake_009',
      name: 'Frenchie',
      address: '5-6 Rue du Nil, 75002 Paris',
      lat: 48.8677,
      lng: 2.3468,
    ),
    Restaurant(
      placeId: 'fake_010',
      name: 'Clover Grill',
      address: '6 Rue Bailleul, 75001 Paris',
      lat: 48.8604,
      lng: 2.3417,
    ),
    Restaurant(
      placeId: 'fake_011',
      name: 'Le Servan',
      address: '32 Rue Saint-Maur, 75011 Paris',
      lat: 48.8617,
      lng: 2.3806,
    ),
    Restaurant(
      placeId: 'fake_012',
      name: 'Bouillon Pigalle',
      address: '22 Boulevard de Clichy, 75018 Paris',
      lat: 48.8827,
      lng: 2.3374,
    ),
    Restaurant(
      placeId: 'fake_013',
      name: 'Au Pied de Cochon',
      address: '6 Rue Coquillière, 75001 Paris',
      lat: 48.8625,
      lng: 2.3448,
    ),
    Restaurant(
      placeId: 'fake_014',
      name: 'Robert et Louise',
      address: '64 Rue Vieille du Temple, 75003 Paris',
      lat: 48.8615,
      lng: 2.3617,
    ),
    Restaurant(
      placeId: 'fake_015',
      name: 'Chez Janou',
      address: '2 Rue Roger Verlomme, 75003 Paris',
      lat: 48.8564,
      lng: 2.3654,
    ),
    Restaurant(
      placeId: 'fake_016',
      name: 'Le Grand Véfour',
      address: '17 Rue de Beaujolais, 75001 Paris',
      lat: 48.8646,
      lng: 2.3379,
    ),
    Restaurant(
      placeId: 'fake_017',
      name: "La Tour d'Argent",
      address: '15 Quai de la Tournelle, 75005 Paris',
      lat: 48.8503,
      lng: 2.3543,
    ),
    Restaurant(
      placeId: 'fake_018',
      name: 'Le Petit Cambodge',
      address: '20 Rue Alibert, 75010 Paris',
      lat: 48.8703,
      lng: 2.3641,
    ),
    Restaurant(
      placeId: 'fake_019',
      name: 'Holybelly',
      address: '19 Rue Lucien Sampaix, 75010 Paris',
      lat: 48.8717,
      lng: 2.3609,
    ),
    Restaurant(
      placeId: 'fake_020',
      name: 'Clamato',
      address: '80 Rue de Charonne, 75011 Paris',
      lat: 48.8556,
      lng: 2.3798,
    ),
  ];

  @override
  Future<List<Restaurant>> search(String query) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return _restaurants;
    }
    return _restaurants
        .where(
          (restaurant) =>
              restaurant.name.toLowerCase().contains(trimmed) ||
              restaurant.address.toLowerCase().contains(trimmed),
        )
        .toList();
  }
}
