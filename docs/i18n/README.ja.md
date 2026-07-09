# prove-it

[![verify](https://github.com/WhyNext/prove-it/actions/workflows/verify.yml/badge.svg)](https://github.com/WhyNext/prove-it/actions/workflows/verify.yml)
[![spec 0.1](https://img.shields.io/badge/spec-0.1-4F6134)](../../SPEC.md)
[![license MIT](https://img.shields.io/badge/license-MIT-lightgrey)](../../LICENSE)
![dependencies none](https://img.shields.io/badge/dependencies-none-4F6134)

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

あなたのエージェントは、リポジトリが自らを証明するまでターンを終えられない。

コーディングエージェントは、テストを一度も走らせていないのに「テストは通る」と報告し、バグを一度も再現していないのに「修正した」と報告する。エージェントには、自分が実際にやったことと、やろうとしたことを突き合わせる手段が無い。だから意図のほうを報告する。これは設計上の性質であって、性格の欠陥ではない。どんなプロンプトでも直らない。

`prove-it` は、その報告をチェックに変える。リポジトリのルートに `verify.sh` を置く。エージェントがターンを終えようとすると、フックがそのスクリプトを実行し、終了コードがゼロ以外なら、原因が直るまでターンは開いたままになる。

![完了したと主張するエージェントを prove-it がブロックする](../../docs/demo.svg)

私自身の使用では、失敗するゲートに当たったターンのうち半分弱が、まだ終わっていなかったとエージェントが認めて戻ってくる。そうでなければ、それらのターンは「完了」の一言で終わっていたはずだ。

## インストール

Claude Code プラグインとして:

```
/plugin marketplace add WhyNext/prove-it
/plugin install prove-it@whynext
```

プラグインは2つのフックを登録する。1つはセッションがファイルを編集したことを記録し、もう1つはターンをゲートする。さらに2つのコマンドを追加する。`/prove-it:init` は最初の `verify.sh` を書き、`/prove-it:ledger` はゲートが検出したものを読み返す。

他のエージェントを使う場合は、リポジトリをクローンして同じ2つのフックを自分で配線する。これらは素の bash で、`bash`、`git`、`python3` だけあればよい:

```bash
git clone https://github.com/WhyNext/prove-it ~/.local/share/prove-it
```

[`hooks/settings.example.json`](../../hooks/settings.example.json) を、1つのリポジトリだけなら `.claude/settings.json` に、すべてのリポジトリなら `~/.claude/settings.json` にマージする。ゲートは Stop hook の JSON ペイロードを標準入力から読み、終了コードで応答する。だから、ターン終了時にスクリプトを走らせられるものなら何でもこれを駆動できる。

そして、肝心のファイルを書く:

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

そのファイルが存在するまで、ゲートは何もしない。

## 最初の5分

望むより小さく始めよう。`git diff --check` だけを走らせる `verify.sh` でも持つ価値があり、それは通る。通ることで、リポジトリが良い状態のときゲートは静かなままだと分かる。

```bash
printf '#!/bin/bash\nset -eu\ncd "$(dirname "$0")"\ngit diff --check\n' > verify.sh
chmod +x verify.sh
./verify.sh                 # run it yourself first
```

次に、わざと失敗させる:

```bash
sed -i.bak 's|git diff --check|git diff --check\nexit 1|' verify.sh && rm verify.sh.bak
```

エージェントに何かファイルを編集させて、そのまま終わらせる。エージェントはターンを終えようとし、ゲートが `verify.sh` を実行し、ターンは開いたままになる。`exit 1` を取り除けば、同じエージェントがすんなり通り抜ける。失敗するのを自分の目で見ていないチェックは、決して出荷しないこと。

そこから、本物のチェックを一度に1つずつ足していく。実際に走らせているテストコマンド、次に型チェッカー、次に diff の衛生確認。足すチェックの1つ1つが、このリポジトリで「証明済み」とは何を意味するかという問いへの答えの1文になる。スクリプト全体でだいたい1分かかるところで止める。

よくある間違いは、初日から野心的な `verify.sh` を書くことだ。遅かったり不安定だったりするゲートは1週間で迂回されるようになり、迂回されたゲートは無いよりも悪い。何も走っていないのに、チェックが走ったと報告するからだ。

## 実行するかどうかの判断

次のすべてが成り立たない限り、ゲートは静かなままだ:

- このセッションがこのリポジトリのファイルを編集した
- 実行可能な `verify.sh` がリポジトリのルートに存在する
- ワーキングツリーにコミットされていない変更がある
- このツリー状態がまだ通過していない

最後の条件は、通過したツリーは停止のたびにではなく一度だけ検証されることを意味する。検証が失敗すると、エージェントは出力の最後の20行を目にする。たいていはそれで、何が悪かったかを教えられなくても原因を直せる。

`PROVE_IT_SKIP=1` は、意図的にゲートを越える。`verify.sh` を削除すれば完全に切れる。どちらの逃げ道も意図的なものだ。人は、取り除けないゲートを回避するようになる。

## エージェントがゲートを書き換えるとき

いちばん厄介な失敗のかたちは、不安定なチェックではない。`verify.sh` を通せず、代わりに `verify.sh` のほうを書き換えるエージェントだ。失敗メッセージはそうするなと告げるし、[SPEC.md](../../SPEC.md) はそれを修正ではなく違反と呼ぶ。だが、どちらも強制ではない。自分の diff を読むこと。仕様にある diff の証拠は、そのためにある。

## `verify.sh` の規約

`hooks/` にあるスクリプトは、意図的に小さくしてある。それが実装しているものは [SPEC.md](../../SPEC.md) に書かれている。リポジトリは、既知の場所で、既知の契約に従って、自らをどう証明するかを宣言する。そしてエージェントは、その証明が通るまで完了を主張してはならない。仕様はファイル名と終了コードを指定し、ベンダーは決して指定しない。だからプラグインは、アイデアそのものではなく、アイデアを配布する1つの方法にすぎない。

`verify.sh` が突き合わせるべき4種類の証拠 - コマンド出力、diff、再現、クロスチェック - と、適合レベルについては、仕様を読んでほしい。

## これがやらないこと

ゲートが強制するのは1つだけだ。ターンが終わる前に `verify.sh` がゼロを返したこと。そのゼロに意味があるかどうかは、あなたが書いたチェックに完全に依存する。`exit 0` だけの `verify.sh` はこのゲートを通過し、何も証明しない。

仕様はそれを Level 1 と呼ぶ。Level 2 は、あなたのチェックが本物の証拠に対して主張しているかどうかであり、それをあなたの代わりに検証できるツールは無い。このツールも含めて。

## レシピ

スタックごとの出発点が [`recipes/`](../../recipes/) にある。1つを `verify.sh` にコピーして、当てはまらない部分を削る。1分以内に収めること。遅いチェックは CI に属する。

| | |
|---|---|
| [`node.sh`](../../recipes/node.sh) | tests, typecheck, lint, diff hygiene |
| [`python.sh`](../../recipes/python.sh) | pytest, ruff, mypy |
| [`go.sh`](../../recipes/go.sh) | go test, vet, gofmt check |
| [`flutter.sh`](../../recipes/flutter.sh) | analyze, test, format check |

フックの配線は簡単な部分だ。難しいのは、あなたのリポジトリで「証明済み」とは何を意味するかに答えることであり、どんなレシピもそれをあなたの代わりに答えてはくれない。

## 台帳

`PROVE_IT_LEDGER=1` を設定すると、検出された偽の完了ごとに1行が `~/.prove-it/ledger.jsonl` に追記される:

```json
{"ts":"2026-07-09T04:12:33Z","claim":"All tests pass. Ready to merge.",
 "evidence_demanded":"verify.sh exit 0","actual":["3 failed, 41 passed"]}
```

その行は、エージェントが何を主張し、何を求められ、何が真だと分かったかを記録する。ファイルはモード `0600` でローカルディスクに書かれ、どこにも送信されず、あなたが有効にするまではオフのままだ。1か月分のエントリがたまれば、エージェントがどう失敗するかを推測するのをやめて、代わりにそれを読める。`/prove-it:ledger` がファイルを要約してくれる。

## このリポジトリは自分自身をゲートする

`prove-it` には `verify.sh` があり、それが走らせるものの一部はゲート自身だ。一時ディレクトリ内の本物の git リポジトリに対して走る。失敗するチェックはブロックし、通るチェックは許可し、読み取り専用のセッションは手を付けず、クリーンなツリーはスキップし、バイパスは機能する。

```bash
./verify.sh
```

CI は、同じスクリプトを Linux と macOS で走らせ、さらに、チェックが失敗するリポジトリをゲートがちゃんとブロックし続けることを証明する別ジョブを走らせる。

## コントリビュート

Issue と pull request を歓迎する。規約への変更は、リファレンス実装に対する pull request ではなく、issue に出すのがふさわしい。[CONTRIBUTING.md](../../CONTRIBUTING.md) を参照。

## ライセンス

MIT.
