String maskEmail(String email) {
  final trimmed = email.trim();
  final at = trimmed.indexOf('@');
  if (at <= 0 || at == trimmed.length - 1) {
    return '••••@••••';
  }
  final local = trimmed.substring(0, at);
  final domain = trimmed.substring(at + 1);
  if (local.length == 1) {
    return '$local••••@$domain';
  }
  final hidden = local.length <= 2 ? 2 : local.length - 2;
  return '${local[0]}${'•' * hidden}${local[local.length - 1]}@$domain';
}
