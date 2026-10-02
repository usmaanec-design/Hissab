import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web_gis;

Widget buildGoogleWebSignInButton({
  VoidCallback? onFallbackPressed,
}) {
  try {
    return web_gis.renderButton(
      configuration: web_gis.GSIButtonConfiguration(
        theme: web_gis.GSIButtonTheme.outline,
        size: web_gis.GSIButtonSize.large,
        text: web_gis.GSIButtonText.signinWith,
        shape: web_gis.GSIButtonShape.rectangular,
        logoAlignment: web_gis.GSIButtonLogoAlignment.left,
      ),
    );
  } catch (e) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.login),
      label: const Text('Sign in with Google'),
      onPressed: onFallbackPressed,
    );
  }
}
