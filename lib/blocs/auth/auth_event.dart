import 'package:linguaflow/blocs/auth/auth_bloc.dart';

class AuthUpdateUser extends AuthEvent {
  final String? nativeLanguage;
  final List<String>? targetLanguages;
  AuthUpdateUser({this.nativeLanguage, this.targetLanguages});
}

class AuthDeleteAccount extends AuthEvent {}