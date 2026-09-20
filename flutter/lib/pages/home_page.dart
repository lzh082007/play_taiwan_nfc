import 'package:flutter/material.dart';

import 'merchant_bind_page.dart';
import 'user_scan_page.dart';

/// 進入 App 後先選擇身分：使用者（掃描/領取/核銷優惠券）或商家（綁定 NFC 貼紙）。
///
/// 目前後端還沒接登入驗證，這裡先用畫面選擇代替真正的帳號登入，
/// 見 docs/NFC_Flutter_Integration_Spec.md 開頭的說明。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NFC 商家優惠券示意')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('請選擇要示範的身分', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UserScanPage()));
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('使用者：掃描貼紙 / 領取 / 核銷'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MerchantBindPage()));
                  },
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('商家：綁定 NFC 貼紙'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
