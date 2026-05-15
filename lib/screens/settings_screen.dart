import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../theme.dart';

/// Settings screen — lets user set:
/// - Device name (required, identifies this device's position)
/// - Optional Supabase cloud sync (URL + anon key)
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _deviceNameCtrl;
  late TextEditingController _supabaseUrlCtrl;
  late TextEditingController _supabaseKeyCtrl;
  late bool _cloudEnabled;
  bool _saving = false;
  bool _showKey = false;

  @override
  void initState() {
    super.initState();
    _deviceNameCtrl = TextEditingController(text: deviceNameVar);
    _cloudEnabled = cloudEnabled;
    _supabaseUrlCtrl = TextEditingController();
    _supabaseKeyCtrl = TextEditingController();
    _loadCloudPrefs();
  }

  Future<void> _loadCloudPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _supabaseUrlCtrl.text = prefs.getString('supabaseUrl') ?? '';
      _supabaseKeyCtrl.text = prefs.getString('supabaseAnonKey') ?? '';
    });
  }

  @override
  void dispose() {
    _deviceNameCtrl.dispose();
    _supabaseUrlCtrl.dispose();
    _supabaseKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final prefs = await SharedPreferences.getInstance();
    final name = _deviceNameCtrl.text.trim();
    await prefs.setString('deviceName', name);
    await prefs.setBool('cloudEnabled', _cloudEnabled);
    await prefs.setString('supabaseUrl', _supabaseUrlCtrl.text.trim());
    await prefs.setString('supabaseAnonKey', _supabaseKeyCtrl.text.trim());

    deviceNameVar = name;
    cloudEnabled = _cloudEnabled;

    // Re-configure cloud if enabled
    if (_cloudEnabled &&
        _supabaseUrlCtrl.text.isNotEmpty &&
        _supabaseKeyCtrl.text.isNotEmpty) {
      cloudRepo.configure(
          _supabaseUrlCtrl.text.trim(), _supabaseKeyCtrl.text.trim());
    } else {
      cloudRepo.reset();
    }

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Settings saved!')));
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // --- Device name ---
            const Text(
              'Device Name',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'A unique name for this device (e.g. "My Phone"). '
              'This identifies where you left off across your devices.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _deviceNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Device Name',
                hintText: 'e.g. My Phone',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.devices),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // --- Cloud sync toggle ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cloud Sync (Optional)',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Sync positions & notes across devices\nvia your own Supabase project.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                Switch(
                  value: _cloudEnabled,
                  activeColor: kPrimaryColor,
                  onChanged: (v) => setState(() => _cloudEnabled = v),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: _cloudEnabled
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _supabaseUrlCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Supabase Project URL',
                            hintText: 'https://xxxx.supabase.co',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.cloud),
                          ),
                          validator: (v) {
                            if (!_cloudEnabled) return null;
                            if (v == null || v.trim().isEmpty) {
                              return 'Required when cloud sync is enabled';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _supabaseKeyCtrl,
                          obscureText: !_showKey,
                          decoration: InputDecoration(
                            labelText: 'Supabase Anon Key',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.key),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showKey
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () =>
                                  setState(() => _showKey = !_showKey),
                            ),
                          ),
                          validator: (v) {
                            if (!_cloudEnabled) return null;
                            if (v == null || v.trim().isEmpty) {
                              return 'Required when cloud sync is enabled';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Card(
                          elevation: 0,
                          color: Colors.blue.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text('Supabase Setup Instructions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const SelectableText('1. Create a project at supabase.com\n'
                                    '2. Go to SQL Editor and run this exact query to create your databases:',
                                    style: TextStyle(fontSize: 13)),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const SelectableText(
                                    'CREATE TABLE notes (\n'
                                    '  id bigint generated by default as identity primary key,\n'
                                    '  book_id text,\n'
                                    '  chapter_index int,\n'
                                    '  position_seconds float8,\n'
                                    '  device_name text,\n'
                                    '  text text,\n'
                                    '  created_at timestamptz\n'
                                    ');\n\n'
                                    'CREATE TABLE device_positions (\n'
                                    '  book_id text,\n'
                                    '  device_name text,\n'
                                    '  chapter_index int,\n'
                                    '  position_seconds float8,\n'
                                    '  updated_at timestamptz,\n'
                                    '  primary key (book_id, device_name)\n'
                                    ');',
                                    style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.greenAccent),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const SelectableText('3. Go to API settings to get the Project URL and anon key.\n'
                                    'Note: Disable Row Level Security (RLS) on both tables since this is a private database.',
                                    style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 40),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save Settings'),
                onPressed: _saving ? null : _save,
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'v2.0.1+4',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
