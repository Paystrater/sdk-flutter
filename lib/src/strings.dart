// Every word the checkout shows, the same table as
// @paystrater/react's core/strings.ts. English in v1; pass `strings` to the
// widget to replace any of them.

const Map<String, String> paystraterStringsEn = {
  'loading': 'Loading the payment…',
  'testMode': 'Test mode',
  'testModeHint': 'Test mode: no real money moves.',
  'payTo': 'Pay {merchant}',
  'amountDue': 'Amount due',
  'chooseMethod': 'Choose how to pay',
  'methodPayWithPaystrater': 'Pay with Paystrater',
  'methodPayWithPaystraterHint': 'Approve it in your Paystrater app',
  'methodTransferToPay': 'Transfer to Pay',
  'methodTransferToPayHint': 'Send from any wallet on {chains}',
  'methodAgentic': 'Pay with an AI agent',
  'methodAgenticHint': 'Your agent pays within the limits you set',
  'back': 'Back to payment methods',
  'continue': 'Continue',
  'payerLabel': 'Paystrater ID or username',
  'payerHelp': 'We\'ll send the request to your app. Approve it there.',
  'payerRequired': 'Enter your Paystrater ID or username.',
  'sendRequest': 'Send to my app',
  'sentTo': 'Sent to {name}',
  'approveInApp': 'Approve it in your Paystrater app',
  'approveInAppHint':
      'Open the request, check the amount and approve it. This page updates by itself.',
  'openApp': 'Open the Paystrater app',
  'wrongAccount':
      'Not your account? Go back and start the payment again with the right Paystrater ID.',
  'chooseChain': 'Network',
  'chooseChainRequired': 'Select a network to pay on.',
  'emailLabel': 'Email',
  'emailHelp':
      'Recommended. We email your receipt, and a link to get funds back if anything goes wrong.',
  'nameLabel': 'Name',
  'refundAddressLabel': 'Refund address',
  'refundAddressHelp':
      'An address on the same network for any refund. Without it, refunds go back to the address you send from, which an exchange may not credit.',
  'refundAddressFormat':
      'Enter a wallet address: 0x followed by 40 characters.',
  'refundAddressChecksum':
      'This address has a typo: its capital letters don\'t match. Copy it again from your wallet.',
  'emailFormat': 'Enter a valid email address, or leave it empty.',
  'optional': 'optional',
  'getAddress': 'Get the deposit address',
  'sendExactly': 'Send exactly {amount} {token} on {chain}',
  'depositAddress': 'Deposit address',
  'totalAmount': 'Total amount',
  'copy': 'Copy',
  'copyAddress': 'Copy address',
  'copied': 'Copied',
  'copyAmount': 'Copy amount',
  'copyContract': 'Copy contract address',
  'shareAddress': 'Share address',
  'selectToCopy': 'Press and hold the address to copy it.',
  'openInWallet': 'Open in wallet',
  'qrLabel': 'QR code of the deposit address',
  'fee': 'Includes a {fee} {token} network fee',
  'expiresIn': 'Expires in {time}',
  'expired': 'Expired',
  'received': 'Received so far: {amount} {token}',
  'waitingForDeposit': 'Watching for your transfer…',
  'depositNotice':
      'Send only {token} on {chain}. Anything else sent here can\'t be recovered.',
  'paymentDetails': 'Payment details',
  'tokenContract': 'Token contract',
  'network': 'Network',
  'chainId': 'Chain ID',
  'agentTitle': 'Pay with your AI agent',
  'agentStartHint':
      'Create a one-time prompt for your agent. It will pay within your limits.',
  'agentHint':
      'Give this prompt to your agent. It pays within your limits, and this page updates when it does.',
  'copyPrompt': 'Copy prompt',
  'agentConnectTitle': 'How to connect your AI agent',
  'agentConnectStep1Title': 'Add Paystrater to your AI app.',
  'agentConnectStep1':
      'In Claude, ChatGPT or another app with connectors (MCP), add this server:',
  'agentConnectStep2Title': 'Sign in with Paystrater.',
  'agentConnectStep2': 'If it asks how to connect, choose sign-in with OAuth.',
  'agentConnectStep3Title': 'Enter your Paystrater ID,',
  'agentConnectStep3':
      'or scan the QR code on the sign-in page with the Paystrater app.',
  'agentConnectStep4Title': 'Approve in the Paystrater app.',
  'agentConnectStep4': 'Match the number and choose how your agent pays.',
  'agentWalletTitle': 'Agent wallet',
  'agentWalletLead': 'Prefer a separate wallet for your agent?',
  'agentWalletBody':
      'Choose Agent wallet when you connect. It\'s kept apart from your main wallet. You fund it, and only your agent spends from it.',
  'agentWalletLimits':
      'Its spend limits start at \$50 a payment and \$200 a day. Your agent can ask for more, and you approve with a code we email you.',
  'agentGuide': 'Read the full guide',
  'statusProcessing': 'Payment received',
  'statusProcessingHint':
      'Confirming it on the network. This usually takes under a minute.',
  'statusSucceeded': 'Payment complete',
  'statusSucceededHint':
      '{merchant} has your payment. You can close this page.',
  'excessRefunded':
      'You sent more than needed; the extra {amount} {token} was returned to your address.',
  'statusExpired': 'This payment has expired',
  'statusExpiredHint':
      'Nothing arrived in time, so nothing was taken. Start again from {merchant}.',
  'statusUnderpaid': 'You sent less than the amount',
  'statusUnderpaidHint':
      'Your funds are safe. We\'ve emailed you a link to get them back.',
  'statusLate': 'Your transfer arrived after the payment expired',
  'statusLateHint':
      'Your funds are safe. We\'ve emailed you a link to get them back.',
  'statusCancelled': 'This payment was cancelled',
  'statusCancelledHint': '{merchant} cancelled it. Nothing more to pay here.',
  'statusFailed': 'This payment didn\'t go through',
  'statusRefunded': 'This payment was refunded',
  'statusUnknown': 'Updating',
  'closePage': 'You can close this page.',
  'startAgain': 'Start again',
  'errorTitle': 'We couldn\'t load this payment',
  'tryAgain': 'Try again',
  'poweredBy': 'Powered by',
  'leaveWarning':
      'A transfer may be on its way. If you leave, you won\'t see it confirmed here.',
  // Text field menu (Flutter only: the web and React Native use the system menu)
  'cut': 'Cut',
  'paste': 'Paste',
  'selectAll': 'Select all',
};

/// Fills {name} placeholders. Values are plain text.
String fillString(String template, Map<String, String?> values) => template
    .replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => values[m.group(1)] ?? '');

/// The strings for a locale, with the merchant's overrides.
class PaystraterStrings {
  PaystraterStrings([Map<String, String> overrides = const {}])
      : _table = {...paystraterStringsEn, ...overrides};

  final Map<String, String> _table;

  String operator [](String key) => _table[key] ?? key;

  String fill(String key, Map<String, String?> values) =>
      fillString(this[key], values);
}
