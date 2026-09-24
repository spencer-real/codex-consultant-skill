# Consultant

A manually invoked second opinion: the main Codex agent selects the evidence, a separate Codex CLI process advises, and the main agent evaluates the advice and continues.

## Use

Installed at `~/.codex/skills/consultant/` (or `$CODEX_HOME/skills/consultant/` for a custom Codex home).

```text
$consultant Review the architecture I am planning before I implement it.
$consultant I tried this race-condition fix twice. Review my locking strategy.
$consultant Review this database migration strategy. Consultation only.
```

Explicit invocation is enabled; implicit invocation is disabled in `agents/openai.yaml`. This skill does not change the primary session's model. Select GPT-6 Sol for the main session if desired. Skill changes normally appear automatically; start a fresh task or restart Codex if its catalog is stale.

The default consultant model is `gpt-6-astra`. To override it for a terminal session:

```sh
export CODEX_CONSULTANT_MODEL=gpt-6-sol
```

Restart a desktop app from that environment for it to inherit the variable, or ask the main agent to pass `--model MODEL` for a particular consultation. No fallback to another model occurs automatically. Model access depends on the account and workspace.

## Helper

Requires Python 3.9+ on macOS/Linux and a Codex CLI supporting the checked flags. Uses only Python's standard library.

```sh
python3 ~/.codex/skills/consultant/scripts/consult.py --packet-file /path/to/private-packet.json
```

Without `--packet-file`, the helper reads JSON from stdin. The six supported string fields are `task`, `question`, `proposed_approach`, `context`, `previous_attempts`, and `constraints`; `task` and `question` are required. Maximum input is 32 KiB. Use a private file and delete it afterward. Never place credentials in the packet.

Options: `--model MODEL`, `--codex-bin /path/to/codex`, `--timeout SECONDS` (1–900; default 240). Success returns Markdown advice on stdout; stderr contains safe status information. Failures never print raw nested logs. Nonzero exit codes: 2 input, 3 authentication, 4 missing CLI, 5 compatibility/recursion, 6 execution/model/allowance, 7 timeout, 8 empty response, 9 permissions/connectivity/local access, 10 output limits/format, 11 possible secret. Cancellation exits 130.

The wrapper launches an argument array through `subprocess.Popen`, with no shell. The packet travels through stdin. It uses an ephemeral temporary working directory, a read-only sandbox, no approval prompts, a dedicated advisor instruction file, and `--output-last-message`. The helper bounds diagnostics and the final response, kills the process group on timeout/cancellation, and removes its temporary files.

Tool isolation uses the installed CLI's bundled model catalog. A temporary copy of only the selected model's metadata disables code-mode tools, patching, delegation, search, and experimental tools. Its model identifier remains unchanged. Feature flags additionally disable shell, plugins, MCP apps, hooks, skills, and other tools. This avoids a tested behavior where Astra's model metadata overrides disabled feature flags. No persistent catalog or settings are changed.

## Authentication and usage

Run `codex login`, then `codex login status`; the status must report ChatGPT. The helper preserves the existing `CODEX_HOME` and uses Codex's `auto` credential store (OS credential store where available, otherwise the existing `auth.json`). It does not read or copy credential values itself. In-memory-only login is not reusable across separate processes.

The child receives a small allowlist of OS, proxy, and CA variables. It receives neither `OPENAI_API_KEY` nor `CODEX_API_KEY`, alternate provider endpoint variables, or arbitrary environment secrets. The helper checks the cached login and forces the built-in OpenAI provider with ChatGPT authentication. User model/provider configuration is ignored for this one invocation. It does not modify your configuration.

This uses the signed-in account's ChatGPT/Codex entitlement, including any applicable workspace credits or purchased Codex credits. It creates no separate OpenAI Platform API-key charges and does not promise unlimited or free usage. Nested calls consume additional allowance. OpenAI documents [ChatGPT versus API-key authentication](https://learn.chatgpt.com/docs/auth) and [saved authentication in non-interactive execution](https://learn.chatgpt.com/docs/noninteractive). Check your account's usage UI for actual allowance; the wrapper cannot attribute an exact credit charge to one call.

## Limitations

- Advice only sees the selected packet and can be wrong or miss omitted context. The main agent must validate it against the repository and state agree, partially agree, or disagree.
- Secret detection is heuristic, with possible false positives and false negatives. Redact manually; no secret filter can guarantee completeness. Potential secrets in output cause that output to be withheld.
- A temporary directory and read-only mode do not constitute a separate container or a filesystem confidentiality boundary. Tool and instruction isolation are configured for the tested CLI, and may need review after updates.
- This CLI still loads global `CODEX_HOME/AGENTS.md` or `AGENTS.override.md` when user configuration is ignored. The helper refuses to run if either is nonempty, rather than send unexpected instructions. Do not delete global instructions to work around this; supporting those installations requires further CLI isolation work. This installation has an empty `AGENTS.md`.
- Consultant models must exist in the CLI's bundled catalog as well as be available to your account. A newly launched model may require a CLI update. The temporary catalog preserves model identity and capability metadata except for tool exposure; it is an implementation detail tied to the verified CLI version.
- `--ephemeral` prevents session rollouts; it does not promise zero CLI cache/auth-refresh/diagnostic activity or alter OpenAI's service-side retention policies. The helper does not persist packets or replies; the parent task can retain advice in its own transcript.
- The outer Codex sandbox can block networking or authentication-cache access. The main agent may need ordinary host approval for this specific invocation. The helper never weakens its internal sandbox or asks the user questions itself.
- Managed administrator restrictions still apply. A proxy or credential-store setup that depends on ignored user configuration can need adaptation. Windows is not yet supported.
- No automatic retries, automatic escalation, model fallback, MCP server, or direct API client is included.

## Uninstall

Remove only `~/.codex/skills/consultant/` (or its custom `CODEX_HOME` equivalent), then refresh/restart Codex if needed. No configuration entries or services need removal.
