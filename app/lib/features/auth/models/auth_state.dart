import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_state.freezed.dart';

enum AuthStatus { idle, identifierEntered, codeSent, verifying, authenticated }

@freezed
class AuthState with _$AuthState {
  const AuthState._();

  const factory AuthState({
    @Default(AuthStatus.idle) AuthStatus status,
    String? userId,
    String? phone,
    String? email,
    String? errorMessage,
  }) = _AuthState;

  bool get isAuthenticated => status == AuthStatus.authenticated;
}
