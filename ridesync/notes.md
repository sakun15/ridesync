## Blocked: permission_handler (2026-08-13)

permission_handler_android 14.0.0 fails to build — `kotlin { compilerOptions { } }`
in its build.gradle.kts doesn't resolve.

Environment (all current, not a stale-version problem):
- AGP 8.11.1
- Gradle 8.14
- Kotlin 2.2.20

Commented out in pubspec.yaml. Not needed until Phase 3 (location permissions).
When re-adding: try latest version first; if it still fails, look at whether the
Kotlin plugin is being applied to plugin subprojects, or pin an older
permission_handler major version.


commented # permission_handler: ^13.0.0   # re-add in Phase 3 (location permissions)