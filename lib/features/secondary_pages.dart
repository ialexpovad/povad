import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../design/povad_theme.dart';
import '../design/preview_notice.dart';
import '../domain/android_usb_host.dart';
import '../l10n/generated/app_localizations.dart';

class EmptyPage extends StatelessWidget {
  const EmptyPage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.previewMode = true,
    this.detail,
  });
  final IconData icon;
  final String title, body;
  final bool previewMode;
  final String? detail;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = paletteOf(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              Icon(icon, size: 52, color: colors.primary),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.muted),
              ),
              if (detail?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.error),
                ),
              ],
              const SizedBox(height: 30),
              if (previewMode) PreviewNotice(label: l.previewNotice),
            ],
          ),
        ),
      ),
    );
  }
}

class BridgeSetupPage extends StatelessWidget {
  const BridgeSetupPage({
    super.key,
    required this.serialPort,
    required this.baud,
    required this.tcpPort,
    required this.onSerialPortChanged,
    required this.onBaudChanged,
    required this.onTcpPortChanged,
    required this.allowLan,
    required this.onAllowLanChanged,
    required this.error,
    required this.running,
    this.usbMode = false,
    this.usbPorts = const [],
    this.usbLoading = false,
    this.usbMessage,
    this.onRefreshUsb,
    this.onUsbPortSelected,
  });

  final String serialPort, baud, tcpPort;
  final ValueChanged<String> onSerialPortChanged;
  final ValueChanged<String> onBaudChanged;
  final ValueChanged<String> onTcpPortChanged;
  final bool allowLan;
  final ValueChanged<bool> onAllowLanChanged;
  final String? error;
  final bool running;
  final bool usbMode, usbLoading;
  final List<AndroidUsbPort> usbPorts;
  final String? usbMessage;
  final VoidCallback? onRefreshUsb;
  final ValueChanged<AndroidUsbPort>? onUsbPortSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = paletteOf(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.bridgeSetupTitle,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                usbMode ? l.androidBridgeSetupIntro : l.bridgeSetupIntro,
                style: TextStyle(color: colors.muted),
              ),
              const SizedBox(height: 26),
              if (usbMode) ...[
                Text(
                  l.usbPortsTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: shad.OutlineButton(
                    onPressed: usbLoading || running ? null : onRefreshUsb,
                    child: Text(l.scanUsbDevices),
                  ),
                ),
                if (usbMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(usbMessage!, style: TextStyle(color: colors.error)),
                ],
                if (usbLoading && usbPorts.isEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    l.scanningUsbDevices,
                    style: TextStyle(color: colors.muted),
                  ),
                ],
                if (usbPorts.isEmpty && usbMessage == null && !usbLoading) ...[
                  const SizedBox(height: 10),
                  Text(l.noUsbDevices, style: TextStyle(color: colors.muted)),
                ],
                if (usbPorts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final port in usbPorts)
                        port.nativeSelection == serialPort
                            ? shad.PrimaryButton(
                                onPressed: running || usbLoading
                                    ? null
                                    : () => onUsbPortSelected?.call(port),
                                child: Text(port.label),
                              )
                            : shad.OutlineButton(
                                onPressed: running || usbLoading
                                    ? null
                                    : () => onUsbPortSelected?.call(port),
                                child: Text(port.label),
                              ),
                    ],
                  ),
                ],
              ] else
                _SettingField(
                  label: l.serialPortPath,
                  value: serialPort,
                  onChanged: onSerialPortChanged,
                  enabled: !running,
                  placeholder: '/dev/cu.usbserial-…',
                ),
              const SizedBox(height: 20),
              _SettingField(
                label: l.baudRate,
                value: baud,
                onChanged: onBaudChanged,
                enabled: !running,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              _SettingField(
                label: l.tcpPortNumber,
                value: tcpPort,
                onChanged: onTcpPortChanged,
                enabled: !running,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.lanAccessTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  shad.Switch(
                    value: allowLan,
                    onChanged: running ? null : onAllowLanChanged,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(l.lanAccessRisk, style: TextStyle(color: colors.muted)),
              if (error != null) ...[
                const SizedBox(height: 18),
                Text(error!, style: TextStyle(color: colors.error)),
              ],
              const SizedBox(height: 24),
              Text(l.loopbackNote, style: TextStyle(color: colors.muted)),
              const SizedBox(height: 12),
              Text(l.bridgeUnverified, style: TextStyle(color: colors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingField extends StatelessWidget {
  const _SettingField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.enabled,
    this.keyboardType,
    this.placeholder,
  });

  final String label, value;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final TextInputType? keyboardType;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        shad.TextField(
          initialValue: value,
          onChanged: onChanged,
          enabled: enabled,
          keyboardType: keyboardType,
          placeholder: placeholder == null ? null : Text(placeholder!),
        ),
      ],
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
    required this.skin,
    required this.onSkinChanged,
  });
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final PovadSkin skin;
  final ValueChanged<PovadSkin> onSkinChanged;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = paletteOf(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.settings,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                l.language,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (code, label) in [
                    ('en', l.english),
                    ('be', l.belarusian),
                  ])
                    code == locale.languageCode
                        ? shad.PrimaryButton(
                            onPressed: () => onLocaleChanged(Locale(code)),
                            child: Text(label),
                          )
                        : shad.OutlineButton(
                            onPressed: () => onLocaleChanged(Locale(code)),
                            child: Text(label),
                          ),
                ],
              ),
              const SizedBox(height: 34),
              Text(
                l.appearance,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 7),
              Text(l.appearanceSystem, style: TextStyle(color: colors.muted)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (option, label) in [
                    (PovadSkin.copper, l.copperTheme),
                    (PovadSkin.classicBlue, l.classicBlueTheme),
                  ])
                    option == skin
                        ? shad.PrimaryButton(
                            onPressed: () => onSkinChanged(option),
                            child: Text(label),
                          )
                        : shad.OutlineButton(
                            onPressed: () => onSkinChanged(option),
                            child: Text(label),
                          ),
                ],
              ),
              const SizedBox(height: 34),
              Text(
                l.about,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 7),
              Text(l.aboutDescription, style: TextStyle(color: colors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
