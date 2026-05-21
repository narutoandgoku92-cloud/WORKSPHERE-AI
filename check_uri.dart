void main() {
  final base = Uri.parse('https://example.com/api/v1');
  final absolute = base.resolve('/auth/login');
  final relative = base.resolve('auth/login');
  print('absolute=' + absolute.toString());
  print('relative=' + relative.toString());
}
