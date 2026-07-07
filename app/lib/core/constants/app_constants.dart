abstract final class AppConstants {
  static const String appName = 'RoadPack';
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const Duration locationUpdateInterval = Duration(seconds: 5);
  static const Duration sosCountdownDuration = Duration(seconds: 5);
  static const Duration crashCountdownDuration = Duration(seconds: 30);
  static const int maxEmergencyContacts = 5;
  static const int minEmergencyContacts = 1;
  static const int maxFamilyCircleMembers = 15;
  static const int maxFriendsCircleMembers = 25;
  static const int maxCommuteCircleMembers = 100;
  static const int maxConvoyCircleMembers = 50;
  static const int locationHistoryRetentionDays = 7;
}
