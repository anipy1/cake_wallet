import 'dart:io';
import 'dart:typed_data';

import 'package:ark_wallet/ark_wallet.dart' as ark;
import 'package:cw_core/amount/money.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/currency.dart';
import 'package:cw_bitcoin/ark/pending_ark_transaction.dart';
import 'package:cw_bitcoin/electrum_transaction_info.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/wallet_type.dart';
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

/// Delegated renewal, always on.
///
/// VTXOs expire, and an expired one keeps its value but loses the ability to be exited
/// unilaterally until renewed. Renewing needs the wallet open, which suits a mobile wallet badly,
/// so a delegate does it in the background. A delegate can only renew - it can never move funds.
///
/// This is deliberately not user-configurable. Turning it on or off changes the addresses the
/// wallet derives, because a delegated VTXO carries an extra Taproot leaf, so a mid-life toggle
/// would strand funds at addresses the wallet no longer watches.
const _kDelegatorUrl = 'https://delegate.arkade.money';

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

  int? _minSendSats;

  /// Smallest VTXO the operator will accept, in sats. Null until the server has been reached.
  int? get minSendSats => _minSendSats;

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
        delegatorUrl: _kDelegatorUrl,
      );

      printV('Ark: connected to $_kArkServer, renewal delegated to $_kDelegatorUrl');

      // The operator sets a floor on VTXO size; below it the send is rejected when it is built.
      // Cached here so the amount field can reject it before the user ever submits.
      try {
        final info = await client.serverInfo();
        _minSendSats = info.vtxoMinAmount?.toInt() ?? info.dust.toInt();
      } catch (e) {
        printV('Ark: could not read the minimum send amount: $e');
      }

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

  /// Ark transaction history, keyed by id so it merges with the wallet's existing history.
  ///
  /// Boarding is always incoming and offboarding always outgoing, so their amounts are unsigned;
  /// commitment and Ark transactions carry the direction in the sign of the amount.
  Future<Map<String, ElectrumTransactionInfo>> getTransactionHistory() async {
    if (!isInitialized) return {};

    final List<ark.Transaction> history;
    try {
      history = await client.transactionHistory();
    } catch (e) {
      printV('Ark: could not fetch transaction history: $e');
      return {};
    }

    final result = <String, ElectrumTransactionInfo>{};
    for (final tx in history) {
      final info = _toTransactionInfo(tx);
      result[info.id] = info;
    }
    return result;
  }

  ElectrumTransactionInfo _toTransactionInfo(ark.Transaction tx) {
    // `kind` records whether the id is a Bitcoin txid. Boarding, commitment and offboard all
    // reference on-chain transactions, so a block explorer can show them; a redeem is a purely
    // off-chain Ark transaction and exists nowhere on the chain.
    final (String id, int sats, int? at, bool incoming, bool pending, String kind) = switch (tx) {
      ark.Transaction_Boarding(:final txid, :final sats, :final confirmedAt) =>
        (txid, sats.toInt(), confirmedAt?.toInt(), true, confirmedAt == null, 'boarding'),
      ark.Transaction_Offboard(:final commitmentTxid, :final sats, :final confirmedAt) =>
        (commitmentTxid, sats.toInt(), confirmedAt?.toInt(), false, confirmedAt == null, 'offboard'),
      ark.Transaction_Commitment(:final txid, :final sats, :final createdAt) =>
        (txid, sats.toInt(), createdAt.toInt(), sats.toInt() >= 0, false, 'commitment'),
      // Not settled means this wallet's outputs in it have not been spent yet. That is the normal
      // resting state of a received VTXO, not a pending payment, so it is not shown as pending.
      ark.Transaction_Redeem(:final txid, :final sats, :final createdAt) =>
        (txid, sats.toInt(), createdAt.toInt(), sats.toInt() >= 0, false, 'redeem'),
    };

    return ElectrumTransactionInfo(
      WalletType.bitcoin,
      id: id,
      amount: Money(BigInt.from(sats.abs()), CryptoCurrency.btcark),
      direction: incoming ? TransactionDirection.incoming : TransactionDirection.outgoing,
      isPending: pending,
      fee: Money.zero(CryptoCurrency.btcark),
      date: at != null
          ? DateTime.fromMillisecondsSinceEpoch(at * 1000)
          : DateTime.now(),
      confirmations: pending ? 0 : 1,
      additionalInfo: {'isArk': true, 'arkKind': kind},
    );
  }

  /// True when [address] is an off-chain Ark address this wallet can pay directly.
  static bool isArkAddress(String address) {
    final trimmed = address.trim().toLowerCase();
    return trimmed.startsWith('ark1') || trimmed.startsWith('tark1');
  }

  /// Prepare an off-chain Ark payment.
  ///
  /// Only Ark-to-Ark sends are supported. Paying an on-chain address from Ark requires a
  /// settlement round, which the operator refuses for VTXOs outside its expiry window, so it
  /// needs handling of its own rather than being folded in here.
  PendingArkTransaction createTransaction(String address, BigInt amountSats) {
    if (!isArkAddress(address)) {
      throw ArkSendException('Ark can only pay another Ark address for now.');
    }
    if (!isInitialized) {
      throw ArkSendException('Ark is not connected.');
    }

    final minimum = _minSendSats;
    if (minimum != null && amountSats < BigInt.from(minimum)) {
      throw ArkSendException('The smallest amount Arkade accepts is $minimum sats.');
    }

    return PendingArkTransaction(
      amount: Money(amountSats, CryptoCurrency.btcark),
      // Ark charges nothing for an off-chain output; the operator's fee schedule only prices
      // on-chain inputs and outputs.
      fee: Money.zero(CryptoCurrency.btcark),
      commitOverride: () async {
        try {
          return await client.sendOffChain(address: address, sats: amountSats.toInt());
        } catch (e) {
          printV('Ark: send failed: $e');
          throw ArkSendException(e.toString());
        }
      },
    );
  }

  /// VTXOs arriving on this wallet's Ark address.
  ///
  /// Ark payments settle off-chain, so no Electrum event announces them. Returns null when the
  /// client is not up, in which case the caller falls back to polling.
  Stream<ark.ArkIncomingPayment>? watchIncomingPayments() {
    if (!isInitialized) return null;
    try {
      return client.watchIncomingPayments();
    } catch (e) {
      printV('Ark: could not watch incoming payments: $e');
      return null;
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

/// Raised when an Ark send cannot be prepared or submitted. Carries the operator's message, which
/// is the only useful diagnostic the caller gets.
class ArkSendException implements Exception {
  ArkSendException(this.message);

  final String message;

  @override
  String toString() => message;
}
