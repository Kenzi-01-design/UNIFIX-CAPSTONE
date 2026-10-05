# Changelog

## Current maintenance release

- Removed the SLA/deadline feature, priority controls, and the administrative audit log from the application and canonical schema.
- Added a migration to remove those database objects from existing installations while preserving report and request workflows.

## Phase 1 — Core usability

- Added compressed private photo attachments, database-generated tracking codes, public tracking, configurable SLA deadlines, and report feedback.
- Added the `report-photos` storage setup and tracking/SLA/feedback migration.

## Phase 2 — Notifications and workflow integrity

- Added in-app and email notifications, optional SMS integration, notification preferences, and append-only audit history.
- Added completion verification, rework, and owner reopening workflows.

## Phase 3 — Insight and smart operations

- Added the Admin/Assistant analytics dashboard, duplicate detection and merge support, locations and printable QR sheets, printable request job orders, and preventive-maintenance schedules.
- Added analytics, duplicate, locations, and maintenance database functions and migration.

## Phase 4 — Quality, security, and evaluation

- Added the installable PWA shell, offline fallback, and IndexedDB-backed public report drafts that require connectivity and CAPTCHA verification before submission.
- Added rate-limited anonymous SUS and ISO/IEC 25010 surveys, an Admin-only aggregate results view, and CSV export.
- Added Vitest checks for SLA calculations and work-status transitions, a pgTAP RLS test suite, tighter assigned-personnel report reads, client secret scanning, security headers, and deployment guides.
