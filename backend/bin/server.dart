import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

// Cấu hình các router
final _router = Router(notFoundHandler: _notFoundHandler)
  ..get('/', _rootHandler)
  ..get('/api/v1/check', _checkHandler)
  ..get('/echo/<message>', _echoHandler)
  ..post('/api/v1/submit', _submitHandler)
  ..post('/api/v1/sendAge', _submitAge);

///Header mặc định cho dữ liệu trả về dưới dạng JSON
final _headers = {'Content-Type': 'application/json'};

/// Xử lý các yêu cầu đến đường dẫn không được định nghĩa (404 Not Found)
Response _notFoundHandler(Request req) {
  return Response.notFound('Không tìm thấy đường dẫn "${req.url}" trên server');
}

/// Hàm xử lý các yêu cầy gốc tại đường dẫn '/'
///
/// Trả về một phản hồi với thông điệp
///
/// `reg` : Đối tượng yêu cầu từ client
///
/// Trả về : Một đối tượng `Response` với mã trạng thái 200 với nội dung JSON
Response _rootHandler(Request req) {
// Constructor `ok` của Response cớ statusCode là 200
  return Response.ok(
    json.encode({'message': 'Hello World!'}),
    headers: _headers,
  );
}

/// Hàm xử lý yêu cầu tại đường dẫn '/api/v1/check'
Response _checkHandler(Request req) {
  try {
    return Response.ok(
      json.encode({'message': 'Chào mừng bạn đến với ứng dụng web động'}),
      headers: _headers,
    );
  } catch (e) {
    return Response.badRequest(
      body: json.encode({'error': e.toString()}),
      headers: _headers,
    );
  }
}

Response _echoHandler(Request request) {
  final message = request.params['message'];
  return Response.ok('$message\n');
}

Future<Response> _submitHandler(Request req) async {
  try {
    // Đọc payload từ request
    final payload = await req.readAsString();

    // Giải mã JSON từ payload
    final data = json.decode(payload);

    // Lấy giá trị 'name' từ data, ép kiểu String? nếu có
    final name = data['name'] as String?;

    // Kiểm tra nếu 'name' hợp lệ
    if (name != null && name.isNotEmpty) {
      // Tạo phản hồi chào mừng
      final response = {'message': 'Chào mừng $name'};

      //Trả về phản hồi với statusCode 200 và JSON
      return Response.ok(
        json.encode(response),
        headers: _headers,
      );
    } else {
      // Tạo phản hồi yêu cầu cung cấp tên
      final response = {'message': 'Server không nhận được tên bạn.'};

      // Trả về phản hồi với statusCode 400 và JSON
      return Response.badRequest(
        body: json.encode(response),
        headers: _headers,
      );
    }
  } catch (e) {
    // Xử lý ngoại lệ khi giải mã JSON
    final response = {'message': ' yêu cầu không hợp lệ. Lỗi ${e.toString()}'};

    // Trả về phản hồi với status 400
    return Response.badRequest(
      body: json.encode(response),
      headers: _headers,
    );
  }
}

Future<Response> _submitAge(Request req) async {
  try {
    final payload = await req.readAsString();

    final data = json.decode(payload);

    final birth = data['age'] as String?;

    if (birth != null && birth.isNotEmpty) {
      final birthDate = DateTime.parse(birth);

      final DateTime now = DateTime.now();
      int age = now.year - birthDate.year;
      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }

      final response = {'message': 'Tuổi của bạn là : $age'};

      return Response.ok(
        json.encode(response),
        headers: _headers,
      );
    } else {
      final response = {'message': 'Vui lòng nhập ngày sinh của bạn'};

      return Response.badRequest(
        body: json.encode(response),
        headers: _headers,
      );
    }
  } catch (e) {
    final response = {'message': ' yêu cầu không hợp lệ. Lỗi ${e.toString()}'};

    return Response.badRequest(
      body: json.encode(response),
      headers: _headers,
    );
  }
}

void main(List<String> args) async {
  // Lắng nghe trên tất cả các ipv4
  final ip = InternetAddress.anyIPv4;

  final corsHeader = createMiddleware(requestHandler: (req) {
    if (req.method == 'OPTIONS') {
      return Response.ok('', headers: {
        // cho phép mọi truy cập trong (trong môi trường dev). trong môi trường production chúng ta nên thay thế * bằng domain cụ thể
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, PATCH, HEAD',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      });
    }
    return null; // tiếp tục xử lý yêu cầu khác
  }, responseHandler: (res) {
    return res.change(headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, PATCH, HEAD',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    });
  });

  // Cấu hình một pipeline để logs các requests và middleware.
  final handler = Pipeline()
      .addMiddleware(corsHeader) // thêm middleware xử lý CORS
      .addMiddleware(logRequests())
      .addHandler(_router.call);

  // Để chạy các containers chúng ta sử dụng biến môi trường PORT
  // Nếu biến môi trường không được thiết lập nó sẽ sử dụng các giá trị từ biến
  // môi trường này: nếu không, nó sẽ sử dụng giá trị mặc định là 8080
  final port = int.parse(Platform.environment['PORT'] ?? '8080');

  // Khởi chạy server tại địa chỉ và cổng chỉ định
  final server = await serve(handler, ip, port);
  print('Server đang chạy tại http://${server.address.host}:${server.port}');
}
