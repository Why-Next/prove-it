# prove-it

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

**在你的仓库自证之前, 你的 agent 无法结束这一轮。**

编码 agent 会在没有跑测试的情况下说"测试通过", 也会在从没复现过 bug 的情况下说"已修复"。这不是出于恶意: agent 分不清它实际做了什么和它想做什么, 于是它汇报的是意图。

`prove-it` 让 *完成* 变成 agent 必须通过的东西, 而不是它随口就能说的东西。在仓库根目录放一个 `verify.sh`。当 agent 试图停下时, 这道门会运行它。退出码非零, 这一轮就不结束。

```
agent: "All tests pass. Ready to merge."
       └─ tries to end turn
          └─ prove-it runs ./verify.sh
             └─ exit 1:  FAIL src/auth.test.ts  (3 failed, 41 passed)
                └─ turn blocked, agent keeps working

agent: "Actually, three tests were failing. Fixing."
```

大约有一半的情况, 被要求拿出证据的 agent 会回答"你说得对, 还没做完。"

## 安装

需要 `bash`, `git`, `python3`。没有依赖包, 没有守护进程, 也不用注册任何东西。随便找个地方 clone 下来:

```bash
git clone https://github.com/YOUR_ORG/prove-it ~/.local/share/prove-it
```

把两个 hook 接进 Claude Code, 方法是把
[`hooks/settings.example.json`](../../hooks/settings.example.json) 合并进你的
`.claude/settings.json`(按仓库)或 `~/.claude/settings.json`(全局)。

然后写下唯一重要的那个文件:

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

这就是全部配置。你的仓库里现在还没有 `verify.sh`, 所以在你写出一个之前, 这道门什么都不做。

## 你的头五分钟

从比你以为的更小的地方开始。一个只跑 `git diff --check` 的 `verify.sh` 就已经值得拥有了, 而且它会通过, 这会让你明白: 一切正常时这道门是安静的。

```bash
printf '#!/bin/bash\nset -eu\ncd "$(dirname "$0")"\ngit diff --check\n' > verify.sh
chmod +x verify.sh
./verify.sh                 # run it yourself first. Never ship a check you have not seen pass.
```

现在故意让它失败, 好让你知道这道门是真的:

```bash
sed -i.bak 's|git diff --check|git diff --check\nexit 1|' verify.sh && rm verify.sh.bak
```

让你的 agent 编辑任意一个文件, 然后让它收尾。它会试着结束这一轮, 门会运行 `verify.sh`, 而这一轮会被拦下。撤掉那个 `exit 1`, 同一个 agent 就顺利通过。

从这里开始, 一次只加一个真正的检查: 你实际会跑的测试命令, 然后是类型检查, 再然后是 diff 卫生检查。你加的每一个检查, 都是你回答 *在这里"证明完成"意味着什么* 的一句话。整套跑下来大约一分钟时就停手。

要避免的错误是第一天就写一个雄心勃勃的 `verify.sh`。又慢又不稳定的门, 一周之内就会被绕过, 而被绕过的门比没有门更糟: 它告诉你检查发生过, 而它其实没有。

## 它如何决定是否运行

这道门默认是安静的。只有当下面每一条都成立时, 它才运行 `verify.sh`:

- 这次会话确实编辑了文件(只读会话没有什么可证明的)
- 仓库根目录存在一个可执行的 `verify.sh`
- 工作树有未提交的改动
- 这个确切的树状态还没有通过过

最后一条意味着: 一个通过的树只验证一次, 而不是每次停下都验证。失败时会把输出的最后 20 行打印给 agent, 通常这就足够让它不用别人告诉就修好原因。

要故意越过这道门: `PROVE_IT_SKIP=1`。要彻底关掉它: 删掉 `verify.sh`。两者都是有意为之。一道谁也删不掉的门, 会变成一道大家绕着走的门。

## 可以退出正是它的特性

最难对付的失败模式不是不稳定的检查。而是一个过不了 `verify.sh` 的 agent 偷偷去改 `verify.sh` 本身。门的失败信息把这一点说得明明白白, 规范也把它列为一项明文违规。不过还是要在你的 diff 里盯着它。这正是 diff 证据的用途。

## `verify.sh` 约定

`hooks/` 里的脚本是有意做得很小的。真正的产物是它实现的那套约定, 写在 **[SPEC.md](../../SPEC.md)** 里: 一个仓库声明它如何自证, 在一个已知的位置, 带着一份已知的契约, 而 agent 在那份证明通过之前不得声称完成。

去读规范, 了解一个 `verify.sh` 应当针对的四类证据 - 命令输出, diff, 复现, 交叉核对 - 以及各个符合级别。

**先说一句实在话。** 这个工具只强制一件事: `verify.sh` 在这一轮结束前返回了零。那个零 *是否* 有意义, 完全取决于你写的检查。一个只包含 `exit 0` 的 `verify.sh` 会通过这道门, 却什么也证明不了。工具是 Level 1。证据是 Level 2, 而 Level 2 是一种实践, 不是一个功能。

## 配方

各个技术栈的起点, 放在 [`recipes/`](../../recipes/)。挑一个复制成 `verify.sh`, 把不适用的部分砍掉。保持在一分钟以内; 慢的检查该放到 CI 里。

| | |
|---|---|
| [`node.sh`](../../recipes/node.sh) | tests, typecheck, lint, diff hygiene |
| [`python.sh`](../../recipes/python.sh) | pytest, ruff, mypy |
| [`go.sh`](../../recipes/go.sh) | go test, vet, gofmt check |
| [`flutter.sh`](../../recipes/flutter.sh) | analyze, test, format check |

采用它最难的部分从来不是接好 hook。而是第一次回答"在这个仓库里, *证明完成* 意味着什么"。

## 账本

设置 `PROVE_IT_LEDGER=1`, 每一次被抓到的假完成都会往
`~/.prove-it/ledger.jsonl` 追加一行:

```json
{"ts":"2026-07-09T04:12:33Z","claim":"All tests pass. Ready to merge.",
 "evidence_demanded":"verify.sh exit 0","actual":["3 failed, 41 passed"]}
```

声称了什么, 要求了什么, 真实情况是什么。只写本地磁盘, 从不外传, 不打开就不启用。一个月之后, 你不再靠猜来判断你的 agent 是怎么失败的, 而是开始去读它。

## 这个仓库为自己设门

`prove-it` 自己有一个 `verify.sh`, 它会在临时目录里针对真实的 git 仓库运行这道门: 失败的检查会拦下, 通过的检查会放行, 只读会话不受影响, 干净的树被跳过, 越过机制生效。

```bash
./verify.sh
```

否则拿出来发布就太奇怪了。

## 许可证

MIT.
