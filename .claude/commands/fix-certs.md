---
manifest:
  id: fix-certs
  purpose: Diagnose and fix TLS certificate issues caused by Cloudflare WARP VPN — runs the substrate's `--check` mode for diagnosis, builds the combined CA bundle if missing, and emits the env-var exports the operator can `eval` or append to their shell profile.
  routes-by: /fix-certs
  input:
    - "no positional args"
  output:
    - "stdout: shell-ready export lines (eval-able)"
    - "side-effect: ~/.cloudflare-certs/combined-ca-bundle.pem and standalone cert created when missing"
  depends-on:
    - fix-cloudflare-certs.sh
  side-effect:
    - writes-cert-bundle
  failure-mode:
    - "cf-cert-not-in-keychain | exit=1 | visible=stderr-FAIL-with-IT-admin-hint | mitigation=ask-IT-to-install-WARP-root-CA"
  contract:
    - idempotent-on-rerun
    - --check-is-side-effect-free
  anchor:
    - BTS-256 (manifest seed)
---

Diagnose and fix TLS certificate issues caused by Cloudflare WARP VPN.

1. Read `.claude/rules/tls-troubleshooting.md` for full context on the problem and remediation steps.

2. Run the diagnosis first:
   ```bash
   bash .ccanvil/scripts/fix-cloudflare-certs.sh --check
   ```
   If the script doesn't exist in the current project, run the manual steps from the rule file.

3. If the combined bundle doesn't exist or is stale, build it:
   ```bash
   bash .ccanvil/scripts/fix-cloudflare-certs.sh
   ```

4. Set the environment variables for the current session by running each export from the script output.

5. If the user reported a specific tool failing (pip, npm, git, cargo, etc.), retry the failing command with the env vars set.

6. Check if the user's `~/.zshrc` already has the Cloudflare cert exports. If not, suggest making them permanent:
   ```bash
   bash .ccanvil/scripts/fix-cloudflare-certs.sh >> ~/.zshrc
   ```

7. Report what was fixed and what the user should verify.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
