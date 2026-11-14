/// Deterministic real-image mapping so every object shows a distinct real photo.
class SpacePics {
  static const List<String> pool = [
    'assets/img/space/carina_nebula.jpg',
    'assets/img/space/orion_nebula.jpg',
    'assets/img/space/eagle.jpg',
    'assets/img/space/helix.jpg',
    'assets/img/space/ring_nebula.jpg',
    'assets/img/space/crab.jpg',
    'assets/img/space/horsehead.jpg',
    'assets/img/space/rosette.jpg',
    'assets/img/space/lagoon.jpg',
    'assets/img/space/pleiades.jpg',
    'assets/img/space/andromeda_galaxy.jpg',
    'assets/img/space/whirlpool.jpg',
    'assets/img/space/sombrero.jpg',
    'assets/img/space/triangulum.jpg',
    'assets/img/space/lmc.jpg',
    'assets/img/space/smc.jpg',
    'assets/img/space/milkyway.jpg',
    'assets/img/space/sun.jpg',
    'assets/img/space/earth.jpg',
  ];

  static const Map<String, String> planets = {
    'Mercury': 'assets/img/space/mercury.jpg',
    'Venus': 'assets/img/space/venus.jpg',
    'Earth': 'assets/img/space/earth.jpg',
    'Mars': 'assets/img/space/mars.jpg',
    'Jupiter': 'assets/img/space/jupiter.jpg',
    'Saturn': 'assets/img/space/saturn.jpg',
    'Uranus': 'assets/img/space/uranus.jpg',
    'Neptune': 'assets/img/space/neptune.jpg',
    'Sun': 'assets/img/space/sun.jpg',
    'Moon': 'assets/img/space/moon.jpg',
  };

  static const Map<String, String> galaxies = {
    'Andromeda (M31)': 'assets/img/space/andromeda_galaxy.jpg',
    'Whirlpool (M51)': 'assets/img/space/whirlpool.jpg',
    'Sombrero (M104)': 'assets/img/space/sombrero.jpg',
    'Triangulum (M33)': 'assets/img/space/triangulum.jpg',
    'Large Magellanic Cloud': 'assets/img/space/lmc.jpg',
    'Small Magellanic Cloud': 'assets/img/space/smc.jpg',
    'Milky Way': 'assets/img/space/milkyway.jpg',
  };

  static const Map<String, String> hypotheses = {
    'Core accretion': 'assets/img/space/orion_nebula.jpg',
    'Disk instability': 'assets/img/space/andromeda_galaxy.jpg',
    'Giant impact (Theia)': 'assets/img/space/moon.jpg',
    'Late veneer': 'assets/img/space/crab.jpg',
    'Water delivery': 'assets/img/space/earth.jpg',
  };

  static const Map<String, String> stages = {
    'The solar nebula': 'assets/img/space/carina_nebula.jpg',
    'Planetesimals and pebbles': 'assets/img/space/orion_nebula.jpg',
    'The magma ocean': 'assets/img/space/sun.jpg',
    'The Moon-forming impact': 'assets/img/space/moon.jpg',
    'Core and magnetic field': 'assets/img/space/earth.jpg',
    'Oceans and atmosphere': 'assets/img/space/earth.jpg',
    'Late accretion (the veneer)': 'assets/img/space/crab.jpg',
    'Continents and plate tectonics': 'assets/img/space/earth.jpg',
    'The Great Oxidation': 'assets/img/space/eagle.jpg',
    'Snowball and explosion of life': 'assets/img/space/earth.jpg',
    'The living planet': 'assets/img/space/earth.jpg',
  };

  static String forConstellation(String key) {
    var h = 0;
    for (final c in key.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return pool[h % pool.length];
  }

  static String forStar(String constellation) => forConstellation(constellation);

  static String forPlanet(String name) => planets[name] ?? 'assets/img/earth.jpg';

  static String forHypothesis(String name) => hypotheses[name] ?? pool[0];

  static String forStage(String title) => stages[title] ?? pool[0];

  static String forGalaxy(String name) => galaxies[name] ?? pool[0];
}
