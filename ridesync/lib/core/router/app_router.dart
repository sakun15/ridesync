import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../screens/auth/login_screen.dart';
import '../../screens/auth/signup_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../state/auth_provider.dart';
import '../../screens/trip/active_trip/active_trip_screen.dart';
import '../../screens/trip/create_trip/create_trip_screen.dart';
import '../../screens/trip/join_trip/join_trip_screen.dart';

/// Route paths in one place so typos become compile errors, not runtime ones.
abstract final class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const signup = '/signup';
  static const home = '/home';
  static const createTrip = '/trip/create';
  static const joinTrip = '/trip/join';
  static const trip = '/trip';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final location = state.matchedLocation;

      // Auth hasn't resolved yet — hold on splash.
      if (authState.isLoading) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final isSignedIn = authState.value != null;

      if (isSignedIn) {
        final isOnAuthFlow = location == AppRoutes.splash ||
            location == AppRoutes.onboarding ||
            location == AppRoutes.login ||
            location == AppRoutes.signup;
        return isOnAuthFlow ? AppRoutes.home : null;
      }

      // Signed out. Splash is a loading state, not a destination — move on.
      if (location == AppRoutes.splash) return AppRoutes.onboarding;

      final isOnAuthFlow = location == AppRoutes.onboarding ||
          location == AppRoutes.login ||
          location == AppRoutes.signup;
      return isOnAuthFlow ? null : AppRoutes.login;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.createTrip,
        builder: (context, state) => const CreateTripScreen(),
      ),
      GoRoute(
        path: AppRoutes.joinTrip,
        builder: (context, state) => const JoinTripScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.trip}/:tripId',
        builder: (context, state) => ActiveTripScreen(
          tripId: state.pathParameters['tripId']!,
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
});