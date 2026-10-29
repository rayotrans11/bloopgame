class GameFormat {
  static String currency(num amount, {String symbol = '\$'}) {
    if (amount >= 1000000) {
      final v = (amount / 1000000).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
      return '$symbol${v}M';
    }
    if (amount >= 1000) {
      final v = (amount / 1000).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
      return '$symbol${v}k';
    }
    if (amount is double || amount.toDouble() != amount.toInt().toDouble()) {
      return '$symbol${amount.toStringAsFixed(2)}';
    }
    return '$symbol$amount';
  }

  static String number(num n) {
    if (n >= 1000000) {
      final v = (n / 1000000).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
      return '${v}M';
    }
    if (n >= 1000) {
      final v = (n / 1000).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
      return '${v}k';
    }
    if (n is double || n.toDouble() != n.toInt().toDouble()) {
      return n.toStringAsFixed(2);
    }
    return '$n';
  }

  static String timer(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
