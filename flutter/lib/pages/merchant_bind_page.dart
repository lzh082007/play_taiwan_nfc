import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../repositories/nfc_coupon_repository.dart';
import '../services/nfc_service.dart';

enum BindMethod { nfc, qr }

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
  const BindSuccess({required this.method, required this.code, required this.couponId});
  final BindMethod method;
  final String code;
  final int couponId;
}

class BindError extends BindResultState {
  const BindError({required this.message});
  final String message;
}

/// 商家端：把一個識別碼（NFC 貼紙序號，或 App 產生的 QR 代碼）跟指定的優惠券綁在一起（功能一）。
///
/// 對應 docs/NFC_Flutter_Integration_Spec.md 第三節。優惠券本身要先透過
/// 商家後台的優惠券 CRUD API 建立好，這裡先讓商家手動輸入 coupon_id。
///
/// 兩種方式的差異：NFC 貼紙的 UID 是硬體出廠就固定的，只能「掃描既有的」；
/// QR 碼的內容純粹是軟體產生的字串，所以是 App 端直接產生一組唯一代碼（UUID）
/// 呼叫綁定 API，成功後把這組代碼渲染成 QR 圖給商家分享/列印出來貼在店裡。
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
  final _qrBoundaryKey = GlobalKey();

  BindResultState _state = const BindIdle();
  BindMethod _method = BindMethod.nfc;

  bool get _isBinding => _state is BindLoading;

  Future<void> _scanAndBindNfc() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final couponId = int.parse(_couponIdController.text);

    setState(() => _state = const BindLoading());

    try {
      final tagResult = await _nfcService.readOnce();

      try {
        await _repository.bindNfc(nfcUid: tagResult.uidHex, couponId: couponId);
        if (!mounted) return;
        setState(() => _state = BindSuccess(method: BindMethod.nfc, code: tagResult.uidHex, couponId: couponId));
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

  Future<void> _generateAndBindQr() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final couponId = int.parse(_couponIdController.text);
    final code = const Uuid().v4();

    setState(() => _state = const BindLoading());

    try {
      await _repository.bindNfc(nfcUid: code, couponId: couponId);
      if (!mounted) return;
      setState(() => _state = BindSuccess(method: BindMethod.qr, code: code, couponId: couponId));
    } on NfcApiException catch (e) {
      if (!mounted) return;
      setState(() => _state = BindError(message: e.message));
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = BindError(message: '發生未預期的錯誤：$e'));
    }
  }

  Future<void> _shareQrImage(String code) async {
    final boundary = _qrBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null || !mounted) return;

    final bytes = byteData.buffer.asUint8List();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: 'qr_$code.png', mimeType: 'image/png')],
        text: '優惠券 QR 碼（代碼：$code）',
      ),
    );
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
      appBar: AppBar(title: const Text('商家：綁定貼紙 / 產生代碼')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                SegmentedButton<BindMethod>(
                  segments: const [
                    ButtonSegment(value: BindMethod.nfc, label: Text('NFC 貼紙'), icon: Icon(Icons.nfc)),
                    ButtonSegment(value: BindMethod.qr, label: Text('QR 碼'), icon: Icon(Icons.qr_code_scanner)),
                  ],
                  selected: {_method},
                  onSelectionChanged: _isBinding ? null : (selection) => setState(() => _method = selection.first),
                ),
                const SizedBox(height: 12),
                Text(
                  _method == BindMethod.nfc
                      ? '輸入要綁定的優惠券 ID，按下「掃描並綁定」後將手機背面靠近新的 NFC 貼紙。'
                      : '輸入要綁定的優惠券 ID，按下「產生並綁定」後會自動產生一組新的 QR 代碼。',
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
                  onPressed: _isBinding ? null : (_method == BindMethod.nfc ? _scanAndBindNfc : _generateAndBindQr),
                  icon: Icon(_method == BindMethod.nfc ? Icons.nfc : Icons.qr_code_2),
                  label: Text(
                    _isBinding
                        ? (_method == BindMethod.nfc ? '掃描中...' : '產生中...')
                        : (_method == BindMethod.nfc ? '掃描並綁定' : '產生並綁定'),
                  ),
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
        child: Column(children: [CircularProgressIndicator()]),
      ),
      BindSuccess(:final method, :final code, :final couponId) => Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(method == BindMethod.nfc ? 'NFC 貼紙綁定成功' : 'QR 代碼綁定成功', style: const TextStyle(fontSize: 16)),
            if (method == BindMethod.qr) ...[
              const SizedBox(height: 16),
              RepaintBoundary(
                key: _qrBoundaryKey,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: QrImageView(data: code, size: 220),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SelectableText(code, textAlign: TextAlign.center),
            Text('優惠券 ID：$couponId'),
            if (method == BindMethod.qr) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _shareQrImage(code),
                icon: const Icon(Icons.share),
                label: const Text('分享 / 儲存 QR 圖'),
              ),
            ],
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
