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


Review this Flutter/Firebase code for a specific security invariant.

CONTEXT
Trip membership is stored in two places that must never disagree:
  1. trips/{tripId}.memberIds — an array, read by Firestore security rules
  2. trips/{tripId}/members/{uid} — a subcollection with per-member data

The array exists only because Firestore security rules cannot query 
subcollections. The rule "only members can read this trip" depends on it.

Trips will contain live GPS location data. If these two sources drift 
apart, either someone retains access to location data they should not 
have, or a legitimate member is locked out.

CHECK FOR
1. Every write that adds/removes a UID from memberIds must be in the same 
   WriteBatch (or transaction) as the corresponding members subcollection 
   write. Flag any bare .update()/.set()/.delete() touching one without 
   the other.
2. Every batch must be awaited. An unawaited commit can silently fail.
3. Firestore rules must actually gate trip reads on memberIds — check 
   firestore.rules matches what the code assumes.
4. Any code path that could produce a half-joined state: early returns 
   between the two writes, error handling that commits partially, 
   retry logic.
5. Ended/left members: confirm removal from memberIds actually revokes 
   read access under the current rules.

Report each violation with file, line, and why it breaks the invariant. 
If the invariant holds everywhere, say so plainly rather than inventing 
issues.

Checkpoint	Why
End of Phase 2	Membership code is written. Cheapest time to fix.
End of Phase 3	⚠️ The critical one. This is when location data starts flowing through these rules. A drift bug goes from "annoying" to "privacy breach" at this exact moment.
End of Phase 5	Emergency alerts read the member list to decide who gets notified.
Phase 7	Full security audit anyway.