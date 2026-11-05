/// Formats an integer amount using Vietnamese thousands separators.
///
/// Returns only the number; callers choose a visible unit such as `VNĐ` or `đ`.
String formatCurrencyAmount(int value) {
  final digits = value.abs().toString();
  final formatted = StringBuffer();
  if (value < 0) formatted.write('-');
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      formatted.write('.');
    }
    formatted.write(digits[index]);
  }
  return formatted.toString();
}
