# prove-it

[![verify](https://github.com/Why-Next/prove-it/actions/workflows/verify.yml/badge.svg)](https://github.com/Why-Next/prove-it/actions/workflows/verify.yml)
[![spec 0.1](https://img.shields.io/badge/spec-0.1-4F6134)](../../SPEC.md)
[![license MIT](https://img.shields.io/badge/license-MIT-lightgrey)](../../LICENSE)
![dependencies none](https://img.shields.io/badge/dependencies-none-4F6134)

[English](../../README.md) ·
中文 ·
[Deutsch](README.de.md) ·
[日本語](README.ja.md) ·
[हिन्दी](README.hi.md) ·
[Français](README.fr.md) ·
[Italiano](README.it.md) ·
[Português](README.pt.md) ·
[Русский](README.ru.md) ·
[Español](README.es.md) ·
[한국어](README.ko.md)

在你的仓库完成自证之前，你的智能体无法结束这一回合。

编程智能体会在从未运行测试的情况下报告测试通过，会在从未复现 bug 的情况下报告 bug 已修复。智能体没有办法把自己做过的事和自己想做的事对照起来，于是它报告的是意图。这是一种设计属性，不是品格缺陷，没有任何提示词能修好它。

`prove-it` 把这份报告变成一次检查。在你的仓库根目录放一个 `verify.sh`。当智能体试图结束这一回合时，一个 hook 会运行这个脚本，只要退出码非零，就会把智能体送回去继续干活，而不是让它停下。

![prove-it 拦下一个声称自己已完成的智能体](../../docs/demo.svg)

门禁在一个回合里最多把智能体顶回去三次，然后让步，因为一个永不让步的 hook 会把会话挂死。让步和通过不是一回事，所以你最后看到的是一句警告，说这一回合在未经验证的情况下结束了，而不是那句"完成了"。三这个数字你可以改，而这一切都不是在说你的智能体过不了门禁。它说的是，你的智能体没法悄无声息地越过门禁。

当仓库里有一个本地命令必须在智能体交回工作前为真时，就使用它：测试、类型检查、lint、生成文件检查、迁移 dry run，或证明 bug 已经消失的小型 smoke test。`prove-it` 最适合那些智能体会改代码，并在同一个线程里说"完成了"的仓库。

不要把它当作 sandbox、CI 替代品，或长时间联网任务的地方。如果某项检查需要 secrets、production access，或大约一分钟以上，就把它放进 CI，并让 `verify.sh` 只保留智能体仍在工作时能本地运行的证据。

第一天的流程刻意很小。安装插件，运行 `/prove-it:init`，只保留生成的 `git diff --check` 作为激活的检查，然后在你亲手看见某个真实命令通过之后再打开它。从那以后，当智能体改动仓库并试图停下时，`verify.sh` 决定它是否可以交回工作。

## 为什么不自己写五行？

一个在 Stop hook 里运行你测试的脚本只要五行 bash，它是大多数人写的第一版，而它会以四种安静的方式失败。其中有几种就曾是这道门禁自己早期版本里的 bug，这正是为什么如今每一种都有一个回归测试。

- **它顶回去一次，之后再也不顶。** Claude Code 会在第一次拦截之后的每一次停止上设置 `stop_hook_active`。一个把这个标志读作"放行"的 hook 恰好拦截一次，然后就不再是一道门禁，而一个无视这个标志的 hook 会永远拦下去，把会话挂死。这道门禁会清点尝试次数，把智能体顶回去有限的若干次，然后大声地让步。
- **一次提交看起来像什么都没发生。** 一个靠检查工作树是否脏来做判断的 hook，会对任何以提交收场的回合挥手放行，而提交是智能体做的最寻常的事。这道门禁把树和会话开始时记录下的基线作比较，所以一次提交、一次 `sed` 重写和一个生成出来的文件全都算作改动。
- **智能体可以把检查移除掉。** 一个无法让 `verify.sh` 通过的智能体，可以转而删除它，或者对它 `chmod -x`。这道门禁会记录会话开始时仓库是否处于武装状态，并拒绝一个以门禁被卸掉而收场的回合。一次让它保持可执行的重写会被放行，并且会报告给你，而不是被默默地信任。
- **放弃和通过无法区分。** 每一个宿主最终都会强迫 hook 让步。一个手写的 hook 会在沉默中让步，你看到的最后一句话是"完成了"；这一个的最后一句话是一条警告，说这一回合在未经验证的情况下结束了。

如果你更愿意留着自己的 hook，那就留着它，然后去读 [SPEC.md](../../SPEC.md)，看看它必须覆盖哪些情况。这份约定本身比它的这个实现更重要。

## 安装

三行命令，真正干活的是第三行：

```
/plugin marketplace add Why-Next/prove-it
/plugin install prove-it@whynext
/prove-it:init
```

`/prove-it:init` 会检测你的技术栈，写出一个 `verify.sh`，运行它好让你亲眼看着它通过，然后再运行一份在末尾加了 `exit 1` 的副本，好让你看着门禁拒绝一个回合。这大约要三十秒，而且它绝不会覆盖你已经有的 `verify.sh`。

生成出来的门禁只有一项处于激活状态的检查，`git diff --check`，针对你技术栈的那些检查则作为注释写在里面。它在你安装它的当天会通过，这是刻意的。一个在落地当天就在 `main` 上失败的门禁，会教人在头一周里就把它绕过去。把注释掉的检查一次打开一项，在你亲手看着每一项通过之后再打开。

除此之外没有别的配置，而且在一个 `verify.sh` 存在之前什么都不会运行。如果你打开一个没有它的仓库，插件会在会话一开始就把这件事说出来，而不是保持沉默、任由你以为自己已经受到保护。

## 不使用插件

这些 hook 就是普通的 bash 脚本，只需要 `bash`、`git` 和 `python3`：

```bash
git clone https://github.com/Why-Next/prove-it ~/.local/share/prove-it
~/.local/share/prove-it/bin/prove-it init
```

把 [`hooks/settings.example.json`](../../hooks/settings.example.json) 合并进你的 `.claude/settings.json`（针对单个仓库），或者 `~/.claude/settings.json`（对所有仓库）。门禁从 stdin 读取 Stop hook 的 JSON 负载，并用退出码作答，所以任何能在回合结束时运行脚本的东西都能驱动它。Claude Code 是它接受测试的地方；[docs/ADAPTERS.md](../ADAPTERS.md) 里写好了 Codex CLI、Qwen Code、Gemini CLI 和 Copilot CLI 的接线方式，它们暴露的是同一类能够拦截的回合结束 hook，而那份文档也直白地说出了哪些宿主根本驱动不了门禁。

`prove-it doctor` 会回答：在你此刻所在的仓库里，门禁会不会触发；如果不会，它会告诉你是什么在拦着它：

```
repository   /home/you/src/api
verify.sh    present and executable
working tree dirty
blocks       up to 3 per turn, then it yields with a warning
state        /home/you/.local/state/prove-it
ledger       off (export PROVE_IT_LEDGER=1 to record what the gate catches)
```

## 让门禁生长

你每加一个检查，都是在回答"在这个仓库里'被证明'意味着什么"这个问题时补上的一句话。加上你实际运行的测试命令，然后是类型检查器，再然后是你的评审反复抓到的那些东西。当整个脚本大约要跑一分钟时就停下；慢的检查该放到 CI 里。

在你打开每一项检查之前，先亲手运行它。同样地，绝不要交付一个你没有亲眼看着它失败的检查：一个不可能失败的检查不算检查，而你不会在需要它的那一天才发现这一点。

常见的错误是第一天就写一个雄心勃勃的 `verify.sh`。又慢又不稳定的门禁会在一周之内被绕过，而被绕过的门禁比没有门禁更糟，因为它会报告有一个检查运行过，其实什么都没运行。

## 它如何决定是否运行

除非下面每一条都成立，否则门禁保持安静：

- 本次会话改动过这个仓库
- 仓库根目录存在一个可执行的 `verify.sh`
- 这个确切的树状态还没有通过过

"改动过"是由仓库来回答的，而不是由一份记录着哪些工具运行过的日志来回答。会话一开始，hook 会记录下当时的树是什么样子，而在每次停止时，它会问树现在是不是还那样。一个被 `sed` 重写的文件、一个用 `git apply` 打上去的补丁、一个由代码生成器产出的文件，以及一次提交，全都是改动，因为它们全都改变了树。一次只做了读取的会话，什么都不算，哪怕它打开时仓库本来就是脏的。

最后一条意味着：一个通过的树只验证一次，而不是每次停止都验证。验证失败时，智能体会看到输出的最后二十行，这通常足以让它在没人告诉它哪里出错的情况下修好原因。

`PROVE_IT_SKIP=1` 会有意越过门禁。在两次会话之间删除 `verify.sh` 会把它彻底关掉。这两个逃生口都是刻意保留的：人们会绕开一个自己无法移除的门禁。`PROVE_IT_MAX_BLOCKS` 设定一个回合能被顶回去多少次，而 `0` 会让门禁只报告、永不拦截。

## 当智能体去改门禁本身

最棘手的失败模式不是不稳定的检查。而是一个无法让 `verify.sh` 通过的智能体，转而去改 `verify.sh`。

其中最省事的一种做法，是干脆把门禁卸掉，所以门禁会拒绝这么做。hook 会记录会话开始时 `verify.sh` 是不是可执行的，而一次以它被删除、或它的可执行位被去掉而收场的会话，会被拦下，被告知它做了什么，也被告知如果它当真想退出该怎样诚实地退出。在两次会话之间删除 `verify.sh` 仍然是一种退出方式，而且仍然只需要一条命令。

更隐蔽的那一种，是一个让 `verify.sh` 保持可执行、却重写里面各项检查的智能体。这样的通过不会被拦下，因为修改 `verify.sh` 常常恰恰就是你交代的工作，但它也不再是悄无声息的了：当一个回合经由一个在会话期间发生过改动的 `verify.sh` 通过时，门禁会把这件事告诉你，而 `verify.sh` 的 diff 会告诉你这次改动是工作还是逃避。读那份 diff。这正是规范里那条 diff 证据存在的意义。

## `verify.sh` 约定

`hooks/` 里的脚本是有意做得很小的。它所实现的东西写在 [SPEC.md](../../SPEC.md) 里：一个仓库在一个已知的路径、以一份已知的契约，声明它如何自证，而在那份证明通过之前，智能体不得声称完成。规范指定的是一个文件和一个退出码，从不指定某个厂商，所以插件只是分发这个想法的一种方式，而不是这个想法本身。

去读规范，了解 `verify.sh` 应当据以断言的四种证据，也就是命令输出、diff、复现和交叉核对，以及各个符合性等级。

## 它不做什么

门禁只强制一件事：`verify.sh` 在回合结束前返回了零。那个零有没有意义，完全取决于你写的检查。一个只包含 `exit 0` 的 `verify.sh` 会通过这道门禁，却什么都证明不了。

规范把那称为 Level 1。Level 2 是你的检查是否据以真实证据来断言，而没有任何工具能替你验证这一点，包括这一个。

还有三条边界，这里直白地讲出来，否则你会在一个糟糕的时刻才撞见它们。门禁在 `PROVE_IT_MAX_BLOCKS` 次拒绝之后就会让步，所以一个执意如此的智能体终究能走到它这一回合的尽头；它做不到的，是悄无声息地走到那里。被你的 `.gitignore` 排除掉的文件，对改动检测是不可见的，所以当只有一个被忽略的 `.env` 发生变化时，一个会去读它的 `verify.sh` 可能会被跳过。还有，一次在它后来所编辑的仓库之外开始的会话，没有基线可供比对，这会让门禁退回到那个更弱的判据：工作树是不是脏的。

## 配方

按技术栈划分的起点在 [`recipes/`](../../recipes/) 里。复制一个到 `verify.sh`，删掉不适用的部分。保持在一分钟以内；慢的检查该放到 CI 里。

| | |
|---|---|
| [`node.sh`](../../recipes/node.sh) | 测试、类型检查、lint、diff 卫生 |
| [`python.sh`](../../recipes/python.sh) | pytest、ruff、mypy |
| [`go.sh`](../../recipes/go.sh) | go test、vet、gofmt 检查 |
| [`flutter.sh`](../../recipes/flutter.sh) | analyze、test、format 检查 |

接上 hook 是容易的部分。真正的工作是回答"在你的仓库里'被证明'意味着什么"，而没有任何配方能替你回答。

## 账本

设置 `PROVE_IT_LEDGER=1`，每一次被抓到的虚假完成都会向 `~/.prove-it/ledger.jsonl` 追加一行：

```json
{"ts":"2026-07-09T04:12:33Z","claim":"All tests pass. Ready to merge.",
 "evidence_demanded":"verify.sh exit 0","actual":["3 failed, 41 passed"]}
```

这一行记录了智能体声称了什么、被要求了什么，以及最后被证明为真的是什么。这个文件以 `0600` 权限写入本地磁盘，不会被传输到任何地方，而且在你打开它之前一直是关闭的。积累一个月的条目之后，你就不用再猜你的智能体是怎么失败的，而是直接去读它。`/prove-it:ledger` 会替你把这个文件汇总起来，命令行上的 `prove-it ledger` 也一样。

## 这个仓库对自己设卡

`prove-it` 有一个 `verify.sh`，它运行的一部分内容就是门禁本身，在一个临时目录里针对真实的 git 仓库运行：失败的检查会拦截，通过的检查会放行，只读会话不受打扰，提交后的干净树不会被误认为没有工作，绕过机制有效。

```bash
./verify.sh
```

CI 会在 Linux 和 macOS 上运行同一个脚本，另外还有一个单独的任务，用来证明门禁仍然会拦下一个检查失败的仓库。这个仓库还会运行 CodeQL、OpenSSF Scorecard，以及一个按 tag 触发的 release workflow，用 checksum 和 GitHub provenance attestation 打包源码。

## 项目信任

在你不信任的仓库里使用它之前，请先阅读 [SECURITY.md](../../SECURITY.md)。`prove-it` 会执行仓库自己拥有的 `verify.sh`；它是 guardrail，不是 sandbox。

Release 步骤在 [RELEASE.md](../../RELEASE.md)，其中包括 verification、workflow 状态、checksum 和 provenance attestation 的 checklist。支持边界在 [SUPPORT.md](../../SUPPORT.md)。

## 贡献

欢迎提 issue 和 pull request。对约定本身的修改应当放进 issue，而不是针对参考实现提 pull request。见 [CONTRIBUTING.md](../../CONTRIBUTING.md)。

## 许可证

MIT。
