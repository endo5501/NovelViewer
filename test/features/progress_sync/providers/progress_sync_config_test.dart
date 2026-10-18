import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/progress_sync/domain/oauth_client.dart';
import 'package:novel_viewer/features/progress_sync/providers/progress_sync_config_providers.dart';
import 'package:novel_viewer/shared/platform/platform_capabilities.dart';
import 'package:novel_viewer/shared/providers/platform_capabilities_provider.dart';

const _full = OAuthClientConfig(
  desktopClientId: 'desk-id',
  desktopClientSecret: 'desk-secret',
  iosClientId: 'ios-id',
);

void main() {
  group('resolveOAuthClient', () {
    test('desktop needs the client id and the secret', () {
      final client = resolveOAuthClient(ProgressSyncSignIn.desktop, _full);

      expect(client, isNotNull);
      expect(client!.signIn, ProgressSyncSignIn.desktop);
      expect(client.clientId, 'desk-id');
      expect(client.clientSecret, 'desk-secret');
    });

    test('desktop without the secret has no sync', () {
      const config = OAuthClientConfig(
        desktopClientId: 'desk-id',
        desktopClientSecret: '',
        iosClientId: 'ios-id',
      );

      expect(resolveOAuthClient(ProgressSyncSignIn.desktop, config), isNull);
    });

    test('desktop without the client id has no sync', () {
      const config = OAuthClientConfig(
        desktopClientId: '',
        desktopClientSecret: 'desk-secret',
        iosClientId: 'ios-id',
      );

      expect(resolveOAuthClient(ProgressSyncSignIn.desktop, config), isNull);
    });

    test('iOS needs only its client id', () {
      const config = OAuthClientConfig(
        desktopClientId: '',
        desktopClientSecret: '',
        iosClientId: 'ios-id',
      );
      final client = resolveOAuthClient(ProgressSyncSignIn.ios, config);

      expect(client, isNotNull);
      expect(client!.clientId, 'ios-id');
      expect(client.clientSecret, isNull);
    });

    test('iOS without its client id has no sync', () {
      const config = OAuthClientConfig(
        desktopClientId: 'desk-id',
        desktopClientSecret: 'desk-secret',
        iosClientId: '',
      );

      expect(resolveOAuthClient(ProgressSyncSignIn.ios, config), isNull);
    });
  });

  test('a build without injected values has no sync', () {
    expect(OAuthClientConfig.fromEnvironment().isEmpty, isTrue);
  });

  group('providers', () {
    test('sync is available when the build carries the platform values', () {
      final container = ProviderContainer(
        overrides: [
          oauthClientConfigProvider.overrideWithValue(_full),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities.forPlatform(isIOS: true, isMacOS: false),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(progressSyncAvailableProvider), isTrue);
      expect(container.read(oauthClientProvider)!.clientId, 'ios-id');
    });

    test('sync is unavailable without the values', () {
      final container = ProviderContainer(
        overrides: [
          oauthClientConfigProvider.overrideWithValue(
            const OAuthClientConfig(
              desktopClientId: '',
              desktopClientSecret: '',
              iosClientId: '',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(progressSyncAvailableProvider), isFalse);
    });

    test('availability can be overridden directly', () {
      final container = ProviderContainer(
        overrides: [progressSyncAvailableProvider.overrideWithValue(true)],
      );
      addTearDown(container.dispose);

      expect(container.read(progressSyncAvailableProvider), isTrue);
    });
  });
}
