import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = "dokbipotd"; 
  static const String uploadPreset = "spotify_preset"; 

  static Future<String?> uploadFile(File file, {bool isAudio = false}) async {
    try {
      // Cloudinary sử dụng resource_type là 'video' cho file âm thanh
      final resourceType = isAudio ? "video" : "image";
      final url = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload");
      
      final request = http.MultipartRequest("POST", url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseString);
        final secureUrl = jsonResponse['secure_url'] as String?;
        if (secureUrl == null) return null;
        // Với file âm thanh/mp4: yêu cầu Cloudinary trả về .mp3 (chỉ lấy tiếng,
        // bỏ hình ảnh của video). File nhạc thường cũng thành .mp3 chuẩn.
        return isAudio ? _toAudioUrl(secureUrl) : secureUrl;
      } else {
        print("Cloudinary Error: $responseString");
        return null;
      }
    } catch (e) {
      print("Upload Exception: $e");
      return null;
    }
  }

  // Đổi đuôi URL Cloudinary sang .mp3 -> Cloudinary tự trích xuất audio
  // (kể cả từ mp4), chỉ giữ âm thanh, bỏ hình ảnh.
  static String _toAudioUrl(String url) {
    final slash = url.lastIndexOf('/');
    final dot = url.lastIndexOf('.');
    if (dot > slash) return '${url.substring(0, dot)}.mp3';
    return '$url.mp3';
  }

  // Giữ lại hàm cũ để tránh lỗi compile nếu chưa cập nhật hết
  static Future<String?> uploadImage(File imageFile) => uploadFile(imageFile, isAudio: false);
}
