import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// Admin screen for WiFi provisioning, broker settings, and motor timings
class AdminScreen extends StatefulWidget {
  final String deviceId;

  const AdminScreen({super.key, required this.deviceId});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _primarySsidController = TextEditingController();
  final _primaryPassController = TextEditingController();
  final _secondarySsidController = TextEditingController();
  final _secondaryPassController = TextEditingController();
  final _brokerHostController = TextEditingController();
  final _brokerPortController = TextEditingController(text: '1883');
  
  // Motor timing controllers
  final _m1StartController = TextEditingController(text: '10');
  final _m1PostController = TextEditingController(text: '10');
  final _m2IntervalController = TextEditingController(text: '30');
  final _m2RunController = TextEditingController(text: '10');
  final _m2DelayController = TextEditingController(text: '5');

  @override
  void dispose() {
    _primarySsidController.dispose();
    _primaryPassController.dispose();
    _secondarySsidController.dispose();
    _secondaryPassController.dispose();
    _brokerHostController.dispose();
    _brokerPortController.dispose();
    _m1StartController.dispose();
    _m1PostController.dispose();
    _m2IntervalController.dispose();
    _m2RunController.dispose();
    _m2DelayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppTheme.darkBackground,
                    AppTheme.darkSurface,
                    const Color(0xFF334155),
                  ]
                : [
                    Colors.white,
                    Colors.blue.shade50,
                    Colors.blue.shade100,
                  ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // WiFi Provisioning
              _SectionCard(
                title: 'WiFi Provisioning',
                icon: Icons.wifi,
                iconColor: AppTheme.info,
                children: [
                  const Text(
                    'Primary WiFi (Pi Hotspot)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _primarySsidController,
                    decoration: const InputDecoration(
                      labelText: 'SSID',
                      prefixIcon: Icon(Icons.wifi),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _primaryPassController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Secondary WiFi (Hospital Network)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _secondarySsidController,
                    decoration: const InputDecoration(
                      labelText: 'SSID',
                      prefixIcon: Icon(Icons.wifi),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _secondaryPassController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _provisionWifi,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Provision WiFi'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Broker Provisioning
              _SectionCard(
                title: 'MQTT Broker Settings',
                icon: Icons.dns,
                iconColor: AppTheme.success,
                children: [
                  TextField(
                    controller: _brokerHostController,
                    decoration: const InputDecoration(
                      labelText: 'Broker Host',
                      hintText: 'e.g., 10.42.0.1 or mqtt-broker.local',
                      prefixIcon: Icon(Icons.computer),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _brokerPortController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      prefixIcon: Icon(Icons.numbers),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _provisionBroker,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Provision Broker'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Motor Timing Configuration
              _SectionCard(
                title: 'Motor Timing Configuration',
                icon: Icons.timer,
                iconColor: AppTheme.info,
                children: [
                  TextField(
                    controller: _m1StartController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Motor-1 Start Run Time (seconds)',
                      helperText: 'Duration Motor-1 runs after system starts',
                      prefixIcon: Icon(Icons.play_circle),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _m1PostController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Motor-1 Post Run Time (seconds)',
                      helperText: 'Duration Motor-1 runs during shutdown drain',
                      prefixIcon: Icon(Icons.stop_circle),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _m2IntervalController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Motor-2 Interval (seconds)',
                      helperText: 'Time between Motor-2 filter clean cycles',
                      prefixIcon: Icon(Icons.refresh),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _m2RunController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Motor-2 Run Time (seconds)',
                      helperText: 'Duration Motor-2 runs each cycle',
                      prefixIcon: Icon(Icons.schedule),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _m2DelayController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Motor-2 Delay After M1 (seconds)',
                      helperText: 'Delay before Motor-2 starts after Motor-1 stops',
                      prefixIcon: Icon(Icons.hourglass_empty),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _resetMotorTimings,
                          icon: const Icon(Icons.restore),
                          label: const Text('Reset to Defaults'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _provisionMotorTimings,
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Save Timings'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _provisionWifi() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    final primarySsid = _primarySsidController.text.trim();
    final primaryPass = _primaryPassController.text.trim();
    final secondarySsid = _secondarySsidController.text.trim();
    final secondaryPass = _secondaryPassController.text.trim();

    if (primarySsid.isEmpty && secondarySsid.isEmpty) {
      _showError('Please enter at least one WiFi network');
      return;
    }

    // Send WiFi provisioning command via API
    final command = {
      'type': 'provision_wifi',
      'primary': primarySsid.isNotEmpty
          ? {'ssid': primarySsid, 'pass': primaryPass}
          : null,
      'secondary': secondarySsid.isNotEmpty
          ? {'ssid': secondarySsid, 'pass': secondaryPass}
          : null,
    };

    provider.sendCommand(widget.deviceId, command);
    _showSuccess('WiFi credentials sent to AHU');
  }

  void _provisionBroker() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    final host = _brokerHostController.text.trim();
    final portStr = _brokerPortController.text.trim();

    if (host.isEmpty) {
      _showError('Please enter broker host');
      return;
    }

    final port = int.tryParse(portStr);
    if (port == null || port <= 0 || port > 65535) {
      _showError('Please enter a valid port number');
      return;
    }

    final command = {
      'type': 'provision_broker',
      'host': host,
      'port': port,
    };

    provider.sendCommand(widget.deviceId, command);
    _showSuccess('Broker settings sent to AHU');
  }

  void _provisionMotorTimings() {
    final provider = Provider.of<AppProvider>(context, listen: false);

    final m1Start = int.tryParse(_m1StartController.text);
    final m1Post = int.tryParse(_m1PostController.text);
    final m2Interval = int.tryParse(_m2IntervalController.text);
    final m2Run = int.tryParse(_m2RunController.text);
    final m2Delay = int.tryParse(_m2DelayController.text);

    if (m1Start == null || m1Post == null || m2Interval == null ||
        m2Run == null || m2Delay == null) {
      _showError('Please enter valid numbers for all timing fields');
      return;
    }

    if (m1Start < 1 || m1Start > 999 || m1Post < 1 || m1Post > 999 ||
        m2Interval < 1 || m2Interval > 999 || m2Run < 1 || m2Run > 999 ||
        m2Delay < 1 || m2Delay > 999) {
      _showError('Timing values must be between 1 and 999 seconds');
      return;
    }

    final command = {
      'type': 'provision_motor_timings',
      'm1_start': m1Start,
      'm1_post': m1Post,
      'm2_interval': m2Interval,
      'm2_run': m2Run,
      'm2_delay': m2Delay,
    };

    provider.sendCommand(widget.deviceId, command);
    _showSuccess('Motor timings sent to AHU');
  }

  void _resetMotorTimings() {
    setState(() {
      _m1StartController.text = '10';
      _m1PostController.text = '10';
      _m2IntervalController.text = '30';
      _m2RunController.text = '10';
      _m2DelayController.text = '5';
    });
    _showSuccess('Motor timings reset to defaults');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.success,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

