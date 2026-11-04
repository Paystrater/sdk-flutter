// The Dart port of @paystrater/react's core helpers: keys,
// payment IDs, money as decimal strings, EIP-681 links and the EIP-55 check.
// test/core_test.dart runs the same vectors as the JavaScript core.

/// Live or test, from the publishable key's prefix.
enum KeyMode { live, test }

final _publishable = RegExp(r'^pk_(live|test)_[A-Za-z0-9]+$');

/// The mode of a publishable key, or null for anything else. A secret key is never accepted.
KeyMode? publishableKeyMode(String key) {
  final match = _publishable.firstMatch(key);
  if (match == null) return null;
  return match.group(1) == 'live' ? KeyMode.live : KeyMode.test;
}

const secretKeyMessage =
    'This is a secret key. Never put a secret key in an app: anyone can read it there. Use your publishable key (pk_live_… or pk_test_…); create payments with the secret key on your server.';

/// Why a key cannot be used, or null when it can.
String? keyProblem(String key) {
  if (key.trim().isEmpty) {
    return 'Pass your publishable key (pk_live_… or pk_test_…) from the Paystrater dashboard.';
  }
  if (key.startsWith('sk_')) return secretKeyMessage;
  if (publishableKeyMode(key) == null) {
    return 'A publishable key starts with pk_live_ or pk_test_.';
  }
  return null;
}

/// Live keys on production, test keys on the sandbox.
Uri apiBaseFor(KeyMode mode) => Uri.parse(mode == KeyMode.live
    ? 'https://api.paystrater.com'
    : 'https://staging-api.paystrater.com');

final _paymentId = RegExp(r'^rcv_[A-Za-z0-9_-]{1,64}$');

/// A receive payment ID, checked before any call; it is never URL-encoded.
bool isPaymentId(String id) => _paymentId.hasMatch(id);

final _decimal = RegExp(r'^(\d+)(?:\.(\d+))?$');

/// "10.25" with 6 decimals is 10250000. Null when it is not a plain decimal or has more digits than the token.
BigInt? toBaseUnits(String amount, int decimals) {
  if (decimals < 0 || decimals > 77) return null;
  final match = _decimal.firstMatch(amount.trim());
  if (match == null) return null;
  final whole = match.group(1)!;
  final fraction = (match.group(2) ?? '').replaceFirst(RegExp(r'0+$'), '');
  if (fraction.length > decimals) return null;
  return BigInt.parse(whole + fraction.padRight(decimals, '0'));
}

/// The exact amount as the server wrote it, with thousands grouped for reading.
String formatAmount(String amount) {
  final match = _decimal.firstMatch(amount.trim());
  if (match == null) return amount;
  final whole = match
      .group(1)!
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  final fraction = match.group(2);
  return fraction == null ? whole : '$whole.$fraction';
}

/// -1, 0 or 1 without floating point; null when either is not a plain decimal.
int? compareAmounts(String a, String b) {
  final x = _decimal.firstMatch(a.trim());
  final y = _decimal.firstMatch(b.trim());
  if (x == null || y == null) return null;
  final scale = (x.group(2) ?? '').length > (y.group(2) ?? '').length
      ? (x.group(2) ?? '').length
      : (y.group(2) ?? '').length;
  BigInt big(RegExpMatch m) =>
      BigInt.parse(m.group(1)! + (m.group(2) ?? '').padRight(scale, '0'));
  return big(x).compareTo(big(y)).sign;
}

bool isPositiveAmount(String? amount) {
  if (amount == null) return false;
  final match = _decimal.firstMatch(amount.trim());
  return match != null &&
      RegExp(r'[1-9]').hasMatch('${match.group(1)}${match.group(2) ?? ''}');
}

/// An EIP-681 link that opens a wallet with the transfer filled in, or null for a native coin.
String? walletLink({
  required String? tokenAddress,
  required int? tokenDecimals,
  required int chainId,
  required String depositAddress,
  required String amount,
}) {
  if (tokenAddress == null || tokenDecimals == null || chainId <= 0) {
    return null;
  }
  final units = toBaseUnits(amount, tokenDecimals);
  if (units == null) return null;
  return 'ethereum:$tokenAddress@$chainId/transfer?address=$depositAddress&uint256=$units';
}

// ---- Keccak-256 and EIP-55 (64-bit lanes: Android and iOS only, as v1 targets) ----

const _roundConstants = <int>[
  0x0000000000000001,
  0x0000000000008082,
  0x800000000000808a,
  0x8000000080008000,
  0x000000000000808b,
  0x0000000080000001,
  0x8000000080008081,
  0x8000000000008009,
  0x000000000000008a,
  0x0000000000000088,
  0x0000000080008009,
  0x000000008000000a,
  0x000000008000808b,
  0x800000000000008b,
  0x8000000000008089,
  0x8000000000008003,
  0x8000000000008002,
  0x8000000000000080,
  0x000000000000800a,
  0x800000008000000a,
  0x8000000080008081,
  0x8000000000008080,
  0x0000000080000001,
  0x8000000080008008,
];

const _rotations = <int>[
  0,
  1,
  62,
  28,
  27,
  36,
  44,
  6,
  55,
  20,
  3,
  10,
  43,
  25,
  39,
  41,
  45,
  15,
  21,
  8,
  18,
  2,
  61,
  56,
  14
];

int _rotl(int lane, int n) => n == 0 ? lane : (lane << n) | (lane >>> (64 - n));

void _permute(List<int> a) {
  final c = List<int>.filled(5, 0);
  final b = List<int>.filled(25, 0);
  for (final rc in _roundConstants) {
    for (var x = 0; x < 5; x++) {
      c[x] = a[x] ^ a[x + 5] ^ a[x + 10] ^ a[x + 15] ^ a[x + 20];
    }
    for (var x = 0; x < 5; x++) {
      final d = c[(x + 4) % 5] ^ _rotl(c[(x + 1) % 5], 1);
      for (var y = 0; y < 25; y += 5) {
        a[x + y] ^= d;
      }
    }
    for (var x = 0; x < 5; x++) {
      for (var y = 0; y < 5; y++) {
        b[y + 5 * ((2 * x + 3 * y) % 5)] =
            _rotl(a[x + 5 * y], _rotations[x + 5 * y]);
      }
    }
    for (var y = 0; y < 25; y += 5) {
      for (var x = 0; x < 5; x++) {
        a[x + y] = b[x + y] ^ (~b[((x + 1) % 5) + y] & b[((x + 2) % 5) + y]);
      }
    }
    a[0] ^= rc;
  }
}

/// Keccak-256, the Ethereum hash (padding 0x01, not SHA3-256's 0x06).
List<int> keccak256(List<int> input) {
  const rate = 136;
  final blocks = input.length ~/ rate + 1;
  final padded = List<int>.filled(blocks * rate, 0)
    ..setRange(0, input.length, input);
  padded[input.length] ^= 0x01;
  padded[padded.length - 1] ^= 0x80;
  final state = List<int>.filled(25, 0);
  for (var offset = 0; offset < padded.length; offset += rate) {
    for (var lane = 0; lane < rate ~/ 8; lane++) {
      var value = 0;
      for (var i = 7; i >= 0; i--) {
        value = (value << 8) | padded[offset + lane * 8 + i];
      }
      state[lane] ^= value;
    }
    _permute(state);
  }
  return List<int>.generate(
      32, (i) => (state[i >> 3] >>> (8 * (i & 7))) & 0xff);
}

final _hexAddress = RegExp(r'^0x[0-9a-fA-F]{40}$');

/// The EIP-55 checksummed form of an address.
String toChecksumAddress(String address) {
  final lower = address.substring(2).toLowerCase();
  final hash = keccak256(lower.codeUnits);
  final out = StringBuffer('0x');
  for (var i = 0; i < 40; i++) {
    final nibble = (hash[i >> 1] >> (i.isEven ? 4 : 0)) & 0x0f;
    out.write(nibble >= 8 ? lower[i].toUpperCase() : lower[i]);
  }
  return out.toString();
}

enum AddressCheck { ok, format, checksum }

/// format: not 0x + 40 hex; checksum: mixed case that fails EIP-55.
AddressCheck checkEvmAddress(String value) {
  final address = value.trim();
  if (!_hexAddress.hasMatch(address)) return AddressCheck.format;
  final body = address.substring(2);
  if (body == body.toLowerCase() || body == body.toUpperCase()) {
    return AddressCheck.ok;
  }
  return toChecksumAddress(address) == address
      ? AddressCheck.ok
      : AddressCheck.checksum;
}
