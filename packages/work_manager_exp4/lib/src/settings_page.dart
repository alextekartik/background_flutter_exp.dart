import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:work_manager_exp_common/screen_mixin.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with ExpScreenMixin<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          FutureBuilder<String>(
            builder: (context, snapshot) {
              var token = snapshot.data ?? '?';
              return ListTile(
                title: const Text('Push token (tap to copy)'),
                subtitle: Text(token),
                onTap: () async {
                  print(token);
                  await Clipboard.setData(ClipboardData(text: token));
                  if (context.mounted) {
                    snackInfo(context, 'Copied to clipboard');
                  }
                },
              );
            },
            future: () async {
              var messaging = FirebaseMessaging.instance;

              return (await messaging.getToken()) ?? '';
            }(),
          ),
        ],
      ),
    );
  }
}
