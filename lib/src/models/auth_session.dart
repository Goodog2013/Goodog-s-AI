import 'auth_account.dart';
import 'user_profile.dart';

class AuthSession {
  const AuthSession({required this.account, required this.profile});

  final AuthAccount account;
  final UserProfile profile;
}
