import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;
import 'package:qr_flutter/qr_flutter.dart';

import '../design/povad_components.dart';
import '../design/povad_theme.dart';
import '../domain/android_usb_host.dart';
import '../domain/client_allowlist.dart';
import '../l10n/generated/app_localizations.dart';

/// Field-level validation shared by the form and the start action.
final class BridgeFieldErrors {
  const BridgeFieldErrors({
    this.serial = false,
    this.baud = false,
    this.tcp = false,
  });

  factory BridgeFieldErrors.of(String serial, String baud, String tcp) {
    final speed = int.tryParse(baud);
    final port = int.tryParse(tcp);
    return BridgeFieldErrors(
      serial: serial.trim().isEmpty,
      baud: speed == null || speed < 300 || speed > 4000000,
      tcp: port == null || port < 1 || port > 65535,
    );
  }

  final bool serial, baud, tcp;
  bool get any => serial || baud || tcp;
}

class BridgeSetupPage extends StatelessWidget {
  const BridgeSetupPage({
    super.key,
    required this.serialPort,
    required this.baud,
    required this.parity,
    required this.tcpPort,
    required this.onSerialPortChanged,
    required this.onBaudChanged,
    required this.onParityChanged,
    required this.onTcpPortChanged,
    required this.allowLan,
    required this.waitNextClient,
    required this.allowedClients,
    this.discoveryUnavailable = false,
    required this.onWaitNextChanged,
    required this.onAllowedClientsChanged,
    required this.onAllowLanChanged,
    required this.lanAddresses,
    required this.copiedEndpoint,
    required this.onRefreshLan,
    required this.onCopyEndpoint,
    required this.showErrors,
    required this.running,
    this.discoveredPorts = const [],
    this.discoverySupported = false,
    this.onRefreshPorts,
    this.usbMode = false,
    this.usbPorts = const [],
    this.usbLoading = false,
    this.usbMessage,
    this.onRefreshUsb,
    this.onUsbPortSelected,
  });

  final String serialPort, baud, parity, tcpPort;
  final ValueChanged<String> onSerialPortChanged;
  final ValueChanged<String> onBaudChanged;
  final ValueChanged<String> onParityChanged;
  final ValueChanged<String> onTcpPortChanged;
  final bool allowLan;
  final bool waitNextClient;
  final String allowedClients;
  final bool discoveryUnavailable;
  final ValueChanged<bool> onWaitNextChanged;
  final ValueChanged<String> onAllowedClientsChanged;
  final ValueChanged<bool> onAllowLanChanged;
  final List<({String name, String address})> lanAddresses;
  final String? copiedEndpoint;
  final VoidCallback onRefreshLan;
  final ValueChanged<String> onCopyEndpoint;

  /// Reveals empty required fields after an attempted start.
  final bool showErrors;
  final bool running;
  final List<String> discoveredPorts;
  final bool discoverySupported;
  final VoidCallback? onRefreshPorts;
  final bool usbMode, usbLoading;
  final List<AndroidUsbPort> usbPorts;
  final String? usbMessage;
  final VoidCallback? onRefreshUsb;
  final ValueChanged<AndroidUsbPort>? onUsbPortSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = paletteOf(context);
    final errors = BridgeFieldErrors.of(serialPort, baud, tcpPort);
    // Show a format error as soon as text is present; an empty required
    // field is flagged only after the operator tries to start.
    final serialError = showErrors && errors.serial;
    final baudError = errors.baud && (showErrors || baud.isNotEmpty);
    final tcpError = errors.tcp && (showErrors || tcpPort.isNotEmpty);

    return PageFrame(
      title: l.bridgeSetupTitle,
      subtitle: usbMode ? l.androidBridgeSetupIntro : l.bridgeSetupIntro,
      children: [
        if (running) ...[
          Callout(icon: shad.LucideIcons.lock, text: l.settingsLocked),
          const SizedBox(height: 18),
        ],
        Section(
          title: l.serialSection,
          icon: shad.LucideIcons.usb,
          padded: true,
          children: [
            if (usbMode)
              _UsbPicker(
                ports: usbPorts,
                selected: serialPort,
                loading: usbLoading,
                message: usbMessage,
                enabled: !running,
                onRefresh: onRefreshUsb,
                onSelected: onUsbPortSelected,
                showError: serialError,
              )
            else ...[
              _FieldLabel(l.serialPortPath),
              _SettingField(
                key: const ValueKey('serial-field'),
                value: serialPort,
                onChanged: onSerialPortChanged,
                enabled: !running,
                placeholder: _serialPlaceholder,
                error: serialError ? l.serialPortRequired : null,
                trailing: discoverySupported
                    ? Semantics(
                        label: l.refreshPorts,
                        button: true,
                        child: shad.GhostButton(
                          onPressed: running ? null : onRefreshPorts,
                          density: shad.ButtonDensity.icon,
                          child: Icon(
                            shad.LucideIcons.refreshCw,
                            size: 15,
                            color: colors.muted,
                          ),
                        ),
                      )
                    : null,
              ),
              if (discoverySupported) ...[
                const SizedBox(height: 12),
                if (discoveredPorts.isEmpty)
                  Text(
                    l.noDetectedPorts,
                    style: TextStyle(fontSize: 12.5, color: colors.muted),
                  )
                else ...[
                  Text(
                    l.detectedPorts,
                    style: TextStyle(fontSize: 12.5, color: colors.muted),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final port in discoveredPorts)
                        _Chip(
                          label: port.replaceFirst('/dev/', ''),
                          selected: port == serialPort,
                          onTap: running
                              ? null
                              : () => onSerialPortChanged(port),
                        ),
                    ],
                  ),
                ],
              ],
            ],
            const SizedBox(height: 20),
            _BaudSelector(
              value: baud,
              onChanged: onBaudChanged,
              enabled: !running,
              error: baudError ? l.baudInvalid : null,
            ),
            const SizedBox(height: 16),
            _ParitySelector(
              value: parity,
              onChanged: onParityChanged,
              enabled: !running,
            ),
          ],
        ),
        Section(
          title: l.tcpListener,
          icon: shad.LucideIcons.network,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FieldLabel(l.tcpPortNumber),
                  _SettingField(
                    key: const ValueKey('tcp-field'),
                    value: tcpPort,
                    onChanged: onTcpPortChanged,
                    enabled: !running,
                    numeric: true,
                    error: tcpError ? l.tcpPortInvalid : null,
                    hint: l.tcpPortHint,
                  ),
                ],
              ),
            ),
            SectionRow(
              label: l.waitNextClient,
              description: l.waitNextDescription,
              stackBelow: 0,
              trailing: shad.Switch(
                key: const ValueKey('wait-next-client'),
                value: waitNextClient,
                onChanged: running ? null : onWaitNextChanged,
              ),
            ),
            SectionRow(
              label: l.lanAccessTitle,
              description: allowLan ? null : l.loopbackNote,
              stackBelow: 0,
              trailing: shad.Switch(
                key: const ValueKey('allow-lan'),
                value: allowLan,
                onChanged: running ? null : onAllowLanChanged,
              ),
              below: allowLan
                  ? Callout(
                      icon: shad.LucideIcons.triangleAlert,
                      tone: CalloutTone.warning,
                      text: l.lanAccessRisk,
                    )
                  : null,
            ),
            if (allowLan) ...[
              if (discoveryUnavailable)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Callout(
                    icon: shad.LucideIcons.triangleAlert,
                    tone: CalloutTone.warning,
                    text: l.discoveryUnavailable,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FieldLabel(l.allowedClients),
                    _SettingField(
                      key: const ValueKey('allowed-clients-field'),
                      value: allowedClients,
                      onChanged: onAllowedClientsChanged,
                      enabled: !running,
                      placeholder: '192.168.1.20, 192.168.1.21',
                      error: parseClientAllowlist(allowedClients) == null
                          ? l.allowedClientsInvalid
                          : null,
                      hint: l.allowedClientsHint,
                    ),
                  ],
                ),
              ),
              SectionRow(
                label: l.lanAddressesTitle,
                stackBelow: 0,
                trailing: Semantics(
                  label: l.refreshAddresses,
                  button: true,
                  child: shad.GhostButton(
                    onPressed: onRefreshLan,
                    density: shad.ButtonDensity.icon,
                    child: Icon(
                      shad.LucideIcons.refreshCw,
                      size: 15,
                      color: colors.muted,
                    ),
                  ),
                ),
                below: lanAddresses.isEmpty
                    ? Text(
                        l.lanAddressUnavailable,
                        style: TextStyle(color: colors.muted, fontSize: 13),
                      )
                    : Column(
                        children: [
                          for (final address in lanAddresses)
                            _AddressRow(
                              name: address.name,
                              endpoint: '${address.address}:$tcpPort',
                              copied:
                                  copiedEndpoint ==
                                  '${address.address}:$tcpPort',
                              copyLabel: l.copyEndpoint,
                              copiedLabel: l.copiedEndpoint,
                              onCopy: onCopyEndpoint,
                            ),
                        ],
                      ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  static String get _serialPlaceholder {
    if (kIsWeb) return '';
    if (Platform.isWindows) return 'COM3';
    if (Platform.isLinux) return '/dev/ttyUSB0';
    return '/dev/cu.usbserial-…';
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: paletteOf(context).foreground,
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    final child = Text(
      label,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? colors.primary : colors.foreground,
      ),
    );
    return Semantics(
      selected: selected,
      child: selected
          ? shad.OutlineButton(
              onPressed: onTap,
              density: shad.ButtonDensity.dense,
              leading: Icon(
                shad.LucideIcons.check,
                size: 13,
                color: colors.primary,
              ),
              child: child,
            )
          : shad.OutlineButton(
              onPressed: onTap,
              density: shad.ButtonDensity.dense,
              child: child,
            ),
    );
  }
}

class _UsbPicker extends StatelessWidget {
  const _UsbPicker({
    required this.ports,
    required this.selected,
    required this.loading,
    required this.message,
    required this.enabled,
    required this.onRefresh,
    required this.onSelected,
    required this.showError,
  });

  final List<AndroidUsbPort> ports;
  final String selected;
  final bool loading, enabled, showError;
  final String? message;
  final VoidCallback? onRefresh;
  final ValueChanged<AndroidUsbPort>? onSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _FieldLabel(l.usbPortsTitle)),
            shad.OutlineButton(
              onPressed: loading || !enabled ? null : onRefresh,
              density: shad.ButtonDensity.dense,
              leading: const Icon(shad.LucideIcons.refreshCw, size: 14),
              child: Text(l.scanUsbDevices),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (message != null)
          Callout(
            icon: shad.LucideIcons.circleAlert,
            tone: CalloutTone.error,
            text: message!,
          )
        else if (loading && ports.isEmpty)
          Text(l.scanningUsbDevices, style: TextStyle(color: colors.muted))
        else if (ports.isEmpty)
          Text(
            l.noUsbDevices,
            style: TextStyle(
              color: showError ? colors.error : colors.muted,
              fontSize: 13,
            ),
          ),
        for (final port in ports)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _UsbRow(
              label: port.labelIn(ports),
              selected: port.nativeSelection == selected,
              onTap: !enabled || loading ? null : () => onSelected?.call(port),
            ),
          ),
      ],
    );
  }
}

class _UsbRow extends StatelessWidget {
  const _UsbRow({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: shad.OutlineButton(
        onPressed: onTap,
        alignment: Alignment.centerLeft,
        leading: Icon(
          selected ? shad.LucideIcons.circleCheck : shad.LucideIcons.usb,
          size: 16,
          color: selected ? colors.primary : colors.muted,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? colors.primary : colors.foreground,
          ),
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.name,
    required this.endpoint,
    required this.copied,
    required this.copyLabel,
    required this.copiedLabel,
    required this.onCopy,
  });

  final String name, endpoint, copyLabel, copiedLabel;
  final bool copied;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(
          color: colors.subtle,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    endpoint,
                    style: TextStyle(
                      color: colors.foreground,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    name,
                    style: TextStyle(color: colors.muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            shad.GhostButton(
              key: ValueKey('qr-$endpoint'),
              onPressed: () => showGeneralDialog<void>(
                context: context,
                barrierDismissible: true,
                barrierLabel: l.close,
                barrierColor: const Color(0x59000000),
                pageBuilder: (dialogContext, _, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: shad.AlertDialog(
                        title: Text(l.scanBridgeAddress),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            QrImageView(
                              data: 'povad-bridge://$endpoint',
                              size: 208,
                              padding: const EdgeInsets.all(8),
                              backgroundColor: const Color(0xFFFFFFFF),
                              eyeStyle: const QrEyeStyle(
                                color: Color(0xFF18181B),
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                color: Color(0xFF18181B),
                              ),
                              semanticsLabel: l.scanBridgeAddress,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'povad-bridge://$endpoint',
                              style: TextStyle(color: colors.muted),
                            ),
                          ],
                        ),
                        actions: [
                          shad.GhostButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text(l.close),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              density: shad.ButtonDensity.icon,
              child: Icon(
                shad.LucideIcons.qrCode,
                size: 17,
                color: colors.muted,
              ),
            ),
            shad.GhostButton(
              onPressed: () => onCopy(endpoint),
              density: shad.ButtonDensity.dense,
              leading: Icon(
                copied ? shad.LucideIcons.check : shad.LucideIcons.copy,
                size: 14,
                color: copied ? colors.primary : colors.muted,
              ),
              child: Text(copied ? copiedLabel : copyLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParitySelector extends StatelessWidget {
  const _ParitySelector({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    String label(String parity) => switch (parity) {
      'E' => l.parityEven,
      'O' => l.parityOdd,
      _ => l.parityNone,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(l.parity),
        shad.Select<String>(
          key: const ValueKey('parity-select'),
          value: value,
          onChanged: enabled
              ? (selected) {
                  if (selected != null) onChanged(selected);
                }
              : null,
          enabled: enabled,
          theme: const shad.SelectTheme(adaptiveOverlay: false),
          itemBuilder: (context, selected) => Text(label(selected)),
          popup: (context) => shad.SelectPopup<String>(
            items: shad.SelectItemList(
              children: [
                for (final parity in const ['N', 'E', 'O'])
                  shad.SelectItemButton<String>(
                    value: parity,
                    child: Text(label(parity)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BaudSelector extends StatelessWidget {
  const _BaudSelector({
    required this.value,
    required this.onChanged,
    required this.enabled,
    this.error,
  });

  static const rates = [
    '1200',
    '2400',
    '4800',
    '9600',
    '19200',
    '38400',
    '57600',
    '115200',
    '230400',
    '460800',
    '921600',
  ];
  static const custom = 'custom';

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isCustom = !rates.contains(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(l.baudRate),
        shad.Select<String>(
          key: const ValueKey('baud-select'),
          value: isCustom ? custom : value,
          onChanged: enabled
              ? (selected) =>
                    onChanged(selected == custom ? '' : selected ?? value)
              : null,
          enabled: enabled,
          theme: const shad.SelectTheme(adaptiveOverlay: false),
          itemBuilder: (context, selected) =>
              Text(selected == custom ? l.customBaudRate : selected),
          popup: (context) => shad.SelectPopup<String>(
            items: shad.SelectItemList(
              children: [
                for (final rate in rates)
                  shad.SelectItemButton<String>(value: rate, child: Text(rate)),
                shad.SelectItemButton<String>(
                  value: custom,
                  child: Text(l.customBaudRate),
                ),
              ],
            ),
          ),
        ),
        if (isCustom) ...[
          const SizedBox(height: 10),
          _SettingField(
            key: const ValueKey('custom-baud-field'),
            value: value,
            onChanged: onChanged,
            enabled: enabled,
            numeric: true,
            placeholder: l.customBaudRate,
            error: error,
          ),
        ] else if (error != null) ...[
          const SizedBox(height: 6),
          _FieldError(error!),
        ],
      ],
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            shad.LucideIcons.circleAlert,
            size: 13,
            color: colors.error,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: colors.error, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

/// A text field that follows external value changes, such as a picked port,
/// without losing the caret while the operator types.
class _SettingField extends StatefulWidget {
  const _SettingField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.enabled,
    this.numeric = false,
    this.placeholder,
    this.error,
    this.hint,
    this.trailing,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled, numeric;
  final String? placeholder, error, hint;
  final Widget? trailing;

  @override
  State<_SettingField> createState() => _SettingFieldState();
}

class _SettingFieldState extends State<_SettingField> {
  late final controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _SettingField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != controller.text) {
      // Listeners of the controller must not rebuild during this build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.value == controller.text) return;
        controller.value = TextEditingValue(
          text: widget.value,
          selection: TextSelection.collapsed(offset: widget.value.length),
        );
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    final field = shad.TextField(
      controller: controller,
      onChanged: widget.onChanged,
      enabled: widget.enabled,
      keyboardType: widget.numeric ? TextInputType.number : null,
      inputFormatters: widget.numeric ? digitsOnly : null,
      autocorrect: false,
      enableSuggestions: false,
      placeholder: widget.placeholder == null
          ? null
          : Text(widget.placeholder!),
      border: widget.error == null ? null : Border.all(color: colors.error),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: field),
            if (widget.trailing != null) ...[
              const SizedBox(width: 6),
              widget.trailing!,
            ],
          ],
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 6),
          _FieldError(widget.error!),
        ] else if (widget.hint != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.hint!,
            style: TextStyle(color: colors.muted, fontSize: 12.5),
          ),
        ],
      ],
    );
  }
}
