import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// Admin screen for WiFi provisioning and advanced settings
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String? selectedAhuId;
  final _primarySsidController = TextEditingController();
  final _primaryPassController = TextEditingController();
  final _secondarySsidController = TextEditingController();
  final _secondaryPassController = TextEditingController();
  final _brokerHostController = TextEditingController();
  final _brokerPortController = TextEditingController(text: '1883');

  @override
  void dispose() {
    _primarySsidController.dispose();
    _primaryPassController.dispose();
    _secondarySsidController.dispose();
    _secondaryPassController.dispose();
    _brokerHostController.dispose();
    _brokerPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF1E293B),
                    const Color(0xFF334155),
                  ]
                : [
                    Colors.white,
                    Colors.blue.shade50,
                    Colors.blue.shade100,
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar with back button and logout
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Back button
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Back',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Admin Settings',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: 28,
                        ),
                      ),
                    ),
                    // Logout button
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.logout_rounded),
                        onPressed: () {
                          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                        },
                        tooltip: 'Logout',
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: Consumer<AppProvider>(
                  builder: (context, provider, child) {
                    final ahus = provider.ahuUnits;

                    if (ahus.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // ALMED Logo
                            Container(
                              constraints: const BoxConstraints(maxWidth: 200),
                              child: Opacity(
                                opacity: 0.3,
                                child: Image.asset(
                                  isDark 
                                      ? 'assets/images/logo_light.png'
                                      : 'assets/images/logo_dark.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.air_rounded,
                                      size: 80,
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No AHU units available',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // AHU selection
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                              ),
                            ),
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select AHU Unit',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: selectedAhuId,
                                  decoration: InputDecoration(
                                    labelText: 'AHU Unit',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Image.asset(
                                        isDark 
                                            ? 'assets/images/logo_light.png'
                                            : 'assets/images/logo_dark.png',
                                        width: 24,
                                        height: 24,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Icon(Icons.air);
                                        },
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surface,
                                  ),
                                  items: ahus.map((ahu) {
                                    return DropdownMenuItem(
                                      value: ahu.id,
                                      child: Text(ahu.name),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedAhuId = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (selectedAhuId != null) ...[
                            // WiFi Provisioning
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                                ),
                              ),
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.wifi, color: Theme.of(context).colorScheme.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                        'WiFi Provisioning',
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  // Primary WiFi
                                  Text(
                                    'Primary WiFi (Pi Hotspot)',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _primarySsidController,
                                    decoration: InputDecoration(
                                      labelText: 'SSID',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      prefixIcon: const Icon(Icons.wifi),
                                      filled: true,
                                      fillColor: Theme.of(context).colorScheme.surface,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _primaryPassController,
                                    obscureText: true,
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      prefixIcon: const Icon(Icons.lock),
                                      filled: true,
                                      fillColor: Theme.of(context).colorScheme.surface,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Secondary WiFi
                                  Text(
                                    'Secondary WiFi (Hospital Network)',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _secondarySsidController,
                                    decoration: InputDecoration(
                                      labelText: 'SSID',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      prefixIcon: const Icon(Icons.wifi),
                                      filled: true,
                                      fillColor: Theme.of(context).colorScheme.surface,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _secondaryPassController,
                                    obscureText: true,
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      prefixIcon: const Icon(Icons.lock),
                                      filled: true,
                                      fillColor: Theme.of(context).colorScheme.surface,
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _provisionWifi(provider),
                                      icon: const Icon(Icons.send_rounded),
                                      label: const Text('Provision WiFi'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Broker Provisioning
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                                ),
                              ),
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.dns, color: AppTheme.success),
                                      const SizedBox(width: 8),
                                      Text(
                                        'MQTT Broker Settings',
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  TextField(
                                    controller: _brokerHostController,
                                    decoration: InputDecoration(
                                      labelText: 'Broker Host',
                                      hintText: 'e.g., 10.42.0.1 or mqtt-broker.local',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      prefixIcon: const Icon(Icons.computer),
                                      filled: true,
                                      fillColor: Theme.of(context).colorScheme.surface,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _brokerPortController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Port',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      prefixIcon: const Icon(Icons.numbers),
                                      filled: true,
                                      fillColor: Theme.of(context).colorScheme.surface,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _provisionBroker(provider),
                                      icon: const Icon(Icons.send_rounded),
                                      label: const Text('Provision Broker'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.success,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _provisionWifi(AppProvider provider) {
    if (selectedAhuId == null) return;

    final primarySsid = _primarySsidController.text.trim();
    final primaryPass = _primaryPassController.text.trim();
    final secondarySsid = _secondarySsidController.text.trim();
    final secondaryPass = _secondaryPassController.text.trim();

    if (primarySsid.isEmpty && secondarySsid.isEmpty) {
      _showError('Please enter at least one WiFi network');
      return;
    }

    provider.provisionWifi(
      selectedAhuId!,
      primarySsid: primarySsid.isNotEmpty ? primarySsid : null,
      primaryPass: primaryPass.isNotEmpty ? primaryPass : null,
      secondarySsid: secondarySsid.isNotEmpty ? secondarySsid : null,
      secondaryPass: secondaryPass.isNotEmpty ? secondaryPass : null,
    );

    _showSuccess('WiFi credentials sent to AHU');
  }

  void _provisionBroker(AppProvider provider) {
    if (selectedAhuId == null) return;

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

    provider.provisionBroker(selectedAhuId!, host, port);

    _showSuccess('Broker settings sent to AHU');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}


