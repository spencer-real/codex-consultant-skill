# Consultant

[English](README.md)

这是一个手动调用的独立技术顾问：主 Codex 智能体挑选相关证据，另一个 Codex CLI 进程提供建议，然后由主智能体评估建议并继续完成任务。

## 使用方法

将技能安装在 `~/.codex/skills/consultant/`；如果使用自定义 Codex 主目录，则安装在 `$CODEX_HOME/skills/consultant/`。

```text
$consultant 在实施前评审我计划采用的架构。
$consultant 我已经两次尝试修复这个竞态条件。请评审我的锁定策略。
$consultant 评审这个数据库迁移方案。只需提供咨询意见。
```

此技能支持显式调用；`agents/openai.yaml` 中禁用了隐式调用。它不会更改主会话使用的模型。如果需要，您可以为主会话另行选择 GPT-6 Sol。技能的修改通常会自动生效；如果技能目录仍显示旧内容，请开启新任务或重启 Codex。

顾问模型默认为 `gpt-6-astra`。如需在当前终端会话中更改：

```sh
export CODEX_CONSULTANT_MODEL=gpt-6-sol
```

要让桌面应用继承这个变量，需要从设置好变量的环境启动应用；也可以让主智能体在某次咨询中传入 `--model MODEL`。程序不会自动回退到其他模型。模型是否可用取决于账户和工作区。

## 辅助程序

需要 macOS、Linux 或 Windows 上的 Python 3.9+，以及支持所检查命令行选项的 Codex CLI。程序只使用 Python 标准库。在 Windows 上，请安装原生 `codex.exe` CLI；不支持 `.cmd`、`.bat` 或 PowerShell 包装程序。

```sh
sh ~/.codex/skills/consultant/scripts/run_consult.sh --packet-file /path/to/private-packet.json
```

在 macOS/Linux 上，启动脚本优先使用 `python3`；仅当 `python` 是 Python 3.9 或更新版本时才回退使用它。如果两个命令都不符合要求，脚本会明确报错。它会原样传递参数和标准输入给 `consult.py`，无需设置 shell 别名。也可以明确指定一个已知的 Python 3.9+ 解释器，直接运行 `consult.py`。

在 Windows PowerShell 中，假设技能安装于 `%USERPROFILE%\.codex\skills\consultant`，先选择 Python 3.9+ 解释器，再调用辅助程序：

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

这个 PowerShell 示例依次尝试 `py.exe -3`、`python3.exe`、`python.exe`，只选择通过版本检查的命令。代码直接在 PowerShell 中运行，无需修改脚本执行策略。辅助程序会在 `PATH` 中查找 `codex.exe`；如果它位于其他目录，请传入 `--codex-bin 'C:\path\to\codex.exe'`。请妥善保护咨询请求文件，并在使用后删除。

不使用 `--packet-file` 时，辅助程序从标准输入读取 JSON。支持六个字符串字段：`task`、`question`、`proposed_approach`、`context`、`previous_attempts` 和 `constraints`；其中 `task` 和 `question` 必填。输入大小上限为 32 KiB。使用私有文件并在完成后删除，切勿将凭据放入咨询请求中。

可选参数：`--model MODEL`、`--auth-mode auto|chatgpt|api`（默认 `auto`）、`--codex-bin PATH`、`--timeout SECONDS`（1–900 秒，默认 240 秒）。成功时在标准输出返回 Markdown 建议，标准错误输出只包含安全的状态信息。失败时不会打印嵌套进程的原始日志。非零退出码：2 表示输入错误；3 表示身份验证失败或计费路径不明确；4 表示找不到 CLI；5 表示兼容性或递归调用问题；6 表示执行、模型或用量限制问题；7 表示超时；8 表示回复为空；9 表示权限、连接或本地访问问题；10 表示输出大小或格式问题；11 表示可能包含秘密信息。取消操作返回 130。

包装程序通过 `subprocess.Popen` 传入参数数组，不使用 shell；咨询请求通过标准输入传递。它使用临时工作目录、只读沙箱、禁止审批提示、专用顾问指令文件和 `--output-last-message`。程序会限制诊断信息和最终回复的大小，在超时或取消时停止子进程及其后代，并删除临时文件。macOS/Linux 使用独立进程组；Windows 使用[关闭句柄时终止进程的 Job Object](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects)和带启动闸门的启动程序：启动程序加入 Job Object 后才会启动 Codex。如果无法加入 Job Object，咨询会在 Codex 启动前停止。这种机制用于清理进程，并非安全沙箱。

工具隔离使用已安装 CLI 随附的模型目录。程序仅临时复制所选模型的元数据，并禁用代码模式工具、补丁、委派、搜索及实验性工具；模型标识保持不变。功能标志也会禁用 shell、插件、MCP 应用、钩子、技能及其他工具。这样做是因为测试发现，Astra 的模型元数据会覆盖已禁用的功能标志。程序不会修改持久化的模型目录或设置。

## 身份验证与用量

辅助程序复用现有的 Codex CLI 登录状态（可用 `codex login status` 查看），或者继承用于单次 CLI 执行的 `CODEX_API_KEY`。它保留现有的 `CODEX_HOME`，并使用 Codex 的 `auto` 凭据存储方式：在可用时使用操作系统凭据存储，否则使用现有的 `auth.json`。辅助程序不会自行读取或复制已保存的凭据值。仅保存在内存中的登录状态无法被独立进程复用。

子进程只接收少量经过允许的操作系统、代理和 CA 环境变量。它不会接收 `OPENAI_API_KEY`、其他提供方的端点变量或任意环境秘密。只有选择 API 模式且存在 `CODEX_API_KEY` 时，子进程才会收到该变量；密钥不会被写入命令参数、咨询请求或日志。辅助程序强制使用内置 OpenAI 提供方和所选身份验证方式；用户的模型或提供方配置对这次调用无效。它不会修改您的配置。

`--auth-mode auto` 遵循以下规则：

| 可用凭据 | 选择的路径 |
| --- | --- |
| 仅有已保存的 ChatGPT 登录状态 | ChatGPT 订阅额度或积分 |
| 仅有已保存的 API 密钥登录状态 | API 密钥 |
| 存在 `CODEX_API_KEY`，且没有已保存的登录状态，或已保存的是 API 密钥登录状态 | API 密钥（环境变量中的密钥优先） |
| 同时存在 `CODEX_API_KEY` 和已保存的 ChatGPT 登录状态 | 停止；需要明确指定 `--auth-mode` |
| 没有受支持的凭据 | 停止 |

已知主会话使用订阅时，请指定 `--auth-mode chatgpt`。这需要已保存的 ChatGPT 登录状态，而且会从子进程环境中移除 `CODEX_API_KEY`。已知主会话通过 API 密钥计费时，请指定 `--auth-mode api`。这需要已保存的 API 密钥登录状态或 `CODEX_API_KEY`。仅有 `OPENAI_API_KEY` 不会被传给 `codex exec`；请使用有文档说明的 `CODEX_API_KEY`，或先通过 API 密钥登录 Codex。身份验证或用量检查失败时，两种模式都不会自动切换到另一种。

例如，使用 `CODEX_API_KEY` 启动的 API 密钥主会话，应通过 `--auth-mode api` 调用辅助程序。如果主会话使用 ChatGPT 登录状态，但 shell 环境中恰好也有 `CODEX_API_KEY`，则应使用 `--auth-mode chatgpt`；辅助程序不会将该密钥传给子进程。切勿将 API 密钥放入咨询请求或命令参数。

包装程序无法直接检查主 Codex 任务实际采用的身份验证方式。自动选择只是根据可用 CLI 凭据作出的推断，不能证明主任务的计费路径。如果凭据互相冲突，请明确指定已知的路径，以免产生意料之外的费用。OpenAI 文档分别介绍了 [ChatGPT 与 API 密钥身份验证](https://learn.chatgpt.com/docs/auth)及[用于单次非交互式执行的 `CODEX_API_KEY`](https://developers.openai.com/codex/noninteractive)。ChatGPT 用量取决于登录账户的 Codex 额度和适用积分；API 密钥用量按 API 计费。两者都会消耗用量，包装程序无法计算某次咨询的准确费用。

## 限制

- 顾问只能看到所选的咨询请求，可能出错或遗漏未提供的背景信息。主智能体必须结合仓库内容验证建议，并明确表示赞同、部分赞同或不赞同。
- 秘密信息检测采用启发式规则，可能误报或漏报。请自行删去敏感信息；任何过滤器都无法保证完全检出。若回复可能包含秘密信息，程序会隐藏该回复。
- 临时目录和只读模式不等于独立容器，也不是文件系统保密边界。工具和指令隔离基于已测试的 CLI 配置，CLI 更新后可能需要重新检查。
- 当用户配置被忽略时，此 CLI 仍会加载全局 `CODEX_HOME/AGENTS.md` 或 `AGENTS.override.md`。如果其中任一文件非空，辅助程序会拒绝运行，以维持仅依据咨询请求提供建议的隔离方式。不要为了绕过限制而删除全局指令；支持这种安装方式需要进一步的 CLI 隔离工作。当前安装的 `AGENTS.md` 为空。
- 顾问模型既必须存在于 CLI 随附的模型目录中，也必须对您的账户可用。新推出的模型可能需要更新 CLI。临时模型目录保留模型身份及能力元数据，只调整工具暴露情况；这是一项依赖已验证 CLI 版本的实现细节。
- `--ephemeral` 可阻止会话记录持久化，但不保证 CLI 完全不产生缓存、身份验证刷新或诊断活动，也不会改变 OpenAI 服务端的数据保留策略。辅助程序不会持久化咨询请求或回复；主任务仍可能在自身对话记录中保留建议。
- 外层 Codex 沙箱可能阻止联网或访问身份验证缓存。主智能体可能需要针对这次调用获得常规主机审批。辅助程序不会放宽内部沙箱设置，也不会自行向用户提问。
- 管理员实施的限制仍然有效。依赖被忽略的用户配置的代理或凭据存储设置，可能需要额外适配。在 Windows 上，主机的 Job Object 策略可能阻止分配；辅助程序会直接停止，不会运行未被 Job Object 包含的子进程。
- 企业版 `CODEX_ACCESS_TOKEN` 和其他工作负载身份不在当前版本的身份验证检测范围内；请使用已保存的 ChatGPT 或 API 密钥登录状态，或在 API 模式下使用 `CODEX_API_KEY`。
- 不包含自动重试、自动升级求助、计费模式回退、模型回退、MCP 服务器或直接调用 API 的客户端。

## 卸载

只需删除 `~/.codex/skills/consultant/`，或自定义 `CODEX_HOME` 中对应的目录。如有必要，再刷新或重启 Codex。无需删除任何配置项或服务。

## 开发检查

在技能源目录中，运行 `python3 -m unittest discover -s tests -v`，以执行离线子进程测试。在 Windows 上，先使用上述 PowerShell 代码选择 `$python` 和 `$pythonArgs`，再运行 `& $python @pythonArgs -m unittest discover -s tests -v`。测试集包含 Windows 启动闸门和进程管理测试；原生 Job Object 测试仅在 Windows 上运行。`python3 tests/check_cli_isolation.py` 通过本地捕获服务器检查真实 CLI 的工具与技能隔离。`python3 tests/check_cli_api_auth.py` 使用一次性模拟密钥和环回服务器检查已保存及环境变量中的 API 密钥路径，不会发起实际模型请求。仅当本机 CLI 已保存 ChatGPT 登录状态、且希望验证此情况下显式选择 API 模式时，才添加 `--test-conflict-with-current-login`。这些环回测试可能需要本地套接字权限。
