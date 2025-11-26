import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/screen_utils.dart';

/// Client Reports Screen - Support ticket submission system
class ClientReportsScreen extends StatefulWidget {
  const ClientReportsScreen({super.key});

  @override
  State<ClientReportsScreen> createState() => _ClientReportsScreenState();
}

class _ClientReportsScreenState extends State<ClientReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _tickets = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTickets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final tickets = await appProvider.getMyTickets();
    if (mounted) {
      setState(() {
        _tickets = tickets;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar
        Container(
          margin: EdgeInsets.all(ScreenUtils.getPadding(context, 16)),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: AppTheme.lightPrimary,
              borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 10)),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
            labelStyle: TextStyle(
              fontSize: ScreenUtils.getFontSize(context, 14),
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'New Report'),
              Tab(text: 'My Tickets'),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _NewTicketForm(onSubmitted: () {
                _loadTickets();
                _tabController.animateTo(1);
              }),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _TicketsList(
                      tickets: _tickets,
                      onRefresh: _loadTickets,
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NewTicketForm extends StatefulWidget {
  final VoidCallback onSubmitted;

  const _NewTicketForm({required this.onSubmitted});

  @override
  State<_NewTicketForm> createState() => _NewTicketFormState();
}

class _NewTicketFormState extends State<_NewTicketForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedAhuId;
  String _priority = 'medium';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final result = await appProvider.createTicket(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      ahuId: _selectedAhuId,
      priority: _priority,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ticket submitted successfully'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(ScreenUtils.getPadding(context, 16)),
        ),
      );
      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedAhuId = null;
        _priority = 'medium';
      });
      widget.onSubmitted();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to submit ticket'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(ScreenUtils.getPadding(context, 16)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AppProvider>().currentUser;
    final ahuIds = user?.assignedAhuIds ?? [];

    return SingleChildScrollView(
      padding: ScreenUtils.getScreenPadding(context),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(ScreenUtils.getPadding(context, 12)),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
                  ),
                  child: Icon(
                    Icons.report_problem_rounded,
                    color: AppTheme.error,
                    size: ScreenUtils.getIconSize(context, 28),
                  ),
                ),
                SizedBox(width: ScreenUtils.getPadding(context, 14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report a Problem',
                        style: TextStyle(
                          fontSize: ScreenUtils.getFontSize(context, 18),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: ScreenUtils.getSpacing(context, 4)),
                      Text(
                        'Describe your issue and we\'ll help resolve it',
                        style: TextStyle(
                          fontSize: ScreenUtils.getFontSize(context, 12),
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 24)),

            // Title field
            Text(
              'Issue Title *',
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 14),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 8)),
            TextFormField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: 'Brief description of the problem',
                prefixIcon: const Icon(Icons.title_rounded, size: 20),
                filled: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 16)),

            // AHU Selection (optional)
            Text(
              'Related AHU (Optional)',
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 14),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 8)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ScreenUtils.getPadding(context, 16),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).inputDecorationTheme.fillColor,
                borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
                border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.3)),
              ),
              child: DropdownButton<String>(
                value: _selectedAhuId,
                isExpanded: true,
                underline: const SizedBox(),
                hint: Text(
                  'Select AHU unit',
                  style: TextStyle(fontSize: ScreenUtils.getFontSize(context, 14)),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ...ahuIds.map((id) => DropdownMenuItem(
                        value: id,
                        child: Text('AHU $id'),
                      )),
                ],
                onChanged: (value) => setState(() => _selectedAhuId = value),
              ),
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 16)),

            // Priority selection
            Text(
              'Priority',
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 14),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 8)),
            Row(
              children: [
                _PriorityChip(
                  label: 'Low',
                  isSelected: _priority == 'low',
                  color: AppTheme.info,
                  onTap: () => setState(() => _priority = 'low'),
                ),
                SizedBox(width: ScreenUtils.getPadding(context, 8)),
                _PriorityChip(
                  label: 'Medium',
                  isSelected: _priority == 'medium',
                  color: AppTheme.warning,
                  onTap: () => setState(() => _priority = 'medium'),
                ),
                SizedBox(width: ScreenUtils.getPadding(context, 8)),
                _PriorityChip(
                  label: 'High',
                  isSelected: _priority == 'high',
                  color: AppTheme.error,
                  onTap: () => setState(() => _priority = 'high'),
                ),
                SizedBox(width: ScreenUtils.getPadding(context, 8)),
                _PriorityChip(
                  label: 'Critical',
                  isSelected: _priority == 'critical',
                  color: const Color(0xFFD32F2F),
                  onTap: () => setState(() => _priority = 'critical'),
                ),
              ],
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 16)),

            // Description field
            Text(
              'Description *',
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 14),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 8)),
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Describe the issue in detail...',
                alignLabelWithHint: true,
                filled: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please describe the issue';
                }
                return null;
              },
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 24)),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: ScreenUtils.getButtonHeight(context),
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitTicket,
                icon: _isSubmitting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_isSubmitting ? 'Submitting...' : 'Submit Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _PriorityChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: ScreenUtils.getPadding(context, 14),
          vertical: ScreenUtils.getPadding(context, 8),
        ),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 10)),
          border: Border.all(color: color, width: isSelected ? 0 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ScreenUtils.getFontSize(context, 12),
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

class _TicketsList extends StatelessWidget {
  final List<Map<String, dynamic>> tickets;
  final VoidCallback onRefresh;

  const _TicketsList({required this.tickets, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              size: ScreenUtils.getIconSize(context, 64),
              color: Colors.grey.shade400,
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 16)),
            Text(
              'No tickets yet',
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 18),
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 8)),
            Text(
              'Submit a report to get started',
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 14),
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: ScreenUtils.getScreenPadding(context),
        itemCount: tickets.length,
        itemBuilder: (context, index) {
          return _TicketCard(ticket: tickets[index]);
        },
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;

  const _TicketCard({required this.ticket});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return AppTheme.success;
      case 'in_progress':
        return AppTheme.warning;
      case 'resolved':
        return AppTheme.info;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return AppTheme.info;
      case 'medium':
        return AppTheme.warning;
      case 'high':
        return AppTheme.error;
      case 'critical':
        return const Color(0xFFD32F2F);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ticket['status'] ?? 'open';
    final priority = ticket['priority'] ?? 'medium';
    final statusColor = _getStatusColor(status);
    final priorityColor = _getPriorityColor(priority);

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: ScreenUtils.getSpacing(context, 12)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 14)),
      ),
      child: Padding(
        padding: EdgeInsets.all(ScreenUtils.getPadding(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket['title'] ?? 'Untitled',
                    style: TextStyle(
                      fontSize: ScreenUtils.getFontSize(context, 16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ScreenUtils.getPadding(context, 10),
                    vertical: ScreenUtils.getPadding(context, 4),
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 8)),
                  ),
                  child: Text(
                    status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: ScreenUtils.getFontSize(context, 10),
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 8)),
            // Meta info
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ScreenUtils.getPadding(context, 8),
                    vertical: ScreenUtils.getPadding(context, 3),
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 6)),
                  ),
                  child: Text(
                    priority.toUpperCase(),
                    style: TextStyle(
                      fontSize: ScreenUtils.getFontSize(context, 9),
                      fontWeight: FontWeight.bold,
                      color: priorityColor,
                    ),
                  ),
                ),
                SizedBox(width: ScreenUtils.getPadding(context, 8)),
                if (ticket['ahu_id'] != null) ...[
                  Icon(Icons.ac_unit, size: 12, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    'AHU ${ticket['ahu_id']}',
                    style: TextStyle(
                      fontSize: ScreenUtils.getFontSize(context, 11),
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(width: ScreenUtils.getPadding(context, 8)),
                ],
                Icon(Icons.schedule, size: 12, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  _formatDate(ticket['created_at']),
                  style: TextStyle(
                    fontSize: ScreenUtils.getFontSize(context, 11),
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 10)),
            // Description
            Text(
              ticket['description'] ?? '',
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 13),
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // Admin response
            if (ticket['admin_response'] != null) ...[
              SizedBox(height: ScreenUtils.getSpacing(context, 12)),
              Container(
                padding: EdgeInsets.all(ScreenUtils.getPadding(context, 12)),
                decoration: BoxDecoration(
                  color: AppTheme.info.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 10)),
                  border: Border(
                    left: BorderSide(color: AppTheme.info, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Response',
                      style: TextStyle(
                        fontSize: ScreenUtils.getFontSize(context, 11),
                        fontWeight: FontWeight.bold,
                        color: AppTheme.info,
                      ),
                    ),
                    SizedBox(height: ScreenUtils.getSpacing(context, 6)),
                    Text(
                      ticket['admin_response'],
                      style: TextStyle(
                        fontSize: ScreenUtils.getFontSize(context, 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
