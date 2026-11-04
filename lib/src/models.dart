// Checkout shapes from the public Developer API spec:
// the ReceivePayment answer of GET /v1/checkout/payments/{id} and the
// TransferToPayCheckout answer of POST /v1/checkout/transfer-to-pay. Field
// names match developer-api.yaml; test/models_test.dart reads the spec's own
// examples.

/// Statuses after which the payment can no longer change on the checkout.
const finalStatuses = <String>{
  'succeeded',
  'failed',
  'expired',
  'cancelled',
  'refunded'
};

bool isFinalStatus(String? status) =>
    status != null && finalStatuses.contains(status);

String? _string(Object? v) => v is String ? v : null;
int? _int(Object? v) => v is int ? v : (v is num ? v.toInt() : null);

class ChainOption {
  const ChainOption({required this.chainId, required this.chainName});

  factory ChainOption.fromJson(Map<String, Object?> json) => ChainOption(
      chainId: _int(json['chainId']) ?? 0,
      chainName: _string(json['chainName']) ?? '');

  final int chainId;
  final String chainName;
}

class PayerSummary {
  const PayerSummary({this.accountNumber, this.name, this.email});

  factory PayerSummary.fromJson(Map<String, Object?> json) => PayerSummary(
        accountNumber: _int(json['accountNumber']),
        name: _string(json['name']),
        email: _string(json['email']),
      );

  final int? accountNumber;
  final String? name;
  final String? email;
}

class TransferToPayDetails {
  const TransferToPayDetails({
    required this.depositAddress,
    required this.expectedAmount,
    required this.depositExpiresAt,
    this.receivedAmount,
    this.excessRefunded,
    this.tokenAddress,
    this.tokenDecimals,
  });

  factory TransferToPayDetails.fromJson(Map<String, Object?> json) =>
      TransferToPayDetails(
        depositAddress: _string(json['depositAddress']) ?? '',
        expectedAmount: _string(json['expectedAmount']) ?? '',
        depositExpiresAt: _string(json['depositExpiresAt']) ?? '',
        receivedAmount: _string(json['receivedAmount']),
        excessRefunded: _string(json['excessRefunded']),
        tokenAddress: _string(json['tokenAddress']),
        tokenDecimals: _int(json['tokenDecimals']),
      );

  final String depositAddress;
  final String expectedAmount;
  final String depositExpiresAt;
  final String? receivedAmount;
  final String? excessRefunded;
  final String? tokenAddress;
  final int? tokenDecimals;
}

/// A payment as the checkout route answers it. Amounts are decimal strings, never doubles.
class CheckoutPayment {
  const CheckoutPayment({
    required this.id,
    required this.status,
    required this.amount,
    required this.tokenTicker,
    required this.feeBearer,
    required this.expiresAt,
    required this.livemode,
    this.method,
    this.merchantName,
    this.merchantLogoUrl,
    this.chainId,
    this.chainName,
    this.fee,
    this.payer,
    this.transferToPay,
    this.description,
    this.failureReason,
    this.agentPrompt,
    this.chains = const [],
    this.methods = const [],
    this.successUrl,
    this.cancelUrl,
  });

  factory CheckoutPayment.fromJson(Map<String, Object?> json) {
    final chains = json['chains'];
    final methods = json['methods'];
    final payer = json['payer'];
    final ttp = json['transferToPay'];
    return CheckoutPayment(
      id: _string(json['id']) ?? '',
      status: _string(json['status']) ?? '',
      amount: _string(json['amount']) ?? '',
      tokenTicker: _string(json['tokenTicker']) ?? '',
      feeBearer: _string(json['feeBearer']) ?? 'customer',
      expiresAt: _string(json['expiresAt']) ?? '',
      livemode: json['livemode'] == true,
      method: _string(json['method']),
      merchantName: _string(json['merchantName']),
      merchantLogoUrl: _string(json['merchantLogoUrl']),
      chainId: _int(json['chainId']),
      chainName: _string(json['chainName']),
      fee: _string(json['fee']),
      payer:
          payer is Map<String, Object?> ? PayerSummary.fromJson(payer) : null,
      transferToPay: ttp is Map<String, Object?>
          ? TransferToPayDetails.fromJson(ttp)
          : null,
      description: _string(json['description']),
      failureReason: _string(json['failureReason']),
      agentPrompt: _string(json['agentPrompt']),
      chains: chains is List
          ? chains
              .whereType<Map<String, Object?>>()
              .map(ChainOption.fromJson)
              .toList(growable: false)
          : const [],
      methods: methods is List
          ? methods.whereType<String>().toList(growable: false)
          : const [],
      successUrl: _string(json['successUrl']),
      cancelUrl: _string(json['cancelUrl']),
    );
  }

  final String id;
  final String status;
  final String amount;
  final String tokenTicker;
  final String feeBearer;
  final String expiresAt;
  final bool livemode;
  final String? method;
  final String? merchantName;
  final String? merchantLogoUrl;
  final int? chainId;
  final String? chainName;
  final String? fee;
  final PayerSummary? payer;
  final TransferToPayDetails? transferToPay;
  final String? description;
  final String? failureReason;
  final String? agentPrompt;
  final List<ChainOption> chains;

  /// pay_with_paystrater, transfer_to_pay, agentic; present only while the payment needs action and has no method.
  final List<String> methods;
  final String? successUrl;
  final String? cancelUrl;
}

/// The answer of POST /v1/checkout/transfer-to-pay.
class TransferToPayStart {
  const TransferToPayStart({
    required this.depositAddress,
    required this.chainId,
    required this.chainName,
    required this.tokenTicker,
    required this.amount,
    required this.fee,
    required this.totalAmount,
    required this.expiresAt,
    this.tokenAddress,
    this.tokenDecimals,
  });

  factory TransferToPayStart.fromJson(Map<String, Object?> json) =>
      TransferToPayStart(
        depositAddress: _string(json['depositAddress']) ?? '',
        chainId: _int(json['chainId']) ?? 0,
        chainName: _string(json['chainName']) ?? '',
        tokenTicker: _string(json['tokenTicker']) ?? '',
        amount: _string(json['amount']) ?? '',
        fee: _string(json['fee']) ?? '',
        totalAmount: _string(json['totalAmount']) ?? '',
        expiresAt: _string(json['expiresAt']) ?? '',
        tokenAddress: _string(json['tokenAddress']),
        tokenDecimals: _int(json['tokenDecimals']),
      );

  final String depositAddress;
  final int chainId;
  final String chainName;
  final String tokenTicker;
  final String amount;
  final String fee;
  final String totalAmount;
  final String expiresAt;
  final String? tokenAddress;
  final int? tokenDecimals;
}
