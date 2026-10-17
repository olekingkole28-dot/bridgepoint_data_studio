# Security policy

## Reporting a vulnerability

Please do not publish exploitable vulnerabilities, credentials, private URLs, personal
data, or account details in a public issue or pull request.

Report suspected vulnerabilities through GitHub's private vulnerability reporting feature
for this repository, when available, or email **bridgepointintelligence@gmail.com** with
the subject `BridgePoint security report`. The address is also published in the site's
security contact file:
https://bridgepointintelligence.online/.well-known/security.txt

Include the affected repository/file, impact, reproducible steps, and a safe proof of
concept. Redact tokens, customer details, precise private property information, and
unnecessary personal data.

## Secret-handling rules

- Never commit Supabase service-role/secret keys, database passwords, signing material,
  private API tokens, or real environment files.
- Web and Flutter clients must not contain server-only credentials.
- Use development-only projects for testing and keep production credentials in a secret
  manager or hosting-provider secret store.
- If a credential may have been exposed, revoke/rotate it immediately; removing it from a
  later commit does not remove it from Git history.
- Treat production database rows and customer/account activity as private by default.

## Scope and limits

This policy does not grant permission to access systems or data. Test only systems you own
or have explicit authorization to assess. Do not use real customer records as a test fixture.
