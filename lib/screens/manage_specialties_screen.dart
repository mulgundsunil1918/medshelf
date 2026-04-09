import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/medical_specialties.dart';
import '../services/onboarding_service.dart';
import '../services/topic_service.dart';
import '../utils/app_colors.dart';

class ManageSpecialtiesScreen extends StatefulWidget {
  const ManageSpecialtiesScreen({super.key});

  @override
  State<ManageSpecialtiesScreen> createState() =>
      _ManageSpecialtiesScreenState();
}

class _ManageSpecialtiesScreenState extends State<ManageSpecialtiesScreen> {
  final Set<String> _selected = {};
  Set<String> _originalSelected = {};
  bool _loading = true;
  bool _saving = false;

  final _specialtyKeys = medicalSpecialties.keys.toList();

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await OnboardingService.instance.getSelectedSpecialties();
    // Match saved names back to keys
    for (final key in _specialtyKeys) {
      if (saved.contains(extractName(key))) {
        _selected.add(key);
      }
    }
    _originalSelected = Set.from(_selected);
    if (mounted) setState(() => _loading = false);
  }

  bool get _hasChanges {
    if (_selected.length != _originalSelected.length) return true;
    return _selected.any((k) => !_originalSelected.contains(k));
  }

  Future<void> _saveChanges() async {
    setState(() => _saving = true);

    final ts = Provider.of<TopicService>(context, listen: false);

    // Find newly added specialties (in _selected but not in _original)
    final added = _selected.difference(_originalSelected);

    for (final key in added) {
      final specialty = await ts.addTopic(
        name: extractName(key),
        emoji: extractEmoji(key),
        parentId: null,
      );
      final topics = medicalSpecialties[key] ?? [];
      for (final topicKey in topics) {
        await ts.addTopic(
          name: extractName(topicKey),
          emoji: extractEmoji(topicKey),
          parentId: specialty.id,
        );
      }
    }

    await OnboardingService.instance.saveSelectedSpecialties(
      _selected.map(extractName).toList(),
    );

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Specialties updated!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true); // signal refresh
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final allSelected = _selected.length == _specialtyKeys.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Specialties'),
        centerTitle: false,
        actions: [
          if (!_loading)
            TextButton(
              onPressed: () => setState(() {
                if (allSelected) {
                  _selected.clear();
                } else {
                  _selected.addAll(_specialtyKeys);
                }
              }),
              child: Text(allSelected ? 'Clear All' : 'Select All'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Toggle the specialties you work or study in.\nNew ones will be added as folders in your library.',
                    style: tt.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _specialtyKeys.length,
                    itemBuilder: (context, i) {
                      final key = _specialtyKeys[i];
                      final name = extractName(key);
                      final emoji = extractEmoji(key);
                      final topicCount =
                          medicalSpecialties[key]?.length ?? 0;
                      final isSelected = _selected.contains(key);
                      final wasOriginal =
                          _originalSelected.contains(key);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _SpecialtyCard(
                          emoji: emoji,
                          name: name,
                          topicCount: topicCount,
                          isSelected: isSelected,
                          isNew: isSelected && !wasOriginal,
                          onTap: () => setState(() {
                            if (isSelected) {
                              _selected.remove(key);
                            } else {
                              _selected.add(key);
                            }
                          }),
                          cs: cs,
                          tt: tt,
                        ),
                      );
                    },
                  ),
                ),
                _SaveBar(
                  selectedCount: _selected.length,
                  hasChanges: _hasChanges,
                  saving: _saving,
                  onSave: _saveChanges,
                  cs: cs,
                ),
              ],
            ),
    );
  }
}

// ─── Specialty Card ───────────────────────────────────────────────────────────

class _SpecialtyCard extends StatelessWidget {
  const _SpecialtyCard({
    required this.emoji,
    required this.name,
    required this.topicCount,
    required this.isSelected,
    required this.isNew,
    required this.onTap,
    required this.cs,
    required this.tt,
  });

  final String emoji;
  final String name;
  final int topicCount;
  final bool isSelected;
  final bool isNew;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: isSelected
            ? cs.primaryContainer.withAlpha(80)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? cs.primary : cs.outline.withAlpha(60),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected
                ? cs.primary.withAlpha(30)
                : cs.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 26)),
        ),
        title: Row(
          children: [
            Text(name,
                style:
                    tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            if (isNew) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.coral.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'NEW',
                  style: tt.labelSmall?.copyWith(
                    color: AppColors.coral,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text('$topicCount topics',
            style:
                tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        trailing: isSelected
            ? CircleAvatar(
                radius: 14,
                backgroundColor: cs.primary,
                child: const Icon(Icons.check_rounded,
                    size: 16, color: Colors.white),
              )
            : CircleAvatar(
                radius: 14,
                backgroundColor: cs.surfaceContainerHighest,
                child: Icon(Icons.circle_outlined,
                    size: 16, color: cs.outline),
              ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }
}

// ─── Save Bar ─────────────────────────────────────────────────────────────────

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.selectedCount,
    required this.hasChanges,
    required this.saving,
    required this.onSave,
    required this.cs,
  });

  final int selectedCount;
  final bool hasChanges;
  final bool saving;
  final VoidCallback onSave;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$selectedCount specialt${selectedCount == 1 ? 'y' : 'ies'} selected',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: (hasChanges && !saving) ? onSave : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save Changes',
                    style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }
}
