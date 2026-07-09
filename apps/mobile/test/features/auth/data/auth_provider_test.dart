import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:skipit/core/services/supabase_provider.dart';
import 'package:skipit/features/auth/data/auth_provider.dart';

class MockSupabaseClient extends Mock implements sb.SupabaseClient {}
class MockGoTrueClient extends Mock implements sb.GoTrueClient {}
class MockSession extends Mock implements sb.Session {}
class MockUser extends Mock implements sb.User {}
class MockAuthResponse extends Mock implements sb.AuthResponse {}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  
  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(() => mockSupabase.auth).thenReturn(mockAuth);
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        supabaseClientProvider.overrideWithValue(mockSupabase),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('initial state is unauthenticated when no session exists', () {
    // Arrange
    when(() => mockAuth.currentSession).thenReturn(null);
    final controller = StreamController<sb.AuthState>();
    when(() => mockAuth.onAuthStateChange).thenAnswer((_) => controller.stream);

    final container = createContainer();

    // Act
    final authState = container.read(authProvider);

    // Assert
    expect(authState.status, equals(AuthStatus.unauthenticated));
    expect(authState.user, isNull);
  });

  test('initial state is authenticated when session exists', () {
    // Arrange
    final mockSession = MockSession();
    final mockUser = MockUser();
    
    when(() => mockAuth.currentSession).thenReturn(mockSession);
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    
    final controller = StreamController<sb.AuthState>();
    when(() => mockAuth.onAuthStateChange).thenAnswer((_) => controller.stream);

    final container = createContainer();

    // Act
    final authState = container.read(authProvider);

    // Assert
    expect(authState.status, equals(AuthStatus.authenticated));
    expect(authState.user, equals(mockUser));
  });

  test('signIn changes state to authenticated on success', () async {
    // Arrange
    when(() => mockAuth.currentSession).thenReturn(null);
    final controller = StreamController<sb.AuthState>();
    when(() => mockAuth.onAuthStateChange).thenAnswer((_) => controller.stream);

    final mockResponse = MockAuthResponse();
    when(() => mockAuth.signInWithPassword(email: 'test@test.com', password: 'password'))
        .thenAnswer((_) async => mockResponse);

    final container = createContainer();
    final notifier = container.read(authProvider.notifier);

    // Act - Start signIn
    final signInFuture = notifier.signIn(email: 'test@test.com', password: 'password');
    
    // Assert - State is loading during signIn
    expect(container.read(authProvider).status, equals(AuthStatus.loading));
    
    await signInFuture;

    // Simulate AuthStateChange event emitted by Supabase
    final mockSession = MockSession();
    final mockUser = MockUser();
    when(() => mockSession.user).thenReturn(mockUser);
    
    controller.add(sb.AuthState(sb.AuthChangeEvent.signedIn, mockSession));
    
    // Allow stream to process
    await Future.delayed(Duration.zero);

    // Assert - State is authenticated
    expect(container.read(authProvider).status, equals(AuthStatus.authenticated));
    expect(container.read(authProvider).user, equals(mockUser));
  });

  test('signIn handles AuthException properly', () async {
    // Arrange
    when(() => mockAuth.currentSession).thenReturn(null);
    final controller = StreamController<sb.AuthState>();
    when(() => mockAuth.onAuthStateChange).thenAnswer((_) => controller.stream);

    when(() => mockAuth.signInWithPassword(email: 'test@test.com', password: 'wrong'))
        .thenThrow(const sb.AuthException('Invalid credentials'));

    final container = createContainer();
    final notifier = container.read(authProvider.notifier);

    // Act
    await notifier.signIn(email: 'test@test.com', password: 'wrong');

    // Assert
    final state = container.read(authProvider);
    expect(state.status, equals(AuthStatus.error));
    expect(state.errorMessage, equals('Invalid credentials'));
  });

  test('signOut sets state to unauthenticated', () async {
    // Arrange
    final mockSession = MockSession();
    final mockUser = MockUser();
    when(() => mockAuth.currentSession).thenReturn(mockSession);
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    
    final controller = StreamController<sb.AuthState>();
    when(() => mockAuth.onAuthStateChange).thenAnswer((_) => controller.stream);

    when(() => mockAuth.signOut()).thenAnswer((_) async {});

    final container = createContainer();
    final notifier = container.read(authProvider.notifier);

    // Act
    await notifier.signOut();

    // Assert
    final state = container.read(authProvider);
    expect(state.status, equals(AuthStatus.unauthenticated));
    expect(state.user, isNull);
    verify(() => mockAuth.signOut()).called(1);
  });
}
