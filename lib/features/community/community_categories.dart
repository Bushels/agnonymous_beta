class CommunityCategory {
  final String name;
  final String icon;

  const CommunityCategory({
    required this.name,
    required this.icon,
  });
}

class MonetteArea {
  final String name;
  final String region;

  const MonetteArea({
    required this.name,
    required this.region,
  });
}

const List<CommunityCategory> boardCategories = [
  CommunityCategory(name: 'Monette', icon: '\u{1F4CD}'),
  CommunityCategory(name: 'General', icon: '\u{1F4DD}'),
  CommunityCategory(name: 'Grain', icon: '\u{1F33E}'),
  CommunityCategory(name: 'Ag Business', icon: '\u{1F3E2}'),
  CommunityCategory(name: 'Equipment', icon: '\u{1F527}'),
  CommunityCategory(name: 'Land', icon: '\u{1F5FA}\uFE0F'),
  CommunityCategory(name: 'Politics', icon: '\u{1F3DB}\uFE0F'),
  CommunityCategory(name: 'Weather', icon: '\u{1F326}\uFE0F'),
];

const String defaultBoardCategory = 'Monette';

const List<MonetteArea> monetteAreas = [
  MonetteArea(name: 'Hafford', region: 'West-Central SK'),
  MonetteArea(name: 'Swift Current', region: 'Southwest SK'),
  MonetteArea(name: 'Stewart Valley', region: 'Swift Current, SK'),
  MonetteArea(name: 'Regina South', region: 'Regina, SK'),
  MonetteArea(name: 'Regina I', region: 'Regina, SK'),
  MonetteArea(name: 'Havre Land', region: 'Havre / Box Elder, MT'),
  MonetteArea(name: 'Wymark', region: 'Southwest SK'),
  MonetteArea(name: 'Wymark / Waldeck', region: 'Southwest SK'),
  MonetteArea(name: 'Vanguard', region: 'Southwest SK'),
  MonetteArea(name: 'Ponteix', region: 'Southwest SK'),
  MonetteArea(name: 'Outlook', region: 'Central SK - Irrigation'),
  MonetteArea(name: 'Raymore', region: 'East-Central SK'),
  MonetteArea(name: 'Kamsack', region: 'East-Central SK'),
  MonetteArea(name: 'Prince Albert', region: 'North-Central SK'),
  MonetteArea(name: 'Calderbank', region: 'Central SK'),
  MonetteArea(name: 'Admiral', region: 'Southwest SK'),
  MonetteArea(name: 'Eddystone', region: 'Interlake MB'),
  MonetteArea(name: 'The Pas', region: 'Northern MB'),
  MonetteArea(name: 'Montana', region: 'Big Horn County, MT'),
  MonetteArea(name: 'Other Monette area', region: 'Not listed'),
];

bool isKnownMonetteArea(String? area) {
  if (area == null) return false;
  final normalized = area.trim().toLowerCase();
  return monetteAreas.any(
    (monetteArea) => monetteArea.name.toLowerCase() == normalized,
  );
}

String iconForBoardCategory(String category) {
  for (final boardCategory in boardCategories) {
    if (boardCategory.name.toLowerCase() == category.toLowerCase()) {
      return boardCategory.icon;
    }
  }

  switch (category.toLowerCase()) {
    case 'farming':
    case 'agriculture':
      return '\u{1F69C}';
    case 'livestock':
      return '\u{1F404}';
    case 'ranching':
      return '\u{1F920}';
    case 'crops':
      return '\u{1F33E}';
    case 'markets':
      return '\u{1F4C8}';
    case 'chemicals':
    case 'inputs':
      return '\u{1F9EA}';
    case 'ag business':
    case 'agribusiness':
    case 'ag retail':
    case 'retailers':
    case 'companies':
      return '\u{1F3E2}';
    case 'input prices':
      return '\u{1F4B0}';
    case 'other':
      return '\u{1F517}';
    default:
      return '\u{1F4DD}';
  }
}
