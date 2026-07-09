# prove-it

[![verify](https://github.com/WhyNext/prove-it/actions/workflows/verify.yml/badge.svg)](https://github.com/WhyNext/prove-it/actions/workflows/verify.yml)
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

`prove-it` 把这份报告变成一次检查。在你的仓库根目录放一个 `verify.sh`。当智能体试图结束这一回合时，一个 hook 会运行这个脚本，只要退出码非零，这一回合就会一直开着，直到原因被修好。

![prove-it 拦下一个声称自己已完成的智能体](../../docs/demo.svg)

在我自己的使用中，撞上失败门禁的回合里，有将近一半会以智能体承认自己还没做完收场。这些回合本来会以一句"完成了"结束。

## 安装

三行命令，真正干活的是第三行：

```
/plugin marketplace add WhyNext/prove-it
/plugin install prove-it@whynext
/prove-it:init
```

`/prove-it:init` 会检测你的技术栈，写出一个 `verify.sh`，运行它好让你亲眼看着它通过，然后再运行一份在末尾加了 `exit 1` 的副本，好让你看着门禁拒绝一个回合。这大约要三十秒，而且它绝不会覆盖你已经有的 `verify.sh`。

生成出来的门禁只有一项处于激活状态的检查，`git diff --check`，针对你技术栈的那些检查则作为注释写在里面。它在你安装它的当天会通过，这是刻意的。一个在落地当天就在 `main` 上失败的门禁，会教人在头一周里就把它绕过去。把注释掉的检查一次打开一项，在你亲手看着每一项通过之后再打开。

除此之外没有别的配置，而且在一个 `verify.sh` 存在之前什么都不会运行。如果你打开一个没有它的仓库，插件会在会话一开始就把这件事说出来，而不是保持沉默、任由你以为自己已经受到保护。

## 不使用插件

这些 hook 就是普通的 bash 脚本，只需要 `bash`、`git` 和 `python3`：

```bash
git clone https://github.com/WhyNext/prove-it ~/.local/share/prove-it
~/.local/share/prove-it/bin/prove-it init
```

把 [`hooks/settings.example.json`](../../hooks/settings.example.json) 合并进你的 `.claude/settings.json`（针对单个仓库），或者 `~/.claude/settings.json`（对所有仓库）。门禁从 stdin 读取 Stop hook 的 JSON 负载，并用退出码作答，所以任何能在回合结束时运行脚本的东西都能驱动它。

`prove-it doctor` 会回答：在你此刻所在的仓库里，门禁会不会触发；如果不会，它会告诉你是什么在拦着它：

```
repository   /home/you/src/api
verify.sh    present and executable
working tree dirty, so the gate would run on the next stop
state        /home/you/.local/state/prove-it
ledger       off (export PROVE_IT_LEDGER=1 to record what the gate catches)
```

## 让门禁生长

你每加一个检查，都是在回答"在这个仓库里'被证明'意味着什么"这个问题时补上的一句话。加上你实际运行的测试命令，然后是类型检查器，再然后是你的评审反复抓到的那些东西。当整个脚本大约要跑一分钟时就停下；慢的检查该放到 CI 里。

在你打开每一项检查之前，先亲手运行它。同样地，绝不要交付一个你没有亲眼看着它失败的检查：一个不可能失败的检查不算检查，而你不会在需要它的那一天才发现这一点。

常见的错误是第一天就写一个雄心勃勃的 `verify.sh`。又慢又不稳定的门禁会在一周之内被绕过，而被绕过的门禁比没有门禁更糟，因为它会报告有一个检查运行过，其实什么都没运行。

## 它如何决定是否运行

除非下面每一条都成立，否则门禁保持安静：

- 本次会话编辑过这个仓库里的文件
- 仓库根目录存在一个可执行的 `verify.sh`
- 工作树有未提交的改动
- 这个确切的树状态还没有通过过

最后一条意味着：一个通过的树只验证一次，而不是每次停止都验证。验证失败时，智能体会看到输出的最后二十行，这通常足以让它在没人告诉它哪里出错的情况下修好原因。

`PROVE_IT_SKIP=1` 会有意越过门禁。删除 `verify.sh` 会把它彻底关掉。这两个逃生口都是刻意保留的：人们会绕开一个自己无法移除的门禁。

## 当智能体去改门禁本身

最棘手的失败模式不是不稳定的检查。而是一个无法让 `verify.sh` 通过的智能体，转而去改 `verify.sh`。失败信息会告诉它不要这么做，[SPEC.md](../../SPEC.md) 也把这称为一种违规而不是修复，但这两者都不是强制手段。读你的 diff。这正是规范里那条 diff 证据存在的意义。

## `verify.sh` 约定

`hooks/` 里的脚本是有意做得很小的。它所实现的东西写在 [SPEC.md](../../SPEC.md) 里：一个仓库在一个已知的路径、以一份已知的契约，声明它如何自证，而在那份证明通过之前，智能体不得声称完成。规范指定的是一个文件和一个退出码，从不指定某个厂商，所以插件只是分发这个想法的一种方式，而不是这个想法本身。

去读规范，了解 `verify.sh` 应当据以断言的四种证据，也就是命令输出、diff、复现和交叉核对，以及各个符合性等级。

## 它不做什么

门禁只强制一件事：`verify.sh` 在回合结束前返回了零。那个零有没有意义，完全取决于你写的检查。一个只包含 `exit 0` 的 `verify.sh` 会通过这道门禁，却什么都证明不了。

规范把那称为 Level 1。Level 2 是你的检查是否据以真实证据来断言，而没有任何工具能替你验证这一点，包括这一个。

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

`prove-it` 有一个 `verify.sh`，它运行的一部分内容就是门禁本身，在一个临时目录里针对真实的 git 仓库运行：失败的检查会拦截，通过的检查会放行，只读会话不受打扰，干净的树会被跳过，绕过机制有效。

```bash
./verify.sh
```

CI 会在 Linux 和 macOS 上运行同一个脚本，另外还有一个单独的任务，用来证明门禁仍然会拦下一个检查失败的仓库。

## 贡献

欢迎提 issue 和 pull request。对约定本身的修改应当放进 issue，而不是针对参考实现提 pull request。见 [CONTRIBUTING.md](../../CONTRIBUTING.md)。

## 许可证

MIT。
