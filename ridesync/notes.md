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


## Deferred from Phase 0
- Blaze plan upgrade → needed before Phase 3 (Maps SDK) and Phase 5 (Cloud Functions)
- Budget alert in Google Cloud Console → set at same time as Blaze, BEFORE writing 
  any location-update code
- Physical Android device → required from Phase 4 (emulator sensors are useless for 
  crash detection)

  ## Firestore rules
Live rules are in the Firebase console. `firestore.rules` in the repo is a 
versioned copy — keep both in sync manually when changing rules.
Consider Firebase CLI (`firebase deploy --only firestore:rules`) later to 
remove the manual step.