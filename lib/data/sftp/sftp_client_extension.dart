import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:encrypt/encrypt.dart';
import 'package:nextcloud/provisioning_api.dart';
import 'package:nextcloud/webdav.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/nextcloud/errors.dart';
import 'package:saber/data/prefs.dart';

class SFTPClient {

  static const String appRootDirectoryPrefix =
      FileManager.appRootDirectoryPrefix;
  static const String configFileName = 'config.sbc';
  static final PathUri configFileUri =
      PathUri.parse('$appRootDirectoryPrefix/$configFileName');

  static const _utf8Decoder = Utf8Decoder(allowMalformed: true);

  static const String reproducibleSalt = r'8MnPs64@R&mF8XjWeLrD';

  final SSHClient _client; // Instance proměnná pro klienta

  SFTPClient._(this._client); // Soukromý konstruktor pro interní použití

  static Future<SFTPClient?> withSavedDetails() async {
    if (!Prefs.sftploggedIn) return null;

    String url = Prefs.sftpUrl.value;
    int port = int.parse(Prefs.sftpPort.value);
    String username = Prefs.sftpUsername.value;
    String sftpPassword = Prefs.sftpPassword.value;

    try {
      final socket = await SSHSocket.connect(url, port);
      final client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => sftpPassword,
      );

      final sftpClientInstance = SFTPClient._(client);
      void deAuth() {
        sftpClientInstance._client.close();
      }

      Prefs.username.addListener(deAuth);

      return sftpClientInstance;
    } catch (e) {
      log('Chyba při připojování: $e');
      return null;
    }
  }

  factory SFTPClient(SSHSocket socket, String username, String sftpPassword) {
    final client = SSHClient(
      socket,
      username: username,
      onPasswordRequest: () => sftpPassword,
    );
    return SFTPClient._(client);
  }

  /// Downloads the config from sftp
  Future<Map<String, String>> getConfig() async {
    final Uint8List bytes;
    try {
      final sftp = await _client.sftp();
      final file = await sftp.open(configFileUri.toString());
      bytes = await file.readBytes();
    }
    on SftpStatusError {
      return {};
    }


    final json = _utf8Decoder.convert(bytes);
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.cast<String, String>();
  }

  /// Generates a config using known values (i.e. from [Prefs]),
  /// updating the given [config] in place.
  ///
  /// This is usually preceded by a call to [getConfig]
  /// and followed by a call to [setConfig].
  ///
  /// Returns the existing [config] for convenience.
  Future<Map<String, String>> generateConfig({
    required Map<String, String> config,
    Encrypter? encrypter,
    IV? iv,
    Key? key,
  }) async {
    encrypter ??= this.encrypter;
    iv ??= IV.fromBase64(Prefs.iv.value);
    key ??= Key.fromBase64(Prefs.key.value);

    config[Prefs.key.key] = encrypter.encrypt(key.base64, iv: iv).base64;
    config[Prefs.iv.key] = iv.base64;

    return config;
  }

  /// Uploads the given [config] to Nextcloud
  Future<void> setConfig(Map<String, String> config) async {
    String json = jsonEncode(config);
    Uint8List file = Uint8List.fromList(json.codeUnits);

    final sftp = await _client.sftp();
    await sftp.mkdir(appRootDirectoryPrefix.toString());
    final configRemote = await sftp.open(configFileUri.toString(), mode: SftpFileOpenMode.create | SftpFileOpenMode.truncate | SftpFileOpenMode.write);
    await configRemote.writeBytes(file);
  }

  Future<String> loadEncryptionKey({
    bool generateKeyIfMissing = true,
  }) async {
    final Encrypter encrypter = this.encrypter;

    final Map<String, String> config = await getConfig();
    if (config.containsKey(Prefs.key.key) && config.containsKey(Prefs.iv.key)) {
      final IV iv = IV.fromBase64(config[Prefs.iv.key]!);
      final String encryptedKey = config[Prefs.key.key]!;
      try {
        final String key = encrypter.decrypt64(encryptedKey, iv: iv);
        Prefs.key.value = key;
        Prefs.iv.value = iv.base64;
        return key;
      } catch (e) {
        // can't decrypt, so we need to get the previous encryption key (user's password)
        throw EncLoginFailure();
      }
    }

    if (!generateKeyIfMissing) throw EncLoginFailure();

    final Key key = Key.fromSecureRandom(32);
    final IV iv = IV.fromSecureRandom(16);

    await generateConfig(
      config: config,
      encrypter: encrypter,
      iv: iv,
      key: key,
    );
    await setConfig(config);

    Prefs.key.value = key.base64;
    Prefs.iv.value = iv.base64;

    return key.base64;
  }

  Future<String> getUsername() async {
    final user = await _client.run('whoami');
    return (user as String).trim();
  }

  Encrypter get encrypter {
    final List<int> encodedPassword =
        utf8.encode(Prefs.encPassword.value + reproducibleSalt);
    final List<int> hashedPasswordBytes = sha256.convert(encodedPassword).bytes;
    final Key passwordKey = Key(hashedPasswordBytes as Uint8List);
    return Encrypter(AES(passwordKey));
  }

  Future<Quota> getStorageQuota() async {
    final sftp = await _client.sftp();
    final statvfs = await sftp.statvfs('/root');
    final total = statvfs.blockSize * statvfs.totalBlocks;
    final free  = statvfs.blockSize * statvfs.freeBlocks;
    final json = {
      'free': free,
      'relative': ((total - free) / total * 100).round(),
      'total': total,
      'used': total - free,
    };
    return UserDetailsQuota.fromJson(json);

  }
}
