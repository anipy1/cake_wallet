import 'package:cw_core/crypto_currency.dart';

/// Which Bitcoin layer the home screen is currently showing.
///
/// This replaces the earlier `bool lightningMode`, which could only express two of the three
/// balances a Bitcoin wallet now carries.
enum WalletLayer {
  onChain,
  lightning,
  ark;

  bool get isOnChain => this == WalletLayer.onChain;

  bool get isLightning => this == WalletLayer.lightning;

  bool get isArk => this == WalletLayer.ark;

  /// The asset whose balance this layer displays, or null for on-chain, where the asset depends
  /// on the wallet (BTC, tBTC, LTC...).
  CryptoCurrency? get asset => switch (this) {
        WalletLayer.onChain => null,
        WalletLayer.lightning => CryptoCurrency.btcln,
        WalletLayer.ark => CryptoCurrency.btcark,
      };

  /// Ark currently exposes a balance only. Sending, receiving and swapping are not implemented,
  /// so callers must not offer those actions while this layer is selected - the underlying
  /// handlers would operate on the on-chain wallet instead.
  bool get supportsActions => this != WalletLayer.ark;
}
