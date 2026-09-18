# Secretly Privacy Policy and Terms of Service

Effective date: April 29, 2026

Operator: Secretly

Official website: https://www.secretlyapp.com

Privacy Policy URL: https://www.secretlyapp.com/privacy-policy

Terms of Service URL: https://www.secretlyapp.com/terms-of-service

Privacy, support, deletion, abuse-reporting, and legal notices: technical.support@secretlyapp.com

Product: Secretly, a private messenger application for mobile and desktop devices.

This document contains the public Privacy Policy and Terms of Service for Secretly. It is written to match the current app and server behavior as of the effective date above. If the shipped app, server configuration, permissions, subprocessors, or payment flows change, this document must be reviewed before publication or store submission.

---

# Privacy Policy

## 1. Overview

Secretly is designed as a private messenger. The app uses client-side encryption for messages so that, in normal operation, Secretly servers relay encrypted message payloads and do not receive message plaintext.

This Privacy Policy explains what information Secretly processes, how that information is used, what is stored locally on your device, what may be processed by Secretly servers and service providers, and what choices you have.

This Policy applies to Secretly apps, websites, APIs, key services, relay services, notification services, support channels, and related services that link to this Policy.

For data-protection purposes, Secretly is the controller of personal information processed for the Secretly service unless a specific third-party provider acts as an independent controller under its own terms.

## 2. Summary

- We do not sell personal information.
- We do not use third-party advertising SDKs in the current app codebase.
- We do not use Firebase Analytics or Crashlytics in the current app dependency list.
- Message content is encrypted on your device before transit. Servers are designed to relay opaque ciphertext and delivery metadata.
- Secretly still processes the metadata needed to operate the service, including profile IDs, device IDs, public key material, delivery state, push tokens, room and call signaling metadata, request metadata, and abuse-prevention data.
- Local chat history, contacts, media caches, settings, and keys are stored on your device. The local database is designed to be encrypted at rest.
- You can delete your account and associated server-side profile data in the app through Settings > Account > Delete account.
- Optional support requests can include your message to support, optional name/email, build marker, Secretly profile ID, and Secretly device ID.
- Optional donations are handled by Donorbox or the payment provider opened from the app. Secretly does not process card details inside the app.

## 3. Information We Process

### 3.1 Account, Profile, and Device Identifiers

Secretly may process:

- Secretly profile ID and device ID.
- Public identity keys, public device keys, signed prekeys, one-time prekeys, and related signatures used to establish encrypted sessions.
- Profile secret verification material and signed request metadata used to authenticate requests.
- Public profile metadata you choose to publish, such as nickname, avatar, bio, profile media references, discoverability settings, privacy audience settings, and last-active visibility settings.
- Device registration records and device metadata needed to sync an account across devices.
- Inactivity deletion settings and last-active timestamps used for automatic profile cleanup.

### 3.2 Messages, Attachments, and User Content

Secretly allows users to create, send, receive, and store messages, media, files, voice messages, call signals, room messages, profile media, and other user-generated content.

In normal operation, message plaintext is encrypted on your device before being sent. Relay servers store and forward encrypted payloads and metadata needed for delivery, such as sender and recipient device IDs, message IDs, delivery sequence numbers, timestamps, time-to-live values, encrypted payload sizes, and transport metadata.

Attachments and media may be uploaded to relay storage as encrypted or access-controlled blobs. The relay may process blob IDs, size, owner identifiers, access tokens or token hashes, creation times, expiration times, and storage paths.

### 3.3 Calls and Real-Time Communication

Secretly supports audio and video calls.

For one-to-one calls, Secretly uses WebRTC signaling and transport security. For room or group calls, Secretly may use LiveKit, TURN, STUN, or similar media infrastructure. These systems process call signaling metadata, room IDs, participant identifiers, call state, media type, access tokens, timestamps, and network routing data. Media providers and relay infrastructure may process media transport data needed to connect calls.

Secretly is not a telephone replacement and does not connect to public emergency services. Do not use Secretly for emergency calls.

### 3.4 Contacts and Address Book Data

Secretly lets you add contacts by QR code, profile links, requests, and other in-app flows.

If you enable device contact sync, Secretly may request access to your device contacts. The current implementation uses contact access to create, update, read, and remove contacts that Secretly manages in your device address book. Managed contacts include a Secretly profile link marker. The current implementation is designed to avoid uploading your full device address book to Secretly servers.

You can disable contact sync and revoke contact permission in your device settings.

### 3.5 Photos, Videos, Camera, Microphone, and Files

Secretly may access camera, microphone, photo library, media library, and selected files only when you use features that need them, such as QR scanning, profile avatars, chat attachments, voice messages, audio calls, and video calls.

Selected media may be processed locally, encrypted for messaging, cached locally, or uploaded as encrypted or access-controlled blobs for delivery. Camera and microphone streams are used for calls and are not used for advertising.

### 3.6 Notifications and Push Tokens

Secretly uses push notifications to wake the app and deliver call and message events. Push payloads are designed not to include message plaintext. After a wake event, the app fetches encrypted payloads and decrypts them locally before showing user-visible notification text.

We may process FCM tokens, APNs tokens, VoIP push tokens, device IDs, notification settings, notification privacy settings, delivery hints, and token health data. Google Firebase Cloud Messaging and Apple Push Notification service process push data under their own terms and privacy policies.

### 3.7 Local Security and Authentication Data

Secretly may use platform security features such as Android Keystore, iOS Keychain, biometric unlock, and secure storage. Secretly does not receive your biometric face or fingerprint templates. Biometric checks are performed by your operating system.

The local app database is designed to be encrypted at rest. Recovery kits and safe backups are encrypted client-side using a passphrase-derived key. If you lose your recovery password or device keys, Secretly may be unable to recover your plaintext data.

### 3.8 Support, Deletion, and Abuse Reports

If you contact support, request deletion, or report abuse, we process the information you provide. The current support flow can include:

- Your support message or report.
- Optional name and email address.
- Build marker.
- Secretly device ID.
- Secretly profile ID.
- Any screenshots, exported evidence, logs, timestamps, or other details you choose to include.

Do not send sensitive message plaintext, passwords, private keys, recovery passwords, payment card details, or unrelated private data to support.

### 3.9 Donations and Payments

Secretly may link to Donorbox or other third-party donation/payment pages. Payment card details, wallet credentials, and donation payment processing are handled by the payment provider, not by Secretly inside the app. We may receive donation confirmation details from the provider if the provider makes them available to us.

Donations are voluntary and do not unlock in-app digital goods unless a separate written offer says otherwise.

### 3.10 Technical, Security, and Operational Data

We may process IP addresses, request timestamps, HTTP headers, rate-limit counters, nonces, signatures, token bucket data, error logs, server health data, abuse-prevention data, and diagnostics needed to run, secure, debug, and improve the service.

Server logs should be configured to minimize sensitive data. Some logs may include fingerprints, truncated identifiers, sizes, status codes, or metadata needed for troubleshooting and security.

## 4. How We Use Information

We use information to:

- Provide encrypted messaging, attachment delivery, calls, rooms, notifications, backups, profile discovery, device linking, and account recovery.
- Authenticate devices and protect against unauthorized access, replay attacks, spam, abuse, and service misuse.
- Route encrypted payloads to intended recipients.
- Maintain block lists, room membership, invites, call state, delivery state, read receipts, and notification preferences.
- Provide support and respond to privacy, deletion, abuse-reporting, and legal requests.
- Maintain service reliability, security, diagnostics, and legal compliance.
- Enforce the Terms of Service and protect users, the public, and Secretly.

## 5. Legal Bases Where Required

Where data-protection law requires a legal basis, we rely on one or more of the following:

- Contract: to provide the Secretly service you request.
- Consent: for optional permissions, notifications, contact sync, support submissions, and certain optional features.
- Legitimate interests: to secure, debug, prevent abuse, maintain, and improve the service.
- Legal obligation: to comply with applicable laws, valid legal requests, tax, accounting, sanctions, and safety obligations.
- Vital interests or public interest: where legally applicable in exceptional safety situations.

## 6. End-to-End Encryption and Metadata

Secretly is designed so message plaintext is encrypted on your device and decrypted on recipient devices. Servers are not designed to read message plaintext in normal operation.

However, encryption does not hide all data. To operate the service, Secretly and its providers may process metadata, including:

- Profile IDs and device IDs.
- Public key bundles and device registration status.
- Sender and recipient routing information.
- Message IDs, delivery sequence numbers, timestamps, TTL values, and encrypted payload sizes.
- Room IDs, membership, invite links, roles, call state, and call media type.
- Push tokens and notification delivery metadata.
- IP addresses and network-level metadata observed by servers and providers.

Recipients can copy, screenshot, forward, export, report, or disclose content they receive. Encryption cannot prevent actions by a recipient or by software running on a compromised device.

## 7. Sharing and Service Providers

We do not sell personal information. We may share or process information with:

- Hosting and infrastructure providers that run Secretly keys, relay, proxy, TURN/STUN, and related services.
- Google Firebase Cloud Messaging for Android push delivery and Firebase installation/messaging services.
- Apple Push Notification service, PushKit, CallKit, and iOS system services for notifications and call integration.
- LiveKit or compatible media infrastructure for room and group calls where enabled.
- Donorbox and payment providers for voluntary donations.
- Email providers, user mail clients, and support tooling when you contact support, request deletion, or report abuse.
- Operating system providers and device platform services, such as Android Keystore, iOS Keychain, biometric APIs, contacts APIs, notification APIs, camera, microphone, and file pickers.
- Legal, compliance, security, or professional advisors where necessary.
- Authorities or third parties when required by law, valid legal process, or to protect rights, safety, users, or the service.

We require service providers to process information for the purposes described in this Policy and according to applicable law.

## 8. Retention

Retention depends on the data category and feature.

- Local app data remains on your device until you delete it, reset the profile, uninstall the app, clear app storage, or the app removes it as part of feature behavior.
- Pending relay messages are stored only as long as needed for delivery and until their configured TTL expires or they are cleaned up.
- Relay blobs and attachment records are stored until their expiration time or cleanup.
- Message deduplication records, call sessions, and room call sessions are retained for operational TTLs and cleanup windows.
- Push tokens are retained until replaced, disabled, deleted, or no longer needed.
- Profile, device, key bundle, public profile metadata, encrypted backup, block list, room, invite, and membership records may remain while the profile or room exists and as needed to provide the service.
- Inactivity deletion settings may delete inactive keys-service profiles and associated key-service records after the selected inactivity period. The current app default is 24 months, and the setting is clamped between 1 and 24 months.
- Support emails, deletion requests, abuse reports, and related records are retained as long as needed to respond, maintain request history, resolve disputes, secure the service, enforce policies, and meet legal obligations.
- Some logs, backups, caches, and legal records may persist for limited periods after deletion where necessary for security, fraud prevention, disaster recovery, legal compliance, or legitimate business records.

## 9. Account Deletion and User Choices

You can control many features in the app, including notification privacy, contact sync, block lists, nickname sharing, profile discoverability, privacy audience settings, local reset, and inactivity deletion timing.

You can delete your Secretly account in the app:

1. Open Settings.
2. Open Account.
3. Select Delete account.
4. Confirm the deletion. If app lock is configured, Secretly will ask you to unlock before continuing.

The in-app account deletion flow is designed to delete server-side data associated with your Secretly profile and current account identity, including key-service profile records, device registrations, published public keys, public profile metadata, encrypted backup records where applicable, relay routing state, pending delivery queues, push-token associations, blob/access records owned by the profile where applicable, block records, and room/call operational state tied to the deleted profile where the server can identify it.

After server deletion succeeds, Secretly resets local data on the current device, including local chats, contacts, requests, local databases, media caches, stored local secrets, device key material, and local app state associated with the deleted profile.

Deletion cannot remove copies already delivered to recipients, recipient screenshots or exports, content other users independently store, data on devices that are offline and not under your control, app-store records, payment provider records, or records that must be retained for legal, security, fraud-prevention, dispute, tax, or compliance reasons.

If you cannot access the in-app deletion flow, contact technical.support@secretlyapp.com from an email address you control and include your Secretly profile ID if available. We may require verification that you control the profile or device before processing a deletion request.

## 10. Your Rights

Depending on your location, you may have rights to access, correct, delete, export, restrict, or object to processing of your personal information. You may also have the right to withdraw consent and to complain to a data-protection authority.

To make a request, contact technical.support@secretlyapp.com. We may need information to verify your request. Because Secretly is designed not to know message plaintext, we may be unable to access, correct, export, or recover encrypted message content that only exists on your device or recipient devices.

## 11. International Transfers

Secretly and its providers may process information in countries other than your country of residence. Where required, we use appropriate safeguards for international transfers, such as contractual protections and other lawful transfer mechanisms.

## 12. Children

Secretly is not intended for children under 13, or under the age required by local law to consent to online services. Do not use Secretly if you are not old enough to consent or if your parent or guardian has not provided any required permission. We do not knowingly collect personal information from children where prohibited. If you believe a child provided information to Secretly, contact us.

## 13. Security

We use technical and organizational safeguards designed to protect information, including transport security, signed requests, replay protection, rate limits, local database encryption, secure storage, and client-side encryption for messages.

No service is perfectly secure. Your security also depends on your device security, operating system, password strength, recovery password, and how you handle contacts, backups, screenshots, exported files, and received content.

## 14. Changes to This Policy

We may update this Policy from time to time. If changes are material, we will take reasonable steps to notify users, such as updating the effective date, publishing the new Policy, or providing in-app notice where appropriate.

## 15. Contact

For privacy, support, deletion, abuse-reporting, or legal requests, contact:

technical.support@secretlyapp.com

Secretly

https://www.secretlyapp.com

---

# Terms of Service

## 1. Acceptance

These Terms of Service govern your access to and use of Secretly. By installing, accessing, or using Secretly, you agree to these Terms and the Privacy Policy. If you do not agree, do not use Secretly.

If you use Secretly on behalf of an organization, you represent that you have authority to bind that organization.

## 2. The Service

Secretly provides private messaging, encrypted message delivery, contacts, rooms, profile features, audio and video calls, notifications, backups/recovery, device linking, account deletion tools, and related features.

Secretly may change, suspend, limit, or discontinue features at any time, including for security, maintenance, legal, operational, or abuse-prevention reasons.

## 3. Eligibility

You must be at least 13 years old, or the minimum age required by your local law, to use Secretly. If you are under the age of majority where you live, you must have permission from a parent or legal guardian.

You may not use Secretly if you are legally barred from using it, if applicable sanctions prohibit use, or if we previously terminated your access for serious violations.

## 4. Your Account, Devices, and Recovery

Secretly identities are based on cryptographic profile and device keys. You are responsible for:

- Keeping your devices secure.
- Protecting passcodes, biometrics, recovery passwords, and recovery kits.
- Maintaining access to devices or backups needed to recover your data.
- Reviewing contact verification, QR codes, and safety indicators where available.
- Understanding that losing keys, passwords, backups, or devices may permanently prevent recovery of plaintext data.

You must not attempt to register devices, publish keys, access profiles, or use tokens you do not control.

## 5. User Content

You are responsible for the messages, media, files, profile information, room content, calls, and other content you create, send, upload, or share through Secretly.

You represent that you have the rights needed to send or share your content and that your content and conduct comply with these Terms and applicable law.

Secretly does not claim ownership of your user content. You grant Secretly the limited rights needed to operate the service, including transmitting, routing, storing, caching, displaying, and delivering encrypted payloads, profile metadata, attachments, and related operational data.

Because Secretly is designed for encrypted communications, we may be unable to view message plaintext or proactively moderate encrypted message content. We may still act on metadata, user reports, support submissions, public profile data, room metadata, abuse signals, and legal requests.

## 6. Acceptable Use

You must not use Secretly to:

- Violate any law or regulation.
- Harm, threaten, harass, stalk, exploit, impersonate, defraud, or abuse others.
- Share or facilitate child sexual abuse material, sexual exploitation, non-consensual intimate imagery, human trafficking, or abuse of minors.
- Promote, plan, or coordinate violence, terrorism, or credible threats of physical harm.
- Distribute malware, phishing, spam, scams, credential theft, or unauthorized access tools.
- Infringe intellectual property, privacy, publicity, or other rights.
- Evade blocks, rate limits, security controls, sanctions, or enforcement actions.
- Interfere with, overload, probe, reverse engineer, attack, scrape, or disrupt the service except as allowed by a written security testing policy.
- Use Secretly for emergency services, life-safety communications, or regulated communications where failure could cause injury or legal harm.

We may investigate and act against misuse, including blocking, limiting, suspending, deleting, or reporting activity where legally permitted or required.

## 7. Blocking, Reporting, and Safety

Secretly includes blocking features. Blocking may be enforced locally and server-side so blocked profiles cannot deliver messages or access certain blobs from the blocking profile.

To report abuse, contact technical.support@secretlyapp.com and include the profile ID, device information if available, timestamps, screenshots, exported evidence, or other details you are legally permitted to share. Do not include private keys, recovery passwords, or unrelated private data.

Because we may not be able to read encrypted messages, reports may require user-provided evidence. We may not be able to take action if we cannot verify a report or identify the relevant account, profile, or device.

## 8. Notifications, Calls, and Availability

Notifications, calls, and message delivery depend on device state, network conditions, operating system restrictions, push providers, battery settings, contacts' devices, servers, and third-party infrastructure. Delivery may be delayed, fail, duplicate, or expire.

Secretly is not an emergency calling service. You must use your mobile carrier, local telephone service, or emergency service provider for emergency calls.

## 9. Backups and Recovery

Secretly may offer recovery kits and safe backups. Backups are designed to be encrypted before storage. You are responsible for keeping recovery passwords and files safe.

We cannot guarantee recovery if you lose your password, recovery kit, device keys, or access to your devices. We may not be able to decrypt, restore, or inspect your data.

## 10. Donations and Third-Party Payments

Secretly may provide links to Donorbox or other third-party donation pages. Donations are voluntary and do not purchase in-app digital goods unless expressly stated in a separate written offer.

Payment processing, refunds, chargebacks, tax receipts, wallet buttons, and card handling are governed by the payment provider's terms. Secretly does not process payment card details inside the app.

If app store rules require a different payment flow for a particular feature, Secretly may change or remove donation/payment links for that platform.

## 11. Third-Party Services

Secretly relies on third-party platforms and services, including operating systems, app stores, push providers, hosting providers, media relay providers, and payment providers. Your use of those services may be governed by their own terms and privacy policies.

We are not responsible for third-party services outside our control, but we use reasonable care when integrating them.

## 12. App Stores

If you obtained Secretly from the Apple App Store, Google Play, or another app store, the store provider is not responsible for Secretly except as required by its own terms. The store provider may be a third-party beneficiary of these Terms where required by store rules.

For Apple App Store downloads, these Terms are between you and Secretly, not Apple. Apple is not responsible for maintenance or support for Secretly, except as required by applicable law. If these Terms are less restrictive than Apple's standard Licensed Application End User License Agreement, Apple's standard terms apply to the extent required by Apple.

## 13. Updates and Beta/Pre-Release Features

Secretly may include beta, experimental, or pre-release features. These features may be unstable, incomplete, changed, or removed without notice.

You agree to install updates needed for security, compatibility, legal compliance, or continued service operation. Older app versions may stop working.

## 14. Intellectual Property

The Secretly source code is copyright Yurii Arkhanhelskyi and is released as free software under the GNU Affero General Public License version 3, with an additional permission for application stores. The licence text and that permission travel with the source code, and nothing in these Terms limits the rights it grants you.

The Secretly name, logo and application icons are trademarks and are not covered by that licence. Branding, designs and service infrastructure remain the property of their respective owners and are protected by intellectual property laws.

Subject to your compliance with these Terms, we grant you a limited, personal, non-exclusive, non-transferable, revocable license to install and use Secretly for lawful personal or internal business communications.

Because the source code is licensed under the AGPL, you may copy, modify, distribute and create derivative works from it on the terms of that licence — including running a modified version as a service, provided you offer its source to its users. These Terms do not take any of that away. What they do restrict is the use of our name and logo, and access to the servers we operate: a fork is welcome, but it is published under its own name and runs on its own infrastructure.

## 15. Suspension and Termination

You may stop using Secretly at any time. You may delete local data through device settings, in-app reset, or available deletion tools. You may delete your account through Settings > Account > Delete account.

We may suspend, limit, or terminate access if we reasonably believe:

- You violated these Terms.
- Your activity creates risk, abuse, security issues, or legal exposure.
- We are required to do so by law, court order, app store policy, sanctions, or provider requirements.
- Continuing service is no longer commercially, technically, legally, or operationally feasible.

Termination may not remove content already delivered to recipients or retained by third parties, recipients, backups, logs, or legal records.

## 16. Disclaimers

To the maximum extent permitted by law, Secretly is provided "as is" and "as available." We disclaim warranties of merchantability, fitness for a particular purpose, non-infringement, availability, accuracy, security, uninterrupted operation, and error-free operation.

We do not guarantee that messages, calls, notifications, backups, recovery, contact sync, room features, account deletion propagation, or attachments will always work, be delivered, be recoverable, or remain available.

Some jurisdictions do not allow certain disclaimers, so some disclaimers may not apply to you.

## 17. Limitation of Liability

To the maximum extent permitted by law, Secretly, its owners, officers, employees, contractors, affiliates, suppliers, and licensors will not be liable for indirect, incidental, special, consequential, exemplary, or punitive damages, or for lost profits, lost data, lost goodwill, business interruption, security incidents, device compromise, failed delivery, failed recovery, or unauthorized access.

To the maximum extent permitted by law, our total liability for all claims relating to Secretly will not exceed the greater of: (a) the amount you paid directly to Secretly for the service in the 12 months before the claim, or (b) USD $100.

Nothing in these Terms limits liability that cannot be limited by law.

## 18. Indemnity

To the maximum extent permitted by law, you agree to defend, indemnify, and hold harmless Secretly and its owners, officers, employees, contractors, affiliates, suppliers, and licensors from claims, damages, losses, liabilities, costs, and expenses arising from your use of Secretly, your content, your violation of these Terms, your violation of law, or your violation of another person's rights.

## 19. Governing Law and Disputes

These Terms are governed by the laws applicable to the Secretly operator, excluding conflict-of-law rules, unless mandatory consumer law gives you additional rights or requires another forum.

Before filing a claim, you agree to contact us at technical.support@secretlyapp.com and give us a reasonable opportunity to resolve the issue informally.

Nothing in these Terms limits rights you may have under mandatory consumer-protection, privacy, or platform laws.

## 20. Changes to Terms

We may update these Terms. If changes are material, we will take reasonable steps to notify users. Continued use after the effective date means you accept the updated Terms.

## 21. Contact

For Terms, support, privacy, deletion, abuse-reporting, or legal notices, contact:

technical.support@secretlyapp.com

Secretly

https://www.secretlyapp.com