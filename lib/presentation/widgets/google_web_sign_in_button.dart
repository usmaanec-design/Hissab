import 'package:flutter/widgets.dart';

import 'google_web_sign_in_button_stub.dart'
    if (dart.library.js_interop) 'google_web_sign_in_button_web.dart' as impl;

/// Cross-platform wrapper that renders official GIS Google button on Web
/// and renders a fallback or empty widget on non-web platforms.
class GoogleWebSignInWidget extends StatelessWidget {
  final VoidCallback? onFallbackPressed;

  const GoogleWebSignInWidget({super.key, this.onFallbackPressed});

  @override
  Widget build(BuildContext context) {
    return impl.buildGoogleWebSignInButton(onFallbackPressed: onFallbackPressed);
  }
}
