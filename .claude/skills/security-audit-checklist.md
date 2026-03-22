---
name: security-audit-checklist
description: "Comprehensive security audit checklist: injection, input validation, secrets, auth, crypto, dependencies, data exposure, file operations."
---

# Security Audit Checklist

Apply to every changed file. Every finding MUST include: file, line, severity, description, concrete recommendation.

## Categories

- **INJECTION**: SQL parameterization (no string concatenation), shell argument sanitization (no direct interpolation), HTML escaping (XSS prevention), path canonicalization (no traversal).
- **INPUT VALIDATION**: Boundary/type checking at all entry points, numeric range validation, string length limits, enum/whitelist validation for structured inputs.
- **SECRETS AND CREDENTIALS**: No hardcoded values (API keys, passwords, tokens), no credential logging (even at debug level), vault/env-based storage required, rotation-friendly design.
- **AUTHENTICATION AND AUTHORIZATION**: Auth check on every protected route/endpoint, non-bypassable authorization (middleware, not per-handler), non-predictable session tokens/IDs.
- **CRYPTOGRAPHY**: No deprecated algorithms (MD5, SHA1 for security, DES, RC4), no Math.random()/rand() for security-sensitive values, proper key lengths (AES-256, RSA-2048+).
- **DEPENDENCY SECURITY**: No known CVEs in added/updated dependencies, no version downgrades, lock file updated.
- **DATA EXPOSURE**: No PII/credentials in error responses, no sensitive data in log output, minimal data in stack traces.
- **FILE AND PATH OPERATIONS**: No path traversal (canonicalize before use), file access restricted to intended directories, temp files cleaned up.
