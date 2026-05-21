import 'package:dio/dio.dart';

void main() {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/v1'));
  final request = dio.requestUri(Uri.parse('/auth/login'));
  print(request.uri.toString());
}
