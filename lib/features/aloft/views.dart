import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account.dart';
import 'api.dart';
import 'provider.dart';

class AloftLoginGate extends ConsumerWidget {
  const AloftLoginGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(aloftAccountProvider);
    return ListenableBuilder(
      listenable: account,
      builder: (context, _) {
        if (account.restoring) {
          return Scaffold(
            title: appName,
            body: Center(child: Text(context.appLocalizations.aloftLoading)),
          );
        }
        return account.signedIn ? child : _AloftLogin(account: account);
      },
    );
  }
}

class _AloftLogin extends StatefulWidget {
  const _AloftLogin({required this.account});

  final AloftAccount account;

  @override
  State<_AloftLogin> createState() => _AloftLoginState();
}

class _AloftLoginState extends State<_AloftLogin> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();

  void _submit() {
    if (widget.account.busy || !(_form.currentState?.validate() ?? false)) return;
    unawaited(widget.account.login(_email.text, _password.text));
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    final account = widget.account;
    return Scaffold(
      title: appName,
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, context.contentTopPadding + 28, 24, 32 + context.bottomInset),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _AloftBrand(),
                      const SizedBox(height: 16),
                      Text(strings.aloftWelcome, textAlign: TextAlign.center, style: AppTextStyle.title1.of(context, emphasized: true)),
                      const SizedBox(height: 8),
                      Text(strings.aloftTagline, textAlign: TextAlign.center, style: AppTextStyle.subheadline.of(context).copyWith(color: context.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _email,
                        autocorrect: false,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        decoration: InputDecoration(labelText: strings.aloftEmail),
                        validator: (value) => value != null && RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim()) ? null : strings.aloftEmailInvalid,
                      ),
                      const SizedBox(height: 20),
                      SecretTextFormField(
                        controller: _password,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(labelText: strings.aloftPassword),
                        validator: (value) => value == null || value.isEmpty ? strings.aloftPasswordRequired : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (account.issue != null) ...[
                        const SizedBox(height: 16),
                        _IssueMessage(issue: account.issue!),
                      ],
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: account.busy ? null : _submit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(account.busy ? strings.aloftLoading : strings.aloftLogin),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        children: [
                          TextButton(onPressed: () => dialogs.openUrl('$aloftWebsite/#/register'), child: Text(strings.aloftCreate)),
                          TextButton(onPressed: () => dialogs.openUrl('$aloftWebsite/#/forgetpassword'), child: Text(strings.aloftForgot)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => dialogs.openUrl('https://github.com/linjiayi393-spec/AloftCloud'),
                        child: Text(strings.aloftSources),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AloftDashboard extends ConsumerWidget {
  const AloftDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(aloftAccountProvider);
    final connected = ref.watch(isStartProvider);
    final strings = context.appLocalizations;
    return ListenableBuilder(
      listenable: account,
      builder: (context, _) {
        final subscription = account.subscription;
        return Scaffold(
          title: appName,
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, context.contentTopPadding, 20, 32 + context.bottomInset),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _AloftBrand(),
                          const SizedBox(height: 16),
                          Text(account.email, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: AppTextStyle.headline.of(context)),
                          const SizedBox(height: 8),
                          Text(connected ? strings.aloftConnected : strings.aloftDisconnected, textAlign: TextAlign.center, style: AppTextStyle.subheadline.of(context).copyWith(color: connected ? context.colorScheme.primary : context.colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: account.busy ? null : () async {
                              if (connected) {
                                await account.disconnect();
                              } else {
                                await account.connect();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(account.busy ? strings.aloftLoading : connected ? strings.aloftDisconnect : strings.aloftConnect),
                            ),
                          ),
                          if (account.issue != null) ...[
                            const SizedBox(height: 16),
                            _IssueMessage(issue: account.issue!),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(strings.aloftSubscription, style: AppTextStyle.headline.of(context)),
                          const SizedBox(height: 16),
                          Text(subscription == null ? strings.aloftLoading : _traffic(subscription.remaining), style: AppTextStyle.largeTitle.of(context, emphasized: true)),
                          Text(strings.aloftRemaining, style: AppTextStyle.subheadline.of(context).copyWith(color: context.colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(value: subscription?.fraction ?? 0),
                          const SizedBox(height: 16),
                          _Detail(label: strings.aloftUsed, value: subscription == null ? '—' : '${_traffic(subscription.used)} / ${_traffic(subscription.quota)}'),
                          _Detail(label: strings.aloftExpiry, value: subscription?.expiresAt == null ? strings.aloftNoExpiry : _date(subscription!.expiresAt!)),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(onPressed: account.busy ? null : account.refresh, child: Text(strings.aloftRefresh)),
                              TextButton(onPressed: () => dialogs.openUrl('$aloftWebsite/#/plan'), child: Text(strings.aloftManage)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(strings.aloftPlans, style: AppTextStyle.title2.of(context, emphasized: true)),
                    const SizedBox(height: 12),
                    for (final plan in account.plans) ...[
                      _PlanCard(plan: plan),
                      const SizedBox(height: 12),
                    ],
                    TextButton(onPressed: account.busy ? null : account.logout, child: Text(strings.aloftLogout)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _traffic(int bytes) => bytes >= 1073741824
      ? '${(bytes / 1073741824).toStringAsFixed(2)} GB'
      : '${(bytes / 1048576).toStringAsFixed(1)} MB';

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _AloftBrand extends StatelessWidget {
  const _AloftBrand();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Image.asset('assets/images/aloft-logo.png', width: 88, height: 88, excludeFromSemantics: true),
      const SizedBox(height: 8),
      Text(appName, style: AppTextStyle.title2.of(context, emphasized: true)),
    ],
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 24,
      runSpacing: 6,
      children: [Text(label, style: AppTextStyle.subheadline.of(context)), Text(value, style: AppTextStyle.subheadline.of(context, emphasized: true))],
    ),
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final AloftPlan plan;

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    final labels = {'month_price': strings.aloftMonth, 'quarter_price': strings.aloftQuarter, 'year_price': strings.aloftYear, 'reset_price': strings.aloftReset};
    return Card(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(plan.name, style: AppTextStyle.headline.of(context)),
          const SizedBox(height: 12),
          for (final entry in plan.prices.entries)
            _Detail(label: labels[entry.key]!, value: '¥${(entry.value / 100).toStringAsFixed(2)}'),
        ],
      ),
    );
  }
}

class _IssueMessage extends StatelessWidget {
  const _IssueMessage({required this.issue});

  final AloftAccountIssue issue;

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    final message = switch (issue) {
      AloftAccountIssue.credentials => strings.aloftIssueCredentials,
      AloftAccountIssue.network => strings.aloftIssueNetwork,
      AloftAccountIssue.response => strings.aloftIssueResponse,
      AloftAccountIssue.storage => strings.aloftIssueStorage,
      AloftAccountIssue.quota => strings.aloftIssueQuota,
      AloftAccountIssue.expired => strings.aloftIssueExpired,
    };
    return Semantics(
      liveRegion: true,
      child: Text(message, style: AppTextStyle.subheadline.of(context).copyWith(color: context.colorScheme.error)),
    );
  }
}
