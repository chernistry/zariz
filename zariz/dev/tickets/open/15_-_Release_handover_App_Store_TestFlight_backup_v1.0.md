Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

When you finish this ticket, mark it in the roadmap: /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/roadmap.md

Title: Release & handover (App Store/TestFlight, backup, v1.0)

Objective
- Package the iOS app for TestFlight and prepare for App Store review.
- Finalize server backup/restore, environment documentation, and version tagging.

Deliverables
- TestFlight build approved, testers added; release notes.
- App Store metadata draft (screenshots, description, privacy).
- Server backup scripts (pg_dump), restore procedure, rotation schedule.
- v1.0.0 tags for backend and iOS; changelog.

Reference-driven accelerators (copy/adapt)
- From DeliveryApp-iOS:
  - Finalize `fastlane` config (we copied in Ticket 9); reuse lane names and add `upload_to_testflight` params; check `Makefile` targets for consistent local builds.
  - Use their CI badge and Codecov patterns as inspiration if extending QA.
- From deliver-backend:
  - Use docker-compose production layout as a reference for our prod compose (we created in Ticket 5). Verify environment variables naming and secrets handling.

Steps
1) iOS
- Ensure app icons, launch screen, bundle ID, capabilities set.
- Privacy: App Privacy details in App Store Connect; push notifications usage description in Info.plist.
- fastlane `beta` → upload; address any processing issues.

2) Backend
- Add `make backup` to run pg_dump to S3 or local disk.
```
pg_dump -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -Fc > backup-$(date +%F).dump
```
- Document restore: `pg_restore -d $DB backup.dump`.

3) Versioning
- Tag backend `v1.0.0` and iOS `1.0 (build N)`; update CHANGELOG.md.

4) Acceptance
- Verify scenarios: store creates order → courier sees/claims → status to delivered → dashboard updates.
- p95 API latency < 300 ms on VPS; push-to-UI within 30–120 s.

Next
- Post-MVP backlog: geolocation, push badges, analytics, roles UI.
