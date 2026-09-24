# Consultant

[简体中文](README.zh-CN.md)

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

Requires Python 3.9+ on macOS, Linux, or Windows and a Codex CLI supporting the checked flags. Uses only Python's standard library. On Windows, install the native `codex.exe` CLI; `.cmd`, `.bat`, and PowerShell wrappers are refused.

```sh
sh ~/.codex/skills/consultant/scripts/run_consult.sh --packet-file /path/to/private-packet.json
```

On macOS/Linux, this launcher prefers `python3` and falls back to `python` only when it is Python 3.9 or newer. It reports a clear error if neither works. It passes all arguments and stdin unchanged to `consult.py`; no shell alias is needed. You may also invoke `consult.py` directly with a known Python 3.9+ interpreter.

On Windows PowerShell, with the skill installed at `%USERPROFILE%\.codex\skills\consultant`, select a Python 3.9+ interpreter before invoking the helper:

```powershell
$skillHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$consultScript = Join-Path $skillHome 'skills\consultant\scripts\consult.py'
$python = $null
$pythonArgs = @()
foreach ($candidate in @(
    @{ Name = 'py.exe'; Prefix = @('-3') }
    @{ Name = 'python3.exe'; Prefix = @() }
    @{ Name = 'python.exe'; Prefix = @() }
)) {
    $found = Get-Command $candidate.Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $found) { continue }
    $executable = $found.Source
    $prefix = $candidate.Prefix
    try { & $executable @prefix -c 'import sys; sys.exit(sys.version_info < (3, 9))' *> $null }
    catch { continue }
    if ($LASTEXITCODE -eq 0) { $python = $executable; $pythonArgs = $prefix; break }
}
if (-not $python) { throw 'Python 3.9+ is required; py, python3, and python were unavailable or too old.' }
& $python @pythonArgs $consultScript --packet-file 'C:\path\to\private-packet.json'
```

The PowerShell example tries `py.exe -3`, then `python3.exe`, then `python.exe`; a candidate is used only if its version probe succeeds. It runs inline, so no PowerShell script execution policy change is needed. The helper looks for `codex.exe` on `PATH`. If it is elsewhere, pass `--codex-bin 'C:\path\to\codex.exe'`. Keep the packet file private and delete it after use.

Without `--packet-file`, the helper reads JSON from stdin. The six supported string fields are `task`, `question`, `proposed_approach`, `context`, `previous_attempts`, and `constraints`; `task` and `question` are required. Maximum input is 32 KiB. Use a private file and delete it afterward. Never place credentials in the packet.

Options: `--model MODEL`, `--auth-mode auto|chatgpt|api` (default `auto`), `--codex-bin PATH`, `--timeout SECONDS` (1–900; default 240). Success returns Markdown advice on stdout; stderr contains safe status information. Failures never print raw nested logs. Nonzero exit codes: 2 input, 3 authentication or ambiguous billing route, 4 missing CLI, 5 compatibility/recursion, 6 execution/model/allowance, 7 timeout, 8 empty response, 9 permissions/connectivity/local access, 10 output limits/format, 11 possible secret. Cancellation exits 130.

The wrapper launches an argument array through `subprocess.Popen`, with no shell. The packet travels through stdin. It uses an ephemeral temporary working directory, a read-only sandbox, no approval prompts, a dedicated advisor instruction file, and `--output-last-message`. The helper bounds diagnostics and the final response, stops descendants on timeout/cancellation, and removes its temporary files. macOS/Linux use a dedicated process group. Windows uses a [kill-on-close Job Object](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects) and a gated launcher: Codex starts only after the launcher has joined the job. Job assignment failure stops the consultation before Codex is released. This is process cleanup, not a security sandbox.

Tool isolation uses the installed CLI's bundled model catalog. A temporary copy of only the selected model's metadata disables code-mode tools, patching, delegation, search, and experimental tools. Its model identifier remains unchanged. Feature flags additionally disable shell, plugins, MCP apps, hooks, skills, and other tools. This avoids a tested behavior where Astra's model metadata overrides disabled feature flags. No persistent catalog or settings are changed.

## Authentication and usage

The helper reuses the existing Codex CLI login (check with `codex login status`) or an inherited `CODEX_API_KEY` intended for a single CLI execution. It preserves the existing `CODEX_HOME` and uses Codex's `auto` credential store (OS credential store where available, otherwise the existing `auth.json`). It does not read or copy stored credential values itself. In-memory-only login is not reusable across separate processes.

The child receives a small allowlist of OS, proxy, and CA variables. It never receives `OPENAI_API_KEY`, alternate provider endpoint variables, or arbitrary environment secrets. It receives `CODEX_API_KEY` only when API mode is selected and that variable is present; the key is never placed in arguments, prompts, or logs. The helper forces the built-in OpenAI provider and the chosen authentication method. User model/provider configuration is ignored for this one invocation. It does not modify your configuration.

`--auth-mode auto` uses these rules:

| Available credentials | Selected route |
| --- | --- |
| Saved ChatGPT login only | ChatGPT subscription/credits |
| Saved API-key login only | API key |
| `CODEX_API_KEY` without a saved login, or alongside saved API-key login | API key (the environment key takes priority) |
| `CODEX_API_KEY` alongside saved ChatGPT login | Stop; specify `--auth-mode` |
| No supported credentials | Stop |

Use `--auth-mode chatgpt` when the primary session is known to use the subscription. It requires a saved ChatGPT login and removes any `CODEX_API_KEY` from the child. Use `--auth-mode api` when the primary session is known to use API-key billing. It requires a saved API-key login or `CODEX_API_KEY`. A key in `OPENAI_API_KEY` alone is not passed to `codex exec`; use the documented `CODEX_API_KEY` or first sign in to Codex with an API key. Neither mode falls back to the other if authentication or usage fails.

For example, when an API-key parent session was started with `CODEX_API_KEY`, invoke the helper with `--auth-mode api`. When the parent uses ChatGPT login and the shell also happens to contain `CODEX_API_KEY`, invoke it with `--auth-mode chatgpt`; the helper keeps that key out of the child process. Never put an API key in a packet or CLI argument.

The wrapper cannot inspect the primary Codex thread's actual authentication method. Automatic selection is an inference from available CLI credentials, not proof of the parent's billing route. If those credentials conflict, explicitly choose the known route instead of risking unexpected charges. OpenAI documents [ChatGPT versus API-key authentication](https://learn.chatgpt.com/docs/auth) and [`CODEX_API_KEY` for one non-interactive execution](https://developers.openai.com/codex/noninteractive). ChatGPT usage follows the signed-in account's Codex allowance and applicable credits; API-key usage follows API billing. Both consume usage, and the wrapper cannot attribute an exact charge to one consultation.

## Limitations

- Advice only sees the selected packet and can be wrong or miss omitted context. The main agent must validate it against the repository and state agree, partially agree, or disagree.
- Secret detection is heuristic, with possible false positives and false negatives. Redact manually; no secret filter can guarantee completeness. Potential secrets in output cause that output to be withheld.
- A temporary directory and read-only mode do not constitute a separate container or a filesystem confidentiality boundary. Tool and instruction isolation are configured for the tested CLI, and may need review after updates.
- This CLI still loads global `CODEX_HOME/AGENTS.md` or `AGENTS.override.md` when user configuration is ignored. The helper refuses to run if either is nonempty, rather than send unexpected instructions. Do not delete global instructions to work around this; supporting those installations requires further CLI isolation work. This installation has an empty `AGENTS.md`.
- Consultant models must exist in the CLI's bundled catalog as well as be available to your account. A newly launched model may require a CLI update. The temporary catalog preserves model identity and capability metadata except for tool exposure; it is an implementation detail tied to the verified CLI version.
- `--ephemeral` prevents session rollouts; it does not promise zero CLI cache/auth-refresh/diagnostic activity or alter OpenAI's service-side retention policies. The helper does not persist packets or replies; the parent task can retain advice in its own transcript.
- The outer Codex sandbox can block networking or authentication-cache access. The main agent may need ordinary host approval for this specific invocation. The helper never weakens its internal sandbox or asks the user questions itself.
- Managed administrator restrictions still apply. A proxy or credential-store setup that depends on ignored user configuration can need adaptation. On Windows, a host Job Object policy can prevent assignment; the helper fails closed rather than running an uncontained child.
- Enterprise `CODEX_ACCESS_TOKEN` and other workload identities are outside this version's authentication detection; use a saved ChatGPT or API-key login, or `CODEX_API_KEY` for API mode.
- No automatic retries, automatic escalation, billing-mode fallback, model fallback, MCP server, or direct API client is included.

## Uninstall

Remove only `~/.codex/skills/consultant/` (or its custom `CODEX_HOME` equivalent), then refresh/restart Codex if needed. No configuration entries or services need removal.

## Development checks

From the skill's source directory, run `python3 -m unittest discover -s tests -v` for offline subprocess tests. On Windows, select `$python` and `$pythonArgs` with the PowerShell block above, then run `& $python @pythonArgs -m unittest discover -s tests -v`. The suite includes the Windows gate and supervisor tests; the native Job Object test runs only on Windows. `python3 tests/check_cli_isolation.py` checks the real CLI's tool and skill isolation through a local capture server. `python3 tests/check_cli_api_auth.py` checks saved and environment API-key routes using disposable synthetic keys and a loopback server, with no live model request. Add `--test-conflict-with-current-login` only when the local CLI has a saved ChatGPT login and you want to verify an explicit API choice in that situation. These loopback checks may need local socket permission.
