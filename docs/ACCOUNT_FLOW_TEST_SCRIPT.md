# UNIFIX account-flow manual test script

Run this only in a non-production Supabase project with disposable test
accounts. Keep `Actual` and `Pass/Fail` blank until the manual run is complete.
Use separate accounts for Public, Employee, Assistant, Personnel, and Admin
checks. Verify both visible navigation and direct page access; where practical,
also verify that disallowed data changes are rejected by the server.

Account deletion is intentionally refused when reports, requests, or assignments
reference the account, preserving business history rather than cascading or
anonymizing it. If deletion is permitted, the Auth account, profile, and
account-specific preferences/notifications are removed; the account audit trail
is retained.

## Registration and account lifecycle

| Test case | Steps | Expected | Actual | Pass/Fail |
|---|---|---|---|---|
| Valid registration | Register with a new allowed-domain email, then inspect User Management and sign in before approval. | Signup sends no confirmation email; a linked profile appears inactive and pending with the requested role; sign-in is blocked pending approval. |  |  |
| Requested registration roles | Register separate applicants requesting `Employee`, `Assistant`, and `Personnel`; inspect each pending profile. | Each supported role request is recorded. Applicants cannot request `Admin`; the effective role remains subject to review and approval. |  |  |
| Client-supplied role cannot grant access | Attempt registration or sign-in while changing the role value in the client request or role selector. | The role stored on the approved profile controls access; a client-supplied role cannot grant privileges or create an Admin account. |  |  |
| Bad domain | Attempt registration with an address outside the configured domain list. | Inline validation prevents submission; direct server-side registration is rejected with a friendly error. |  |  |
| Duplicate email | Submit a registration using an existing address. | No duplicate profile is created; the UI gives a generic sign-in/reset-password message without account enumeration. |  |  |
| Notification email verification | Sign in to an approved account, enter a notification email in Settings, request verification, and open its verification link. | The separate notification address becomes verified; email updates remain off until the user enables and saves them. |  |  |
| Notification opt-in | Change the notification email after verification, then try to enable email updates. | Editing the address clears its verified state and disables email updates until that new address is verified. |  |  |
| Sign-up email confirmation setting | Register a valid new account with Email → Confirm email disabled in Supabase. | Supabase does not require an email confirmation; the account still waits for Admin or Assistant approval. |  |  |
| Pending login | Register a new applicant and sign in before the profile is approved. | Sign-in ends locally and explains that administrative approval is pending; no email confirmation is requested. |  |  |
| Approve then login | As Admin, approve the pending profile with a role; then sign in as the applicant. | Approval is audited; the assigned profile role controls navigation and sign-in succeeds. |  |  |
| Reject then login | As Admin, reject a pending profile with a reason; sign in as that applicant. | The account remains inactive; the applicant sees rejection and the configured reason. |  |  |
| Re-apply | As a rejected applicant, request another review; as Admin, reopen the application. | Request is rate-limited to once every 30 days; only the Admin action returns it to pending. |  |  |
| Deactivate then login | As Admin, deactivate an approved account; sign in as that user. | The profile remains approved but inactive; sign-in is denied with a deactivation message. |  |  |
| Reactivate | As Admin, reactivate the same approved account; sign in again. | The account is active and can sign in with its profile role. |  |  |
| Admin invite and set-password | As Admin, invite a new allowed-domain user with a non-Admin role; open the invite link and set a password. | A real Auth user and active approved profile are created, an invitation email is sent, and the assigned role is enforced. |  |  |
| Forgot password | Request a reset from Login, use the email link, enter and confirm a new password. | The recovery view appears, password update succeeds, and the user returns to sign-in. |  |  |
| Role change while logged in | Keep a user signed in while an Admin changes that profile's role. | Realtime/token refresh applies the new role and navigation, or access is ended if the profile is no longer active. |  |  |
| Last-Admin protection | With one active Admin remaining, attempt to deactivate, demote, or delete that account. | Each operation is rejected; at least one active Admin remains. |  |  |
| Assistant account administration | Sign in as Assistant and review a pending application; approve it with an allowed role and inspect active-user management. | Assistant can perform the documented day-to-day approval and user-management actions. Admin-only protections still preserve the distinct Admin role and at least one active Admin. |  |  |

## Role access and work scope

| Test case | Steps | Expected | Actual | Pass/Fail |
|---|---|---|---|---|
| Public access without account | As a signed-out visitor, open report submission, report tracking, facility issues, and public evaluation. | Public report and tracking flows work without sign-in; tracking exposes only limited status information, not personal details or internal remarks. |  |  |
| Employee access and data scope | Sign in as Employee; inspect Dashboard, Submit Request, Requisitions, Reports, Profile, Settings, and Evaluation. Try to view another employee's request. | Employee can submit and view their own requests and access the Employee pages; other users' requests are not visible or accessible. Employee cannot assign work or manage accounts. |  |  |
| Personnel access and data scope | Sign in as Personnel with assigned and unassigned work available; inspect Dashboard, Reports, Requests, Tasks, Profile, and Settings. Attempt to open and update unassigned work. | Personnel can access assigned work and reports they personally submitted; unassigned work and protected requester/assignment fields cannot be read or changed. Personnel cannot assign work, manage accounts, or verify completed work. |  |  |
| Personnel work progression | As Personnel, accept an assigned report, mark it In Progress, submit completion with optional photos, then open a returned item and resubmit it. | Only assigned work can be progressed; completion moves the item to For Verification, and returned work can be resubmitted. |  |  |
| Assistant operational access | Sign in as Assistant; inspect Dashboard, Submit Report, Reports, Requests, Admin Panel, Activity Log, User Management, Profile, Settings, and Evaluation Results. | Assistant can review and assign work, manage locations and preventive-maintenance schedules, manage accounts, view activity and analytics, and view aggregate evaluation results. |  |  |
| Admin operational access | Repeat the Assistant operational-access checks as Admin; verify the first/last-Admin safeguards separately. | Admin has the documented administrative functions; protections prevent removal or demotion of the last active Admin. |  |  |
| Verification and rework | As Assistant or Admin, verify completed work, then separately reject completed work with a reason; sign in as assigned Personnel. | Verification closes the work item. Rejection requires a reason and returns it for rework; Personnel can see the reason and continue the assigned workflow. |  |  |
| Direct access denial | As Employee and Personnel, navigate directly to Admin Panel, User Management, Activity Log, and Evaluation Results; also attempt a disallowed server-side operation. | Restricted pages/actions are denied even when opened directly; server-side authorization rejects unauthorized changes. |  |  |
| Student role compatibility | If a Student profile exists, sign in and test navigation, direct page access, report submission, and feedback. | Record actual behavior and compare it with the approved role policy before release. The README describes limited Student report/feedback access, but the current app access map does not define Student pages. |  |  |
| Evaluation role compatibility | Test UTAUT and ISO/IEC 25010 evaluation submission as Public and Employee; test evaluation-results access as Assistant and Admin. | Public and Employee can submit all UTAUT-construct and quality-characteristic ratings; Assistant and Admin can view aggregate means and counts only. Other roles cannot submit through the public evaluation endpoint. |  |  |

## Notes for interpreting results

- The current app role map gives Employee access to Dashboard, Submit Request,
  Requisitions, Reports, Profile, Settings, and Evaluation; Personnel access to
  Dashboard, Reports, Requests, Tasks, Profile, and Settings; and Admin and
  Assistant the same administrative pages.
- The project documentation describes Student report/feedback access, but
  Student is not included in the app's role-page access map. Do not mark this
  workflow passed until expected Student access is agreed and implemented.
- The current app evaluation rules allow submission for Public and Employee;
  Assistant and Admin can view results, while Personnel has no evaluation page.
  This differs from some role manuals and the README role matrix. Confirm the
  intended policy, then update the app or documentation before sign-off.
