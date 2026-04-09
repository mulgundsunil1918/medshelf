import 'package:shared_preferences/shared_preferences.dart';

/// Persists specialty-onboarding state in SharedPreferences.
class OnboardingService {
  OnboardingService._();
  static final OnboardingService instance = OnboardingService._();

  static const _kCompleted = 'hasCompletedSpecialtySetup';
  static const _kSpecialties = 'selected_specialties';
  static const _kTutorialSeen        = 'has_seen_tutorial';
  static const _kAuthSeen            = 'has_seen_auth';
  static const _kPermissionExplained = 'permission_explained';

  Future<bool> hasExplainedPermission() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPermissionExplained) ?? false;
  }

  Future<void> setPermissionExplained() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPermissionExplained, true);
  }

  Future<bool> hasSeenTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kTutorialSeen) ?? false;
  }

  Future<void> markTutorialSeen() => setHasSeenTutorial();

  Future<void> setHasSeenTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTutorialSeen, true);
  }

  Future<bool> hasSeenAuth() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAuthSeen) ?? false;
  }

  Future<void> setHasSeenAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAuthSeen, true);
  }

  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kCompleted) ?? false;
  }

  Future<void> setOnboardingComplete() => setHasCompletedOnboarding();

  Future<void> setHasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCompleted, true);
  }

  Future<List<String>> getSelectedSpecialties() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSpecialties) ?? '';
    if (raw.isEmpty) return [];
    return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  Future<void> saveSelectedSpecialties(List<String> names) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSpecialties, names.join(','));
  }
}
