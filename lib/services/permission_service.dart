import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  /// Returns the Android SDK version, or 0 on non-Android platforms.
  Future<int> _sdkVersion() async {
    if (!Platform.isAndroid) return 0;
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt;
  }

  // ─── Check ────────────────────────────────────────────────────────────────

  /// Returns true if MedShelf already has the storage access it needs.
  Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return true;
    final sdk = await _sdkVersion();
    if (sdk >= 30) {
      return Permission.manageExternalStorage.isGranted;
    }
    return Permission.storage.isGranted;
  }

  // ─── Request ──────────────────────────────────────────────────────────────

  /// Requests the appropriate storage permission for the running Android version.
  ///
  /// - Android 13+ (SDK 33+): requests granular media + MANAGE_EXTERNAL_STORAGE
  /// - Android 11–12 (SDK 30–32): requests MANAGE_EXTERNAL_STORAGE
  /// - Android 10 and below: requests READ/WRITE_EXTERNAL_STORAGE
  ///
  /// Opens app settings if permanently denied.
  /// Returns `true` when the app has sufficient access.
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    final sdk = await _sdkVersion();

    if (sdk >= 33) {
      // Android 13+: granular media permissions + all-files access
      await Permission.photos.request();
      await Permission.videos.request();
      await Permission.audio.request();
      // All-files access is needed to write to /storage/emulated/0/MedShelf/
      final manage = await Permission.manageExternalStorage.request();
      if (manage.isPermanentlyDenied) await openAppSettings();
      return manage.isGranted;
    } else if (sdk >= 30) {
      // Android 11–12: all-files access
      final status = await Permission.manageExternalStorage.status;
      if (status.isGranted) return true;
      final result = await Permission.manageExternalStorage.request();
      if (result.isPermanentlyDenied) await openAppSettings();
      return result.isGranted;
    } else {
      // Android 10 and below
      final result = await Permission.storage.request();
      if (result.isPermanentlyDenied) await openAppSettings();
      return result.isGranted;
    }
  }
}
