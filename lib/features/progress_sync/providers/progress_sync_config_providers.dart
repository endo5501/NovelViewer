import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/shared/providers/platform_capabilities_provider.dart';

import '../domain/oauth_client.dart';

final oauthClientConfigProvider = Provider<OAuthClientConfig>(
  (ref) => const OAuthClientConfig.fromEnvironment(),
);

/// The OAuth client for the running platform, or null when this build cannot
/// sign in here.
final oauthClientProvider = Provider<OAuthClient?>(
  (ref) => resolveOAuthClient(
    ref.watch(platformCapabilitiesProvider).progressSyncSignIn,
    ref.watch(oauthClientConfigProvider),
  ),
);

/// Whether progress sync is offered at all. Surfaces watch this; the sync
/// service also refuses on it, so a surface added without a guard cannot
/// reach Google.
final progressSyncAvailableProvider = Provider<bool>(
  (ref) => ref.watch(oauthClientProvider) != null,
);
