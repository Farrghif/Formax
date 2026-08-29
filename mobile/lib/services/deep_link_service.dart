import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../pages/fillformpage.dart';

/// Menangani deep link (custom scheme `form4x://app/f/<slug>`).
///
/// Saat aplikasi menerima link (dari ketukan link atau hasil pindai QR),
/// ekstrak slug-nya lalu navigasi langsung ke [FillFormPage].
class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  /// Dipakai MaterialApp supaya kita bisa navigasi dari luar widget tree.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  bool _initialized = false;

  /// Panggil di main() agar link awal (cold start) ikut tertangkap.
  void init() {
    if (_initialized) return;
    _initialized = true;
    _sub = _appLinks.uriLinkStream.listen((uri) {
      _handle(uri);
    });
  }

  Uri? _pendingUri;

  void _handle(Uri uri) {
    final slug = _extractSlug(uri);
    if (slug == null || slug.isEmpty) return;

    _pendingUri = uri;
    _tryNavigate();
  }

  String? _extractSlug(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.contains('f')) {
      final index = segments.indexOf('f');
      if (index + 1 < segments.length) {
        return segments[index + 1];
      }
    }
    if (segments.isNotEmpty) {
      return segments.last;
    }
    return null;
  }

  void _tryNavigate() {
    final uri = _pendingUri;
    if (uri == null) return;
    final slug = _extractSlug(uri);
    if (slug == null || slug.isEmpty) return;

    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      // Navigator belum siap (mis. cold start) — coba lagi sebentar.
      Future.delayed(const Duration(milliseconds: 300), _tryNavigate);
      return;
    }

    _pendingUri = null;
    Navigator.of(ctx).push(
      MaterialPageRoute(builder: (_) => FillFormPage(slug: slug)),
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _initialized = false;
  }
}
