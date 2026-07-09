# prove-it

[English](../../README.md) ·
[中文](README.zh.md) ·
[Deutsch](README.de.md) ·
日本語 ·
[हिन्दी](README.hi.md) ·
[Français](README.fr.md) ·
[Italiano](README.it.md) ·
[Português](README.pt.md) ·
[Русский](README.ru.md) ·
[Español](README.es.md) ·
[한국어](README.ko.md)

**リポジトリが自らを証明するまで、エージェントはターンを終えられない。**

コーディングエージェントは、テストを実行していないのに「テストは通った」と言い、バグを再現してもいないのに「修正した」と言う。悪意からではない。エージェントは自分が実際にやったことと、やろうとしたことを区別できないので、意図のほうを報告してしまう。

`prove-it` は、*完了* をエージェントが口にできるものではなく、通過しなければならないものに変える。リポジトリのルートに `verify.sh` を置く。エージェントが停止しようとすると、ゲートがそれを実行する。終了コードがゼロ以外なら、ターンは終わらない。

```
agent: "All tests pass. Ready to merge."
       └─ tries to end turn
          └─ prove-it runs ./verify.sh
             └─ exit 1:  FAIL src/auth.test.ts  (3 failed, 41 passed)
                └─ turn blocked, agent keeps working

agent: "Actually, three tests were failing. Fixing."
```

証拠を求められたエージェントは、おおよそ半分の確率で「そのとおり、まだ終わっていません」と答える。

## インストール

`bash`、`git`、`python3` が必要。パッケージも、デーモンも、サインアップも要らない。どこにでもクローンできる:

```bash
git clone https://github.com/YOUR_ORG/prove-it ~/.local/share/prove-it
```

[`hooks/settings.example.json`](../../hooks/settings.example.json) を `.claude/settings.json`(リポジトリごと)または `~/.claude/settings.json`(全体)にマージして、2つのフックを Claude Code に組み込む。

そして、唯一重要なファイルを書く:

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

セットアップはこれで全部だ。リポジトリにはまだ `verify.sh` が無いので、書くまでゲートは何もしない。

## 最初の5分

思っているより小さく始めよう。`git diff --check` を実行するだけの `verify.sh` でも持つ価値があるし、それは通る。そして通ることで、問題が無いときゲートは静かだと分かる。

```bash
printf '#!/bin/bash\nset -eu\ncd "$(dirname "$0")"\ngit diff --check\n' > verify.sh
chmod +x verify.sh
./verify.sh                 # run it yourself first. Never ship a check you have not seen pass.
```

次に、わざと失敗させて、ゲートが本物だと確かめる:

```bash
sed -i.bak 's|git diff --check|git diff --check\nexit 1|' verify.sh && rm verify.sh.bak
```

エージェントに何かファイルを編集させて、そのまま終わらせる。エージェントはターンを終えようとし、ゲートが `verify.sh` を実行し、ターンはブロックされる。`exit 1` を元に戻せば、同じエージェントがすんなり通り抜ける。

そこから、本物のチェックを一度に1つずつ足していく。実際に走らせているテストコマンド、次に型チェッカー、次に diff の衛生確認。足すチェックの1つ1つが、*ここで証明済みとは何を意味するか* への答えの1文になる。全体でだいたい1分かかるところで止める。

避けるべき間違いは、初日から野心的な `verify.sh` を書くことだ。遅かったり不安定だったりするゲートは1週間で迂回されるようになり、迂回されたゲートは無いよりも悪い。実際には起きていないチェックが、起きたと告げてくるからだ。

## 実行するかどうかの判断

ゲートはデフォルトで静かだ。次のすべてが真のときだけ `verify.sh` を実行する:

- セッションが実際にファイルを編集した(読み取り専用のセッションには証明すべきものが無い)
- 実行可能な `verify.sh` がリポジトリのルートに存在する
- ワーキングツリーにコミットされていない変更がある
- このツリー状態がまだ通過していない

最後の条件は、通過したツリーは一度だけ検証され、停止のたびにではないことを意味する。失敗すると、出力の最後の20行がエージェントに表示され、たいていはそれで、言われなくても原因を直せる。

わざとゲートを越えるには `PROVE_IT_SKIP=1`。完全に切るには `verify.sh` を削除する。どちらも意図的な操作だ。誰にも取り除けないゲートは、人が回避するゲートになる。

## オプトアウトこそが機能だ

いちばん厄介な失敗のかたちは、不安定なチェックではない。`verify.sh` を通せず、こっそり `verify.sh` のほうを書き換えるエージェントだ。ゲートの失敗メッセージははっきりそう述べるし、仕様はそれを明示された違反としている。それでも diff で目を光らせておくこと。diff の証拠はそのためにある。

## `verify.sh` の規約

`hooks/` にあるスクリプトは、意図的に小さくしてある。本当の成果物は、それが実装している規約であり、**[SPEC.md](../../SPEC.md)** に書かれている。リポジトリは、既知の場所で、既知の契約に従って、自らをどう証明するかを宣言する。そしてエージェントは、その証明が通るまで完了を主張してはならない。

`verify.sh` が突き合わせるべき4種類の証拠 - コマンド出力、diff、再現、クロスチェック - と適合レベルについては、仕様を読んでほしい。

**最初に、正直な注記を1つ。** このツールが強制するのは、ちょうど1つだけ。ターンが終わる前に `verify.sh` がゼロを返したことだ。そのゼロに *意味* があるかどうかは、あなたが書いたチェック次第で決まる。`exit 0` だけの `verify.sh` はこのゲートを通過し、何も証明しない。ツールは Level 1 だ。証拠は Level 2 であり、Level 2 は機能ではなく実践だ。

## レシピ

スタックごとの出発点が [`recipes/`](../../recipes/) にある。1つを `verify.sh` にコピーして、当てはまらない部分を削る。1分以内に収めること。遅いチェックは CI に属する。

| | |
|---|---|
| [`node.sh`](../../recipes/node.sh) | tests, typecheck, lint, diff hygiene |
| [`python.sh`](../../recipes/python.sh) | pytest, ruff, mypy |
| [`go.sh`](../../recipes/go.sh) | go test, vet, gofmt check |
| [`flutter.sh`](../../recipes/flutter.sh) | analyze, test, format check |

これを導入するうえで難しいのは、フックの配線ではまったくない。「このリポジトリで *証明済み* とは何を意味するか」に、初めて答えることだ。

## 台帳

`PROVE_IT_LEDGER=1` を設定すると、検出された偽の完了ごとに1行が `~/.prove-it/ledger.jsonl` に追記される:

```json
{"ts":"2026-07-09T04:12:33Z","claim":"All tests pass. Ready to merge.",
 "evidence_demanded":"verify.sh exit 0","actual":["3 failed, 41 passed"]}
```

何が主張され、何が求められ、何が真だったか。ローカルディスクだけに、決して送信されず、有効にしない限りオフだ。1か月経つと、エージェントがどう失敗するかを推測するのをやめ、それを読むようになる。

## このリポジトリは自分自身をゲートする

`prove-it` には `verify.sh` があり、一時ディレクトリ内の本物の git リポジトリに対してゲートを実行する。失敗するチェックはブロックし、通るチェックは許可し、読み取り専用のセッションは手を付けず、クリーンなツリーはスキップし、バイパスは機能する。

```bash
./verify.sh
```

そうでないものを出荷するのは、おかしな話だろう。

## ライセンス

MIT.
