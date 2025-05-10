import 'package:flutter/material.dart';
import 'package:saber/components/sftp/done_login_step.dart';
import 'package:saber/components/sftp/enc_login_step.dart';
import 'package:saber/components/sftp/sftp_login_step.dart';
import 'package:saber/data/prefs.dart';

class SFTPLoginPage extends StatefulWidget {
  const SFTPLoginPage({
    super.key,
    @visibleForTesting this.forceAppBarLeading = true,
  });

  /// Whether to force the AppBar to have a leading back button
  final bool forceAppBarLeading;

  @override
  State<SFTPLoginPage> createState() => _SFTPLoginPageState();

  static LoginStep getCurrentStep() {
    if (!Prefs.sftpUrl.loaded ||
        !Prefs.sftpUsername.loaded ||
        !Prefs.sftpPassword.loaded ||
        !Prefs.encPassword.loaded ||
        !Prefs.key.loaded ||
        !Prefs.iv.loaded) {
      return LoginStep.waitingForPrefs;
    }

    if (Prefs.sftpUsername.value.isEmpty || 
        Prefs.sftpPassword.value.isEmpty ||
        Prefs.sftpUrl.value.isEmpty ||
        Prefs.sftpPort.value.isEmpty) {
      return LoginStep.sftp;
    }
    if (Prefs.encPassword.value.isEmpty ||
        Prefs.key.value.isEmpty ||
        Prefs.iv.value.isEmpty) {
      return LoginStep.enc;
    }

    return LoginStep.done;
  }
}

class _SFTPLoginPageState extends State<SFTPLoginPage> {

  late LoginStep step = LoginStep.waitingForPrefs;

  @override
  void initState() {
    waitForPrefs();
    super.initState();
  }

  Future<void> waitForPrefs() async {
    step = LoginStep.waitingForPrefs;

    if (!Prefs.sftpUrl.loaded ||
        !Prefs.sftpUsername.loaded ||
        !Prefs.sftpPassword.loaded ||
        !Prefs.sftpPort.loaded ||
        !Prefs.key.loaded ||
        !Prefs.iv.loaded)
      await Future.wait([
        Prefs.sftpUrl.waitUntilLoaded(),
        Prefs.sftpUsername.waitUntilLoaded(),
        Prefs.sftpPassword.waitUntilLoaded(),
        Prefs.sftpPort.waitUntilLoaded(),
        Prefs.key.waitUntilLoaded(),
        Prefs.iv.waitUntilLoaded()
      ]);

    recheckCurrentStep();
  }

  void recheckCurrentStep() {
    final prevStep = step;
    step = SFTPLoginPage.getCurrentStep();

    if (prevStep != step) if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add SFTP Profile'),
        leading: widget.forceAppBarLeading
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: switch (step) {
        LoginStep.waitingForPrefs =>
          const Center(child: CircularProgressIndicator()),
        LoginStep.sftp => SFTPLoginStep(recheckCurrentStep: recheckCurrentStep),
        LoginStep.enc => EncLoginStep(recheckCurrentStep: recheckCurrentStep),
        LoginStep.done => DoneLoginStep(recheckCurrentStep: recheckCurrentStep),
      },
    );
  }
}

enum LoginStep {
  /// We're waiting for the Prefs to be loaded
  waitingForPrefs(0),

  /// The user needs to authenticate with the sftp server
  sftp(0.2),

  /// The user needs to provide their encryption password
  enc(0.6),

  /// The user is fully logged in
  done(1);

  const LoginStep(this.progress) : assert(progress >= 0 && progress <= 1);

  /// The value used for the LinearProgressIndicator on this step
  final double progress;
}
