import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/screen_utils.dart';

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
        title: Text(
          'Admin Settings',
          style: TextStyle(
            fontSize: ScreenUtils.getFontSize(context, 18),
            fontWeight: FontWeight.bold,
          ),
        ),
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
                ? const [AppTheme.darkBackground, AppTheme.darkSurface, Color(0xFF334155)]
                : [Colors.white, Colors.blue.shade50, Colors.blue.shade100],
          ),
        ),
        child: SingleChildScrollView(
          padding: ScreenUtils.getScreenPadding(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WifiSection(
                  primarySsidController: _primarySsidController,
                  primaryPassController: _primaryPassController,
                  secondarySsidController: _secondarySsidController,
                  secondaryPassController: _secondaryPassController,
                  onProvision: _provisionWifi,
                ),
                SizedBox(height: ScreenUtils.getSpacing(context, 16)),
                _BrokerSection(
                  brokerHostController: _brokerHostController,
                  brokerPortController: _brokerPortController,
                  onProvision: _provisionBroker,
                ),
                SizedBox(height: ScreenUtils.getSpacing(context, 16)),
                _MotorTimingSection(
                  m1StartController: _m1StartController,
                  m1PostController: _m1PostController,
                  m2IntervalController: _m2IntervalController,
                  m2RunController: _m2RunController,
                  m2DelayController: _m2DelayController,
                  onProvision: _provisionMotorTimings,
                  onReset: _resetMotorTimings,
                ),
                SizedBox(height: ScreenUtils.getSpacing(context, 20)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _provisionWifi() {
    final provider = context.read<AppProvider>();
    
    final primarySsid = _primarySsidController.text.trim();
    final primaryPass = _primaryPassController.text.trim();
    final secondarySsid = _secondarySsidController.text.trim();
    final secondaryPass = _secondaryPassController.text.trim();

    if (primarySsid.isEmpty && secondarySsid.isEmpty) {
      _showError('Please enter at least one WiFi network');
      return;
    }

    final command = {
      'type': 'provision_wifi',
      'primary': primarySsid.isNotEmpty ? {'ssid': primarySsid, 'pass': primaryPass} : null,
      'secondary': secondarySsid.isNotEmpty ? {'ssid': secondarySsid, 'pass': secondaryPass} : null,
    };

    provider.sendCommand(widget.deviceId, command);
    _showSuccess('WiFi credentials sent to AHU');
  }

  void _provisionBroker() {
    final provider = context.read<AppProvider>();
    
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

    final command = {'type': 'provision_broker', 'host': host, 'port': port};
    provider.sendCommand(widget.deviceId, command);
    _showSuccess('Broker settings sent to AHU');
  }

  void _provisionMotorTimings() {
    final provider = context.read<AppProvider>();

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
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

class _WifiSection extends StatelessWidget {
  final TextEditingController primarySsidController;
  final TextEditingController primaryPassController;
  final TextEditingController secondarySsidController;
  final TextEditingController secondaryPassController;
  final VoidCallback onProvision;

  const _WifiSection({
    required this.primarySsidController,
    required this.primaryPassController,
    required this.secondarySsidController,
    required this.secondaryPassController,
    required this.onProvision,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = ScreenUtils.getSpacing(context, 12);

    return _SectionCard(
      title: 'WiFi Provisioning',
      icon: Icons.wifi,
      iconColor: AppTheme.info,
      children: [
        Text(
          'Primary WiFi (Pi Hotspot)',
          style: TextStyle(
            fontSize: ScreenUtils.getFontSize(context, 13),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: spacing),
        _TextField(controller: primarySsidController, label: 'SSID', icon: Icons.wifi),
        SizedBox(height: spacing),
        _TextField(controller: primaryPassController, label: 'Password', icon: Icons.lock, obscure: true),
        SizedBox(height: ScreenUtils.getSpacing(context, 20)),
        Text(
          'Secondary WiFi (Hospital Network)',
          style: TextStyle(
            fontSize: ScreenUtils.getFontSize(context, 13),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: spacing),
        _TextField(controller: secondarySsidController, label: 'SSID', icon: Icons.wifi),
        SizedBox(height: spacing),
        _TextField(controller: secondaryPassController, label: 'Password', icon: Icons.lock, obscure: true),
        SizedBox(height: ScreenUtils.getSpacing(context, 16)),
        SizedBox(
          width: double.infinity,
          height: ScreenUtils.getButtonHeight(context),
          child: ElevatedButton.icon(
            onPressed: onProvision,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Provision WiFi'),
          ),
        ),
      ],
    );
  }
}

class _BrokerSection extends StatelessWidget {
  final TextEditingController brokerHostController;
  final TextEditingController brokerPortController;
  final VoidCallback onProvision;

  const _BrokerSection({
    required this.brokerHostController,
    required this.brokerPortController,
    required this.onProvision,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = ScreenUtils.getSpacing(context, 12);

    return _SectionCard(
      title: 'MQTT Broker Settings',
      icon: Icons.dns,
      iconColor: AppTheme.success,
      children: [
        _TextField(
          controller: brokerHostController,
          label: 'Broker Host',
          icon: Icons.computer,
          hint: 'e.g., 10.42.0.1',
        ),
        SizedBox(height: spacing),
        _TextField(
          controller: brokerPortController,
          label: 'Port',
          icon: Icons.numbers,
          keyboardType: TextInputType.number,
        ),
        SizedBox(height: ScreenUtils.getSpacing(context, 16)),
        SizedBox(
          width: double.infinity,
          height: ScreenUtils.getButtonHeight(context),
          child: ElevatedButton.icon(
            onPressed: onProvision,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Provision Broker'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
          ),
        ),
      ],
    );
  }
}

class _MotorTimingSection extends StatelessWidget {
  final TextEditingController m1StartController;
  final TextEditingController m1PostController;
  final TextEditingController m2IntervalController;
  final TextEditingController m2RunController;
  final TextEditingController m2DelayController;
  final VoidCallback onProvision;
  final VoidCallback onReset;

  const _MotorTimingSection({
    required this.m1StartController,
    required this.m1PostController,
    required this.m2IntervalController,
    required this.m2RunController,
    required this.m2DelayController,
    required this.onProvision,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = ScreenUtils.getSpacing(context, 12);

    return _SectionCard(
      title: 'Motor Timing Configuration',
      icon: Icons.timer,
      iconColor: AppTheme.info,
      children: [
        _TextField(
          controller: m1StartController,
          label: 'Motor-1 Start Run Time (seconds)',
          icon: Icons.play_circle,
          keyboardType: TextInputType.number,
          helper: 'Duration Motor-1 runs after system starts',
        ),
        SizedBox(height: spacing),
        _TextField(
          controller: m1PostController,
          label: 'Motor-1 Post Run Time (seconds)',
          icon: Icons.stop_circle,
          keyboardType: TextInputType.number,
          helper: 'Duration Motor-1 runs during shutdown drain',
        ),
        SizedBox(height: spacing),
        _TextField(
          controller: m2IntervalController,
          label: 'Motor-2 Interval (seconds)',
          icon: Icons.refresh,
          keyboardType: TextInputType.number,
          helper: 'Time between Motor-2 filter clean cycles',
        ),
        SizedBox(height: spacing),
        _TextField(
          controller: m2RunController,
          label: 'Motor-2 Run Time (seconds)',
          icon: Icons.schedule,
          keyboardType: TextInputType.number,
          helper: 'Duration Motor-2 runs each cycle',
        ),
        SizedBox(height: spacing),
        _TextField(
          controller: m2DelayController,
          label: 'Motor-2 Delay After M1 (seconds)',
          icon: Icons.hourglass_empty,
          keyboardType: TextInputType.number,
          helper: 'Delay before Motor-2 starts after Motor-1 stops',
        ),
        SizedBox(height: ScreenUtils.getSpacing(context, 16)),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: ScreenUtils.getButtonHeight(context),
                child: OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.restore, size: 18),
                  label: Text(
                    'Reset',
                    style: TextStyle(fontSize: ScreenUtils.getFontSize(context, 13)),
                  ),
                ),
              ),
            ),
            SizedBox(width: ScreenUtils.getPadding(context, 10)),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: ScreenUtils.getButtonHeight(context),
                child: ElevatedButton.icon(
                  onPressed: onProvision,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    'Save Timings',
                    style: TextStyle(fontSize: ScreenUtils.getFontSize(context, 13)),
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.info),
                ),
              ),
            ),
          ],
        ),
      ],
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
      padding: EdgeInsets.all(ScreenUtils.getPadding(context, 18)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 18)),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: ScreenUtils.getIconSize(context, 22)),
              SizedBox(width: ScreenUtils.getPadding(context, 8)),
              Text(
                title,
                style: TextStyle(
                  fontSize: ScreenUtils.getFontSize(context, 16),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: ScreenUtils.getSpacing(context, 16)),
          ...children,
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;

  const _TextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.hint,
    this.helper,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: ScreenUtils.getFontSize(context, 14)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        prefixIcon: Icon(icon, size: 20),
        contentPadding: EdgeInsets.symmetric(
          horizontal: ScreenUtils.getPadding(context, 14),
          vertical: ScreenUtils.getSpacing(context, 12),
        ),
      ),
    );
  }
}
