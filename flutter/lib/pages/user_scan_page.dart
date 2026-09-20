import 'package:flutter/material.dart';

import '../config/auth_context.dart';
import '../models/nfc_scan_result.dart';
import '../repositories/nfc_coupon_repository.dart';
import '../services/nfc_service.dart';
import '../widgets/coupon_card.dart';
import '../widgets/merchant_place_card.dart';

sealed class ScanResultState {
  const ScanResultState();
}

class ScanIdle extends ScanResultState {
  const ScanIdle();
}

class ScanLoading extends ScanResultState {
  const ScanLoading();
}

class ScanSuccess extends ScanResultState {
  const ScanSuccess({required this.uidHex, required this.result});
  final String uidHex;
  final NfcScanResult result;
}

class ScanNotFound extends ScanResultState {
  const ScanNotFound({required this.uidHex, required this.message});
  final String uidHex;
  final String message;
}

class ScanError extends ScanResultState {
  const ScanError({required this.message});
  final String message;
}

/// 使用者端：掃描 NFC 貼紙查詢商家/優惠券資訊（功能二），並可核銷優惠券（功能三）。
///
/// 對應 docs/NFC_Flutter_Integration_Spec.md 第四、五節。
class UserScanPage extends StatefulWidget {
  const UserScanPage({super.key});

  @override
  State<UserScanPage> createState() => _UserScanPageState();
}

class _UserScanPageState extends State<UserScanPage> {
  final _nfcService = NfcService();
  final _repository = NfcCouponRepository();

  ScanResultState _state = const ScanIdle();

  /// 訪客模式：不帶 auId 查詢，只看內容、不會寫入領取紀錄。
  bool _guestMode = false;
  bool _isRedeeming = false;

  bool get _isScanning => _state is ScanLoading;

  Future<void> _startScan() async {
    setState(() => _state = const ScanLoading());

    try {
      final tagResult = await _nfcService.readOnce();

      try {
        final result = await _repository.scanNfc(
          tagResult.uidHex,
          auId: _guestMode ? null : AuthContext.currentAuId,
        );
        if (!mounted) return;
        setState(() => _state = ScanSuccess(uidHex: tagResult.uidHex, result: result));
      } on NfcApiFailure catch (e) {
        if (!mounted) return;
        setState(() {
          _state = e.isNotFound
              ? ScanNotFound(uidHex: tagResult.uidHex, message: e.message)
              : ScanError(message: e.message);
        });
      } on NfcApiException catch (e) {
        if (!mounted) return;
        setState(() => _state = ScanError(message: e.message));
      }
    } on NfcReadFailure catch (e) {
      if (!mounted) return;
      setState(() => _state = ScanError(message: e.message));
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = ScanError(message: '發生未預期的錯誤：$e'));
    } finally {
      await _nfcService.stopSession();
    }
  }

  Future<void> _redeem(int couponId) async {
    setState(() => _isRedeeming = true);
    try {
      await _repository.redeemCoupon(couponId: couponId, auId: AuthContext.currentAuId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('優惠券核銷成功')));
    } on NfcApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isRedeeming = false);
    }
  }

  @override
  void dispose() {
    _nfcService.stopSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('使用者：掃描貼紙')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text(
                '按下「掃描」後，將手機背面靠近店家的 NFC 貼紙，\n'
                'App 會讀取貼紙序號並查詢對應的商家資訊與優惠券。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('以訪客身份查詢'),
                subtitle: const Text('不會自動登記領取優惠券'),
                value: _guestMode,
                onChanged: _isScanning ? null : (value) => setState(() => _guestMode = value),
              ),
              FilledButton.icon(
                onPressed: _isScanning ? null : _startScan,
                icon: const Icon(Icons.nfc),
                label: Text(_isScanning ? '掃描中...' : '掃描'),
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
    );
  }

  Widget _buildResult(ScanResultState state) {
    return switch (state) {
      ScanIdle() => const SizedBox.shrink(),
      ScanLoading() => const Padding(
        padding: EdgeInsets.only(top: 32),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('請將手機靠近 NFC 貼紙...'),
          ],
        ),
      ),
      ScanSuccess(:final uidHex, :final result) => _buildSuccess(uidHex, result),
      ScanNotFound(:final uidHex, :final message) => Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Column(
          children: [
            const Icon(Icons.help_outline, size: 48),
            const SizedBox(height: 8),
            const Text('這張貼紙尚未啟用，請洽店家', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('讀到的貼紙序號：$uidHex'),
          ],
        ),
      ),
      ScanError(:final message) => Padding(
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

  Widget _buildSuccess(String uidHex, NfcScanResult result) {
    final place = result.merchantPlace;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (place != null) ...[MerchantPlaceCard(place: place), const SizedBox(height: 12)],
        CouponCard(coupon: result.coupon),
        const SizedBox(height: 12),
        if (!_guestMode)
          Text(
            result.isNewlyClaimed ? '已幫你登記領取這張優惠券' : '你之前已經領過這張優惠券了',
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _guestMode || _isRedeeming ? null : () => _redeem(result.coupon.couponId),
          icon: const Icon(Icons.check_circle_outline),
          label: Text(_isRedeeming ? '核銷中...' : '到店核銷這張優惠券'),
        ),
        if (_guestMode) const Text('訪客模式無法核銷，請關閉訪客模式後重新掃描', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        Text('讀到的貼紙序號：$uidHex', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
