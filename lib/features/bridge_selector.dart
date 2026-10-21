import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../design/povad_components.dart';
import '../design/povad_theme.dart';
import '../domain/bridge_fleet.dart';
import '../domain/bridge_profiles.dart';
import '../l10n/generated/app_localizations.dart';
import 'overview_page.dart';

String bridgeLabel(BridgeProfile profile, AppLocalizations l) =>
    profile.name.isEmpty ? l.bridgeDefaultName(profile.number) : profile.name;

class BridgeSelector extends StatelessWidget {
  const BridgeSelector({
    super.key,
    required this.connections,
    required this.selectedId,
    required this.enabled,
    required this.onSelected,
    required this.onAdd,
    required this.onEdit,
  });
  final List<BridgeConnection> connections;
  final String selectedId;
  final bool enabled;
  final ValueChanged<String> onSelected;
  final VoidCallback onAdd, onEdit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = paletteOf(context);
    final selected = connections.firstWhere((c) => c.id == selectedId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: l.bridgeChoose,
              child: shad.Select<String>(
                key: const ValueKey('bridge-selector'),
                value: selectedId,
                constraints: const BoxConstraints(minHeight: 48),
                enabled: enabled,
                onChanged: enabled
                    ? (id) {
                        if (id != null) onSelected(id);
                      }
                    : null,
                theme: const shad.SelectTheme(
                  adaptiveOverlay: false,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                itemBuilder: (context, id) => Text(
                  bridgeLabel(
                    connections.firstWhere((c) => c.id == id).profile,
                    l,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                popup: (context) => shad.SelectPopup<String>(
                  items: shad.SelectItemList(
                    children: [
                      for (final entry in connections)
                        shad.SelectItemButton<String>(
                          value: entry.id,
                          child: SizedBox(
                            width: 220,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bridgeLabel(entry.profile, l),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${entry.profile.settings.serialPort.isEmpty ? l.serialValue : entry.profile.settings.serialPort} · ${StateCopy.of(entry.state, l).badge}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          ToolbarIconButton(
            key: const ValueKey('bridge-add'),
            icon: shad.LucideIcons.plus,
            label: l.bridgeAdd,
            quiet: true,
            onPressed: enabled ? onAdd : null,
          ),
          ToolbarIconButton(
            key: const ValueKey('bridge-edit'),
            icon: shad.LucideIcons.ellipsis,
            label: l.bridgeEdit,
            quiet: true,
            onPressed: enabled && !selected.active ? onEdit : null,
          ),
        ],
      ),
    );
  }
}

Future<({String name, bool remove})?> showBridgeEditor(
  BuildContext context, {
  required BridgeProfile profile,
  required bool canRemove,
  required bool enabled,
}) async {
  final l = AppLocalizations.of(context)!;
  return showGeneralDialog<({String name, bool remove})>(
    context: context,
    barrierDismissible: true,
    barrierLabel: l.cancel,
    barrierColor: const Color(0x59000000),
    pageBuilder: (context, _, _) =>
        _BridgeEditor(profile: profile, canRemove: canRemove, enabled: enabled),
  );
}

class _BridgeEditor extends StatefulWidget {
  const _BridgeEditor({
    required this.profile,
    required this.canRemove,
    required this.enabled,
  });
  final BridgeProfile profile;
  final bool canRemove, enabled;
  @override
  State<_BridgeEditor> createState() => _BridgeEditorState();
}

class _BridgeEditorState extends State<_BridgeEditor> {
  late final TextEditingController controller = TextEditingController(
    text: widget.profile.name,
  );
  bool confirmRemove = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: shad.Card(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    confirmRemove ? l.bridgeRemoveTitle : l.bridgeEdit,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (confirmRemove)
                    Text(
                      l.bridgeRemoveDescription(bridgeLabel(widget.profile, l)),
                    )
                  else
                    shad.TextField(
                      key: const ValueKey('bridge-name-field'),
                      controller: controller,
                      maxLength: 40,
                      placeholder: Text(
                        l.bridgeDefaultName(widget.profile.number),
                      ),
                      enabled: widget.enabled,
                    ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      if (confirmRemove) ...[
                        shad.GhostButton(
                          onPressed: () =>
                              setState(() => confirmRemove = false),
                          child: Text(l.cancel),
                        ),
                        shad.DestructiveButton(
                          onPressed: () => Navigator.pop(context, (
                            name: controller.text.trim(),
                            remove: true,
                          )),
                          child: Text(l.bridgeRemove),
                        ),
                      ] else ...[
                        if (widget.canRemove)
                          shad.GhostButton(
                            onPressed: widget.enabled
                                ? () => setState(() => confirmRemove = true)
                                : null,
                            child: Text(l.bridgeRemove),
                          ),
                        shad.GhostButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l.cancel),
                        ),
                        shad.PrimaryButton(
                          onPressed: widget.enabled
                              ? () => Navigator.pop(context, (
                                  name: controller.text.trim(),
                                  remove: false,
                                ))
                              : null,
                          child: Text(l.bridgeSave),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
