import 'package:bitcoin_base/src/bitcoin/address/address.dart';

/// Address types for the Ark layer.
///
/// Mirrors [LightningAddressType]: Ark addresses are not Bitcoin script addresses, but the receive
/// page keys everything off [BitcoinAddressType], so they are modelled as one.
class ArkAddressType implements BitcoinAddressType {
  const ArkAddressType._(this.value);

  /// Off-chain Ark address (`ark1...`). Receives VTXOs from other Ark users, instantly.
  static const ArkAddressType p2ark = ArkAddressType._("Arkade");

  /// On-chain boarding address (`bc1p...`). Moves Bitcoin into Ark; requires a confirmation and a
  /// subsequent boarding round, so it is not instant.
  static const ArkAddressType boarding = ArkAddressType._("Arkade Boarding");

  static const String ArkAddressMatcher = r'^(ark|tark)1[a-z0-9]+$';

  @override
  bool get isP2sh => false;

  @override
  bool get isSegwit => false;

  @override
  final String value;

  @override
  int get hashLength => 32;

  @override
  String toString() => value;
}
