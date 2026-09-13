import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/new-ui/models/wallet_layer.dart';
import 'package:cake_wallet/src/widgets/cake_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Switches the home screen between the balances a Bitcoin wallet carries.
///
/// Replaces the earlier two-position toggle. The knob slides to the selected segment and each
/// glyph is tinted to show which one is active.
class LayerSwitcher extends StatelessWidget {
  const LayerSwitcher({
    super.key,
    required this.layer,
    required this.onLayerSelected,
    this.layers = const [WalletLayer.onChain, WalletLayer.lightning, WalletLayer.ark],
  });

  final WalletLayer layer;
  final ValueChanged<WalletLayer> onLayerSelected;
  final List<WalletLayer> layers;

  static const double _segment = 27;
  static const double _padding = 4.5;

  String _iconFor(WalletLayer layer) => switch (layer) {
        WalletLayer.onChain => 'assets/new-ui/switcher-bitcoin.svg',
        WalletLayer.lightning => 'assets/new-ui/switcher-lightning.svg',
        WalletLayer.ark => 'assets/new-ui/switcher-arkade.svg',
      };

  String _labelFor(BuildContext context, WalletLayer layer) => switch (layer) {
        WalletLayer.onChain => 'Bitcoin',
        WalletLayer.lightning => S.of(context).lightning_mode,
        WalletLayer.ark => 'Arkade',
      };

  @override
  Widget build(BuildContext context) {
    final selectedIndex = layers.indexOf(layer);
    final theme = Theme.of(context);

    return Container(
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(borderRadius: BorderRadiusGeometry.circular(900.0)),
        color: theme.colorScheme.surfaceContainer,
      ),
      width: _segment * layers.length + _padding * 2,
      height: 36,
      padding: const EdgeInsets.all(_padding),
      child: Stack(
        children: [
          // The knob. Its offset is derived from the selected index so that adding a layer does
          // not require touching the animation.
          AnimatedPositioned(
            left: _segment * (selectedIndex < 0 ? 0 : selectedIndex),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: Container(
              width: _segment,
              height: _segment,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(9999990.0)),
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Row(
            children: [
              for (final entry in layers.asMap().entries)
                Semantics(
                  button: true,
                  selected: entry.value == layer,
                  label: _labelFor(context, entry.value),
                  child: InkWell(
                    onTap: () {
                      if (entry.value == layer) return;
                      HapticFeedback.mediumImpact();
                      onLayerSelected(entry.value);
                    },
                    child: SizedBox(
                      width: _segment,
                      height: _segment,
                      child: CakeImageWidget(
                        imageUrl: _iconFor(entry.value),
                        width: _segment,
                        height: _segment,
                        colorFilter: ColorFilter.mode(
                          entry.value == layer
                              ? theme.colorScheme.surfaceContainer
                              : theme.colorScheme.primary,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
