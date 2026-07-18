import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

class FirebaseService {
  static FirebaseApp? _app;

  static Future<FirebaseApp> initialize() async {
    _app ??= await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return _app!;
  }

  static FirebaseApp get app {
    if (_app == null) {
      throw Exception('Firebase chưa được khởi tạo. Gọi FirebaseService.initialize() trước.');
    }
    return _app!;
  }
}
