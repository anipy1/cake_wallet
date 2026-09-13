import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:mobx/mobx.dart';

part 'ark_settings_view_model.g.dart';

class ArkSettingsViewModel = ArkSettingsViewModelBase with _$ArkSettingsViewModel;

/// Read-only view of the Ark delegate.
///
/// There is deliberately nothing to change here. The delegate's key sits in the third Taproot
/// leaf of every VTXO this wallet derives, so turning delegation off or pointing it elsewhere
/// would change every Ark address the wallet has ever published.
abstract class ArkSettingsViewModelBase with Store {
  ArkSettingsViewModelBase(this._wallet) {
    _load();
  }

  final WalletBase _wallet;

  @observable
  bool isLoading = true;

  @observable
  Map<String, String>? delegate;

  @computed
  bool get isDelegated => delegate != null;

  @action
  Future<void> _load() async {
    delegate = await bitcoin!.arkDelegate(_wallet);
    isLoading = false;
  }
}
