import 'dart:io';
import 'dart:typed_data';

import 'package:ark_wallet/ark_wallet.dart' as ark;
import 'package:cw_core/amount/money.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/currency.dart';
import 'package:cw_core/utils/print_verbose.dart';

bool _arkLibUninitialized = true;

/// Bitcoin mainnet configuration for Arkade.
///
/// `network` uses rust-bitcoin's spelling, where mainnet is `bitcoin`; `mainnet` is rejected.
/// Operator URLs come from https://docs.arkadeos.com/wallets/getting-started/developer-resources
const _kNetwork = 'bitcoin';
const _kArkServer = 'https://arkade.computer';
const _kBoltzUrl = 'https://api.boltz.exchange';

/// Arkade publishes no mainnet Esplora endpoint, so one is chosen here. Whoever operates it can
/// see every address this wallet queries.
const _kEsploraUrl = 'https://blockstream.info/api';

/// Wraps the Ark client for a single Bitcoin wallet.
///
/// Mirrors [LightningWallet]: it is constructed by `BitcoinWallet`, derives from the same seed,
/// and contributes a balance under [CryptoCurrency.btcark].
class ArkWallet {
  ArkWallet({
    required this.seedBytes,
    required this.dataDir,
  });

  /// The wallet's BIP39 seed. Passed through to the Ark client as the BIP32 master seed, so Ark
  /// derives from the same master key as the rest of the wallet and the mnemonic alone recovers it.
  final Uint8List seedBytes;

  /// Directory for Ark state, notably the swap database. Must be writable and wallet-specific.
  final String dataDir;

  ark.ArkWallet? _client;

  static bool get isAvailable => Platform.isIOS || Platform.isAndroid || Platform.isMacOS;

  Currency get currency => CryptoCurrency.btcark;

  bool get isInitialized => _client != null;

  ark.ArkWallet get client => _client!;

  Future<bool> init() async {
    try {
      if (_arkLibUninitialized) {
        await ark.LibArk.init();
        _arkLibUninitialized = false;
      }

      final dir = Directory(dataDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      _client = await ark.ArkWallet.init(
        secretKey: seedBytes,
        network: _kNetwork,
        esplora: _kEsploraUrl,
        server: _kArkServer,
        boltz: _kBoltzUrl,
        dataDir: dataDir,
      );

      printV('Ark: connected to $_kArkServer');
      return true;
    } catch (e) {
      // A failure here must not take the Bitcoin wallet down with it.
      printV('Ark: init failed: $e');
      _client = null;
      return false;
    }
  }

  /// Off-chain Ark address for receiving VTXOs.
  Future<String?> getAddress() async {
    if (!isInitialized) return null;
    try {
      return await client.offchainAddress();
    } catch (e) {
      printV('Ark: could not get offchain address: $e');
      return null;
    }
  }

  /// On-chain address for boarding funds into Ark.
  Future<String?> getBoardingAddress() async {
    if (!isInitialized) return null;
    try {
      return await client.boardingAddress();
    } catch (e) {
      printV('Ark: could not get boarding address: $e');
      return null;
    }
  }

  Future<Money> getBalance() async {
    if (!isInitialized) return Money.zero(CryptoCurrency.btcark);
    try {
      final balance = await client.balance();
      return Money.fromInt(balance.total.toInt(), CryptoCurrency.btcark);
    } catch (e) {
      printV('Ark: could not fetch balance: $e');
      return Money.zero(CryptoCurrency.btcark);
    }
  }

  /// Balance whose batch has expired: still spendable, but it has lost the ability to exit
  /// unilaterally until it is renewed via a settle.
  Future<Money> getRecoverableBalance() async {
    if (!isInitialized) return Money.zero(CryptoCurrency.btcark);
    try {
      final balance = await client.balance();
      return Money.fromInt(balance.recoverable.toInt(), CryptoCurrency.btcark);
    } catch (e) {
      printV('Ark: could not fetch recoverable balance: $e');
      return Money.zero(CryptoCurrency.btcark);
    }
  }

  /// How long funds stay locked after starting a unilateral exit, in seconds.
  ///
  /// Decoded from the operator's BIP68 sequence; null when the timelock is height-based.
  Future<int?> getUnilateralExitDelaySeconds() async {
    if (!isInitialized) return null;
    try {
      final info = await client.serverInfo();
      return info.unilateralExitDelaySeconds?.toInt();
    } catch (e) {
      printV('Ark: could not fetch server info: $e');
      return null;
    }
  }

  void close() => _client = null;
}
