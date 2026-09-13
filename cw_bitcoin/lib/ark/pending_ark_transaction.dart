import 'package:cw_core/amount/money.dart';
import 'package:cw_core/pending_transaction.dart';

/// An Ark send that has been prepared but not yet broadcast.
///
/// Mirrors [PendingLightningTransaction]: there is no raw transaction to show, because the
/// wallet never builds one itself - the Ark client signs and submits it to the operator when
/// [commit] runs, and only then is a txid known.
class PendingArkTransaction with PendingTransaction {
  PendingArkTransaction({
    required this.amount,
    required this.fee,
    required this.commitOverride,
    this.id = '',
  });

  final Future<String> Function() commitOverride;

  @override
  String id;

  @override
  final Money amount;

  @override
  final Money fee;

  /// Ark transactions are not Bitcoin transactions, so there is no hex to display or export.
  @override
  String get hex => '';

  @override
  String get amountFormatted => amount.toString();

  @override
  int? get outputCount => 1;

  @override
  Future<void> commit() async {
    id = await commitOverride.call();
  }

  @override
  bool shouldCommitUR() => false;

  @override
  Future<Map<String, String>> commitUR() => throw UnimplementedError();
}
