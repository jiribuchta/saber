import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/pages/user/login.dart';

class SFTPProfile extends StatefulWidget {
  const SFTPProfile({super.key});

  @override
  State<SFTPProfile> createState() => _SFTPProfileState();

  /// If non-null, this will be used instead of the actual login state.
  @visibleForTesting
  static LoginStep? forceLoginStep;
}

class _SFTPProfileState extends State<SFTPProfile> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => context.push(RoutePaths.sftp),
      title: Text('Add SFTP Profile'),
      subtitle: Text('You can use SFTP as a lighter alternative to Nextcloud'),
    );
  }
}
