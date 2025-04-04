import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

class SFTPLoginPage extends StatefulWidget {
  const SFTPLoginPage({
    super.key,
    @visibleForTesting this.forceAppBarLeading = true,
  });

  /// Whether to force the AppBar to have a leading back button
  final bool forceAppBarLeading;

  @override
  State<SFTPLoginPage> createState() => _SFTPLoginPageState();
}

class _SFTPLoginPageState extends State<SFTPLoginPage> {
  static const width = 400.0;
  final TextEditingController _serverUrlController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
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
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth > width ? (screenWidth - width) / 2 : 16,
          vertical: 16,
        ),
        children: [
          const SizedBox(height: 16),
          const SizedBox(height: 64),
          const SizedBox(height: 32),
          const SizedBox(height: 16),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Add SFTP Profile',
                  style: textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _serverUrlController,
            decoration: InputDecoration(
              labelText: 'Server URL',
              hintText: 'https://sftp.example.com',
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: 'Username',
              hintText: 'user',
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'pass',
            ),
          ),
          const SizedBox(height: 4),
          ElevatedButton(
            onPressed: () {
              // Handle adding SFTP profile
              // TODO remove this
              print('Server URL: ${_serverUrlController.text}');
              print('Username: ${_usernameController.text}');
              print('Password: ${_passwordController.text}');

              getSFTPconnection();
            },
            child: Text('Add SFTP Profile'),
          ),
        ],
      ),
    );
  }
  getSFTPconnection() async {
    final socket = await SSHSocket.connect(_serverUrlController.text, 22);
  final client = SSHClient(
    socket,
    username: _usernameController.text,
    onPasswordRequest: () => _passwordController.text,
  );

  final uptime = await client.run('ls -la');
  print(utf8.decode(uptime));

  client.close();
  await client.done;
  }
}
