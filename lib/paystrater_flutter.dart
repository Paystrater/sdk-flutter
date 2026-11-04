/// The Paystrater checkout for Flutter: Pay with Paystrater
/// and Transfer to Pay on a publishable key, with no dependencies beyond the
/// Flutter SDK. Ship goods on the incoming_payment.succeeded webhook, never on
/// onSuccess: that callback is for the payer's experience.
library paystrater_flutter;

export 'src/checkout.dart'
    show
        ActionResult,
        ActivitySource,
        AlwaysActive,
        Checkout,
        Deposit,
        FieldProblem,
        Stage;
export 'src/client.dart'
    show
        CallResult,
        CheckoutApi,
        ErrorKind,
        PaystraterClient,
        PaystraterError,
        RateLimit,
        errorForPayer;
export 'src/core.dart'
    show
        KeyMode,
        checkEvmAddress,
        formatAmount,
        isPaymentId,
        publishableKeyMode,
        walletLink;
export 'src/models.dart'
    show
        ChainOption,
        CheckoutPayment,
        PayerSummary,
        TransferToPayDetails,
        TransferToPayStart;
export 'src/platform.dart' show AppLifecycleActivity, PaystraterPlatform;
export 'src/strings.dart' show PaystraterStrings, paystraterStringsEn;
export 'src/theme.dart'
    show PaystraterTheme, PaystraterThemeMode, contrastWarnings;
export 'src/widget.dart' show PaystraterCheckout;
