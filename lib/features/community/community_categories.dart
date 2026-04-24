class CommunityCategory {
  final String name;
  final String icon;

  const CommunityCategory({
    required this.name,
    required this.icon,
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
