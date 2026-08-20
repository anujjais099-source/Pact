import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/pact_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/pact_button.dart';
import '../../core/widgets/pact_loader.dart';
import '../../core/widgets/pact_scaffold.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/services/firebase_service.dart';
import '../../state/providers.dart';

/// One goal, one word if possible. The presets exist because a blank field is
/// where motivation goes to die.
class GoalSetupScreen extends ConsumerStatefulWidget {
  const GoalSetupScreen({super.key, this.isEditing = false});

  final bool isEditing;

  @override
  ConsumerState<GoalSetupScreen> createState() => _GoalSetupScreenState();
}

class _GoalSetupScreenState extends ConsumerState<GoalSetupScreen> {
  static const _presets = [
    ('Gym', Icons.fitness_center_rounded),
    ('Study', Icons.menu_book_rounded),
    ('Reading', Icons.auto_stories_rounded),
    ('Meditation', Icons.self_improvement_rounded),
    ('Running', Icons.directions_run_rounded),
    ('Learning', Icons.lightbulb_outline_rounded),
  ];

  final _controller = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(currentUserProvider).value?.goalName ?? '';
    _controller.text = existing;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final goal = _controller.text.trim();
    final problem = Validators.goal(goal);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(userRepositoryProvider).updateGoal(uid, goal);
      await ref.read(pactAnalyticsProvider).goalSet(goal);
      if (mounted && widget.isEditing) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final selected = _controller.text.trim().toLowerCase();

    return PactScaffold(
      title: widget.isEditing ? 'Change goal' : null,
      leading: widget.isEditing ? const BackButton() : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 72),
          Text(
            widget.isEditing ? 'What are you\nshowing up for?' : 'What will you\ndo every day?',
            style: t.headlineMedium,
          ),
          Gap.h8,
          Text(
            'Your partner sees this. Keep it small enough that a bad day cannot excuse it.',
            style: t.bodyMedium,
          ),
          Gap.h24,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, icon) in _presets)
                _GoalChip(
                  label: label,
                  icon: icon,
                  selected: selected == label.toLowerCase(),
                  onTap: () => setState(() {
                    _controller.text = label;
                    _error = null;
                  }),
                ),
            ],
          ),
          Gap.h24,
          TextField(
            controller: _controller,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Or write your own',
              hintText: 'Practice guitar',
              counterText: '',
            ),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _save(),
          ),
          if (_error != null) ...[
            Gap.h12,
            PactError(message: _error!),
          ],
          const Spacer(),
          if (!widget.isEditing)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      size: 15, color: PactColors.textTertiary),
                  Gap.w8,
                  Expanded(
                    child: Text(
                      'You can change this later, but never mid-streak excuses.',
                      style: t.bodyMedium?.copyWith(
                        fontSize: 12.5,
                        color: PactColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          PactButton(
            label: widget.isEditing ? 'Save goal' : 'Find my partner',
            loading: _saving,
            onPressed: _save,
          ),
          Gap.h16,
        ],
      ),
    );
  }
}

class _GoalChip extends StatelessWidget {
  const _GoalChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? PactColors.violetSoft : PactColors.surfaceRaised,
      borderRadius: Radii.pill,
      child: InkWell(
        borderRadius: Radii.pill,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: Radii.pill,
            border: Border.all(
              color: selected ? PactColors.violet : PactColors.stroke,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? PactColors.violet : PactColors.textSecondary),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? PactColors.violet : PactColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
