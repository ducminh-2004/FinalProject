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
        return jsonResponse['secure_url'];
      } else {
        print("Cloudinary Error: $responseString");
        return null;
      }
    } catch (e) {
      print("Upload Exception: $e");
      return null;
    }
  }

  // Giữ lại hàm cũ để tránh lỗi compile nếu chưa cập nhật hết
  static Future<String?> uploadImage(File imageFile) => uploadFile(imageFile, isAudio: false);
}
