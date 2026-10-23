/// "23 Oct 2026" — matches the web's toLocaleDateString("en-GB", { day, month: "short", year }).
String grDate(DateTime? date) {
  if (date == null) return '';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final d = date.toLocal();
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

/// Formats a number the way the web does for prices: ₦1,234,567 / $1,234.
String grMoney(num value, {String symbol = '₦'}) {
  final whole = value.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  return '$symbol$buf';
}
