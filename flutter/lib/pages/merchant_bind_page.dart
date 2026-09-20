import 'package:flutter/material.dart';

import '../repositories/nfc_coupon_repository.dart';
import '../services/nfc_service.dart';

sealed class BindResultState {
  const BindResultState();
}

class BindIdle extends BindResultState {
  const BindIdle();
}

class BindLoading extends BindResultState {
  const BindLoading();
}

class BindSuccess extends BindResultState {
  const BindSuccess({required this.uidHex, required this.couponId});
  final String uidHex;
  final int couponId;
}

class BindError extends BindResultState {
  const BindError({required this.message});
  final String message;
}

/// 商家端：掃描一張新的 NFC 貼紙，把它跟指定的優惠券綁在一起（功能一）。
///
/// 對應 docs/NFC_Flutter_Integration_Spec.md 第三節。優惠券本身要先透過
/// 商家後台的優惠券 CRUD API 建立好，這裡先讓商家手動輸入 coupon_id。
class MerchantBindPage extends StatefulWidget {
  const MerchantBindPage({super.key});

  @override
  State<MerchantBindPage> createState() => _MerchantBindPageState();
}

class _MerchantBindPageState extends State<MerchantBindPage> {
  final _nfcService = NfcService();
  final _repository = NfcCouponRepository();
  final _couponIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  BindResultState _state = const BindIdle();

  bool get _isBinding => _state is BindLoading;

  Future<void> _scanAndBind() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final couponId = int.parse(_couponIdController.text);

    setState(() => _state = const BindLoading());

    try {
      final tagResult = await _nfcService.readOnce();

      try {
        await _repository.bindNfc(nfcUid: tagResult.uidHex, couponId: couponId);
        if (!mounted) return;
        setState(() => _state = BindSuccess(uidHex: tagResult.uidHex, couponId: couponId));
      } on NfcApiException catch (e) {
        if (!mounted) return;
        setState(() => _state = BindError(message: e.message));
      }
    } on NfcReadFailure catch (e) {
      if (!mounted) return;
      setState(() => _state = BindError(message: e.message));
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = BindError(message: '發生未預期的錯誤：$e'));
    } finally {
      await _nfcService.stopSession();
    }
  }

  @override
  void dispose() {
    _nfcService.stopSession();
    _couponIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('商家：綁定 NFC 貼紙')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Text(
                  '輸入要綁定的優惠券 ID，按下「掃描並綁定」後將手機背面靠近新的 NFC 貼紙。',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _couponIdController,
                  enabled: !_isBinding,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '優惠券 ID（coupon_id）', border: OutlineInputBorder()),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return '請輸入優惠券 ID';
                    if (int.tryParse(value.trim()) == null) return '請輸入整數';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isBinding ? null : _scanAndBind,
                  icon: const Icon(Icons.nfc),
                  label: Text(_isBinding ? '掃描中...' : '掃描並綁定'),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(child: _buildResult(_state)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResult(BindResultState state) {
    return switch (state) {
      BindIdle() => const SizedBox.shrink(),
      BindLoading() => const Padding(
        padding: EdgeInsets.only(top: 32),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('請將手機靠近 NFC 貼紙...'),
          ],
        ),
      ),
      BindSuccess(:final uidHex, :final couponId) => Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            const Text('NFC 貼紙綁定成功', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('貼紙序號：$uidHex'),
            Text('優惠券 ID：$couponId'),
          ],
        ),
      ),
      BindError(:final message) => Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    };
  }
}
