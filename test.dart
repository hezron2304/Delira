import 'package:google_sign_in/google_sign_in.dart';

void main() {
  try {
    final g = GoogleSignIn();
    print(g);
  } catch (e) {
    print(e);
  }
}
