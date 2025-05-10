import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nextcloud/provisioning_api.dart';
import 'package:saber/components/theming/adaptive_icon.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/nextcloud/readable_bytes.dart';
import 'package:saber/data/nextcloud/saber_syncer.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/sftp/sftp_client_extension.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/user/sftp.dart';

typedef Quota = UserDetailsQuota;

class SftpProfile extends StatefulWidget {
  const SftpProfile({super.key});

  @override
  State<SftpProfile> createState() => _SftpProfileState();

  /// If non-null, this will be used instead of the actual login state.
  @visibleForTesting
  static LoginStep? forceLoginStep;
}

class _SftpProfileState extends State<SftpProfile> {
  @override
  void initState() {
    Prefs.sftpUsername.addListener(_usernameChanged);
    Prefs.encPassword.addListener(_usernameChanged);
    Prefs.key.addListener(_usernameChanged);
    Prefs.iv.addListener(_usernameChanged);
    super.initState();
  }

  @override
  void dispose() {
    Prefs.sftpUsername.removeListener(_usernameChanged);
    Prefs.encPassword.removeListener(_usernameChanged);
    Prefs.key.removeListener(_usernameChanged);
    Prefs.iv.removeListener(_usernameChanged);
    super.dispose();
  }

  late var getStorageQuotaFuture = getStorageQuota();
  void _usernameChanged() {
    getStorageQuotaFuture = getStorageQuota();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final loginStep =
        SftpProfile.forceLoginStep ?? SFTPLoginPage.getCurrentStep();
    final heading = switch (loginStep) {
      LoginStep.waitingForPrefs => '',
      LoginStep.sftp => 'Add SFTP Profile',
      LoginStep.enc ||
      LoginStep.done =>
        t.login.status.hi(u: Prefs.sftpUsername.value),
    };
    final subheading = switch (loginStep) {
      LoginStep.waitingForPrefs => '',
      LoginStep.sftp => 'You can use SFTP as a lighter alternative to Nextcloud',
      LoginStep.enc => t.login.status.almostDone,
      LoginStep.done => t.login.status.loggedIn,
    };

    var colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: () => context.push(RoutePaths.sftp),
      leading: ValueListenableBuilder(
        valueListenable: Prefs.pfp,
        builder: (BuildContext context, Uint8List? pfp, _) {
          if (pfp == null) {
            return const Icon(Icons.account_circle, size: 48);
          } else {
            return ClipPath(
              clipper: ShapeBorderClipper(
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(40),
                ),
              ),
              child: Image.memory(
                pfp,
                width: 48,
                height: 48,
              ),
            );
          }
        },
      ),
      title: Text(heading),
      subtitle: Text(subheading),
      trailing: loginStep == LoginStep.done
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FutureBuilder(
                  future: getStorageQuotaFuture,
                  initialData: Prefs.sftpLastStorageQuota.value,
                  builder:
                      (BuildContext context, AsyncSnapshot<Quota?> snapshot) {
                    final Quota? quota = snapshot.data;
                    final double? relativePercent;
                    if (quota != null) {
                      relativePercent = quota.relative / 100;
                    } else {
                      relativePercent = null;
                    }

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: relativePercent,
                          backgroundColor:
                              colorScheme.primary.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary.withValues(alpha: 0.5),
                          ),
                          strokeWidth: 8,
                          semanticsLabel: 'Storage usage',
                          semanticsValue: snapshot.data != null
                              ? '${snapshot.data}%'
                              : null,
                        ),
                        Text(readableQuota(quota)),
                      ],
                    );
                  },
                ),
                IconButton(
                  icon: const AdaptiveIcon(
                    icon: Icons.cloud_upload,
                    cupertinoIcon: CupertinoIcons.cloud_upload,
                  ),
                  tooltip: t.settings.resyncEverything,
                  onPressed: () async {
                    Prefs.fileSyncResyncEverythingDate.value = DateTime.now();
                    final allFiles = await FileManager.getAllFiles(
                        includeExtensions: true, includeAssets: true);
                    for (final file in allFiles) {
                      syncer.uploader.enqueueRel(file);
                    }
                  },
                ),
              ],
            )
          : null,
    );
  }

  static Future<Quota?> getStorageQuota() async {
    if (SftpProfile.forceLoginStep != null)
      return Prefs.sftpLastStorageQuota.value;
      
      Quota? quota;

      final client = await SFTPClient.withSavedDetails();
      if (client != null) {
        quota = await client.getStorageQuota();
      }
    Prefs.sftpLastStorageQuota.value = quota;
    return Prefs.sftpLastStorageQuota.value;
  }

  static String readableQuota(Quota? quota) {
    final used = readableBytes(quota?.used);
    final total = readableBytes(quota?.total);
    return '$used / $total';
  }
}
