import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/new-ui/widgets/receive_page/receive_top_bar.dart';
import 'package:cake_wallet/view_model/settings/ark_settings_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class ArkSettingsPage extends StatelessWidget {
  ArkSettingsPage(this._viewModel);

  final ArkSettingsViewModel _viewModel;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          ModalTopBar(
            title: 'Arkade',
            leadingIcon: Icon(Icons.arrow_back_ios_new),
            leadingSemanticLabel: S.current.seed_alert_back,
            onLeadingPressed: Navigator.of(context).pop,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Observer(
                builder: (_) {
                  if (_viewModel.isLoading) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final delegate = _viewModel.delegate;
                  if (delegate == null) {
                    return _Explainer(
                      'Renewal is not delegated. This wallet renews its own VTXOs, which '
                      'requires it to be open before they expire.',
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Explainer(
                        'A VTXO expires, and renewing one needs the wallet open at the right '
                        'moment. A delegate does it in the background instead. It can only '
                        'renew: it can never move or spend your funds.',
                      ),
                      SizedBox(height: 24),
                      _Row(label: 'Service', value: delegate['url'] ?? ''),
                      _Row(label: 'Fee per renewal', value: '${delegate['fee'] ?? '0'} sats'),
                      _Row(label: 'Public key', value: delegate['pubkey'] ?? '', copyable: true),
                      _Row(label: 'Fee address', value: delegate['address'] ?? '', copyable: true),
                      SizedBox(height: 24),
                      _Explainer(
                        'This cannot be changed. The delegate is part of every Ark address this '
                        'wallet derives, so switching it would strand funds at addresses the '
                        'wallet no longer watches.',
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.copyable = false});

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 4),
          InkWell(
            // A public key is long enough that reading it off the screen is useless; copying it
            // is the only way anyone would actually check it against the delegate's own listing.
            onTap: copyable
                ? () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(S.current.copied_to_clipboard)),
                    );
                  }
                : null,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (copyable)
                  Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.copy, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
