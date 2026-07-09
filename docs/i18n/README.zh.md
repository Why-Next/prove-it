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

**在仓库完成自证之前，你的智能体无法结束当前回合。**

编程智能体会在没运行测试的情况下声称"测试通过"，会在从未复现 bug 的情况下声称"已修复"。这并非出于恶意：智能体分不清自己实际做了什么和自己打算做什么，于是它报告的是意图。

`prove-it` 把*完成*变成智能体必须通过的东西，而不是它随口就能说出的话。在仓库根目录放一个 `verify.sh`。当智能体试图停止时，门禁会运行它。只要退出码非零，这一回合就不会结束。

![prove-it 拦截了一个声称自己已完成的智能体](../../docs/demo.svg)

大约有一半的情况，当你要求智能体拿出证据时，它会回答"你说得对，其实还没做完"。

## 安装

作为 Claude Code 插件：

```
/plugin marketplace add WhyNext/prove-it
/plugin install prove-it@whynext
```

安装到此为止。插件会注册两个 hook：一个用于标记某次会话编辑过文件，另一个用于对这一回合设卡。

对于任何其他智能体，或者如果你不想安装插件，可以克隆仓库并自己接上这两个相同的 hook。它们就是普通的 bash 脚本，除了 `bash`、`git` 和 `python3` 之外不依赖任何东西：

```bash
git clone https://github.com/WhyNext/prove-it ~/.local/share/prove-it
```

把 [`hooks/settings.example.json`](../../hooks/settings.example.json) 合并进你的 `.claude/settings.json`（针对单个仓库）或 `~/.claude/settings.json`（对所有仓库生效）。门禁从 stdin 读取 Stop hook 的 JSON 负载，并通过退出码通信，所以任何能在回合结束时运行脚本的东西都能驱动它。

然后写下那个唯一重要的文件：

```bash
cat > verify.sh <<'EOF'
#!/bin/bash
set -eu
cd "$(dirname "$0")"

npm test
npx tsc --noEmit
git diff --check

echo "verify.sh OK"
EOF
chmod +x verify.sh
```

在你写下那个文件之前，门禁什么都不会做。

## 你的头五分钟

从比你以为的还要小的地方开始。一个只运行 `git diff --check` 的 `verify.sh` 就已经值得拥有，而且它会通过，这会让你明白：一切正常时门禁是安静的。

```bash
printf '#!/bin/bash\nset -eu\ncd "$(dirname "$0")"\ngit diff --check\n' > verify.sh
chmod +x verify.sh
./verify.sh                 # run it yourself first. Never ship a check you have not seen pass.
```

现在故意让它失败，好让你知道门禁是真的：

```bash
sed -i.bak 's|git diff --check|git diff --check\nexit 1|' verify.sh && rm verify.sh.bak
```

让你的智能体随便编辑一个文件，然后让它收尾。它会试图结束这一回合，门禁会运行 `verify.sh`，而这一回合会被拦下。撤销那个 `exit 1`，同一个智能体就会顺畅通过。

从这里开始，一次只加一个真正的检查：你实际运行的测试命令，然后是类型检查器，然后是 diff 卫生检查。你每加一个检查，都是在回答*在这里被证明意味着什么*这个问题时补上的一句话。当整件事跑起来大约要花一分钟时，就停下。

要避免的错误是第一天就写一个雄心勃勃的 `verify.sh`。又慢又不稳定的门禁在一周之内就会被绕过，而被绕过的门禁比没有还糟：它会告诉你检查发生过，其实并没有。

## 它如何决定要不要运行

门禁默认是安静的。只有当下面每一条都成立时，它才会运行 `verify.sh`：

- 会话确实编辑过文件（只读会话没什么可证明的）
- 仓库根目录存在一个可执行的 `verify.sh`
- 工作树有未提交的改动
- 这个确切的树状态还没有通过过

最后一条意味着：一个通过的树只验证一次，而不是每次停止都验证。失败时会把输出的最后 20 行打印给智能体，这通常足以让它在没人提示的情况下修好原因。

想有意越过门禁：`PROVE_IT_SKIP=1`。想彻底关掉它：删除 `verify.sh`。两者都是刻意为之。一个谁都无法移除的门禁，会变成一个人人绕道而行的门禁。

## 可以选择退出，这正是特性所在

最棘手的失败模式不是不稳定的检查。而是一个过不了 `verify.sh` 的智能体，转而悄悄去改 `verify.sh`。门禁的失败信息会把这一点直白地说出来，规范也把它明确列为一种违规。不过你还是要在自己的 diff 里留意它。这正是 diff 证据存在的意义。

## `verify.sh` 约定

`hooks/` 里的脚本是有意做得很小的。真正的产物是它所实现的约定，写在 **[SPEC.md](../../SPEC.md)** 里：一个仓库在一个已知的位置、以一份已知的契约，声明它如何自证，而在那份证明通过之前，智能体不得声称完成。

插件只是一个分发渠道，不是这个想法本身。这份约定意在活得比任何单个智能体都久，所以规范指定的是一个文件和一个退出码，而绝不是某个厂商。

去读规范，了解 `verify.sh` 应当据以断言的四种证据 - 命令输出、diff、复现、交叉核对 - 以及各个符合性等级。

**先老实说一句。** 这个工具只强制一件事：`verify.sh` 在回合结束前返回了零。那个零到底*有没有*意义，完全取决于你写的检查。一个只包含 `exit 0` 的 `verify.sh` 会通过这道门禁，却什么都证明不了。工具是 Level 1。证据是 Level 2，而 Level 2 是一种实践，不是一个功能。

## 配方

按技术栈划分的起点，在 [`recipes/`](../../recipes/) 里。复制一个到 `verify.sh`，删掉不适用的部分。保持在一分钟以内；慢的检查该放到 CI 里。

| | |
|---|---|
| [`node.sh`](../../recipes/node.sh) | 测试、类型检查、lint、diff 卫生 |
| [`python.sh`](../../recipes/python.sh) | pytest、ruff、mypy |
| [`go.sh`](../../recipes/go.sh) | go test、vet、gofmt 检查 |
| [`flutter.sh`](../../recipes/flutter.sh) | analyze、test、format 检查 |

采用它的难点从来不是接上 hook。而是第一次回答"在这个仓库里*被证明*意味着什么"。

## 账本

设置 `PROVE_IT_LEDGER=1`，每一次被抓到的虚假完成都会向 `~/.prove-it/ledger.jsonl` 追加一行：

```json
{"ts":"2026-07-09T04:12:33Z","claim":"All tests pass. Ready to merge.",
 "evidence_demanded":"verify.sh exit 0","actual":["3 failed, 41 passed"]}
```

声称了什么，要求了什么，实际为真的是什么。只写本地磁盘，绝不传输，除非你打开否则一直关闭。一个月之后，你就不再靠猜来判断你的智能体是怎么失败的，而是开始去读它。

## 这个仓库对自己设卡

`prove-it` 有一个 `verify.sh`，它会在一个临时目录里针对真实的 git 仓库运行门禁：失败的检查会拦截，通过的检查会放行，只读会话不受影响，干净的树会被跳过，绕过机制有效。

```bash
./verify.sh
```

否则发布它就成了一件很奇怪的事。

## 贡献

欢迎提 issue 和 pull request。对约定本身的修改应当放进 issue，而不是针对参考实现提 pull request：约定才是产物，脚本只是脚注。见 [CONTRIBUTING.md](../../CONTRIBUTING.md)。

## 许可证

MIT。
