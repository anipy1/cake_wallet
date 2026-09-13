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

  /// Ark can receive: it publishes an off-chain address and an on-chain boarding address.
  bool get supportsReceive => true;

  /// Every layer can send. Ark pays another Ark address off-chain; paying an on-chain address
  /// from Ark needs a settlement round and is not offered yet.
  bool get supportsSend => true;

  /// Swaps route through the on-chain or Lightning wallet. There is no Ark swap path, so
  /// offering it while Ark is selected would spend the wrong funds.
  bool get supportsSwap => this != WalletLayer.ark;

  /// True when every action in the row is available.
  bool get supportsAllActions => supportsSend && supportsReceive && supportsSwap;
}
