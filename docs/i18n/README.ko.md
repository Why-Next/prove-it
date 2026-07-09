# prove-it

[![verify](https://github.com/WhyNext/prove-it/actions/workflows/verify.yml/badge.svg)](https://github.com/WhyNext/prove-it/actions/workflows/verify.yml)
[![spec 0.1](https://img.shields.io/badge/spec-0.1-4F6134)](../../SPEC.md)
[![license MIT](https://img.shields.io/badge/license-MIT-lightgrey)](../../LICENSE)
![dependencies none](https://img.shields.io/badge/dependencies-none-4F6134)

[English](../../README.md) ·
[中文](README.zh.md) ·
[Deutsch](README.de.md) ·
[日本語](README.ja.md) ·
[हिन्दी](README.hi.md) ·
[Français](README.fr.md) ·
[Italiano](README.it.md) ·
[Português](README.pt.md) ·
[Русский](README.ru.md) ·
[Español](README.es.md) ·
한국어

**당신의 레포가 스스로를 증명하기 전까지, 에이전트는 자기 차례를 끝낼 수 없습니다.**

코딩 에이전트는 테스트를 돌려보지도 않고 "테스트 통과"라고 말하고, 버그를 재현해본 적도 없이 "고쳤다"고 말합니다. 악의가 있어서가 아닙니다. 에이전트는 자기가 실제로 한 일과 하려던 일을 구분하지 못하기 때문에, 의도를 그대로 보고할 뿐입니다.

`prove-it`는 *완료*를 에이전트가 그냥 말할 수 있는 것이 아니라 통과해야만 하는 것으로 만듭니다. 레포 루트에 `verify.sh`를 두세요. 에이전트가 멈추려고 하면 게이트가 이걸 실행합니다. 종료 코드가 0이 아니면 그 차례는 끝나지 않습니다.

![완료됐다고 주장하는 에이전트를 prove-it가 막는 모습](../../docs/demo.svg)

증거를 요구받은 에이전트는 대략 절반의 경우 "맞아요, 아직 안 끝났네요"라고 답합니다.

## 설치

Claude Code 플러그인으로:

```
/plugin marketplace add WhyNext/prove-it
/plugin install prove-it@whynext
```

설치는 이게 전부입니다. 플러그인은 훅 두 개를 등록합니다. 하나는 세션이 파일을 편집했다는 걸 표시하고, 하나는 차례를 게이트합니다.

다른 에이전트를 쓰거나 플러그인을 설치하고 싶지 않다면, 레포를 클론해서 같은 훅 두 개를 직접 연결하세요. 훅은 평범한 bash이고 `bash`, `git`, `python3` 말고는 아무것도 필요로 하지 않습니다:

```bash
git clone https://github.com/WhyNext/prove-it ~/.local/share/prove-it
```

[`hooks/settings.example.json`](../../hooks/settings.example.json)을 `.claude/settings.json`(레포별) 또는 `~/.claude/settings.json`(전역)에 병합하세요. 게이트는 stdin으로 Stop 훅 JSON 페이로드를 읽고 종료 코드로 소통하므로, 차례가 끝나는 시점에 스크립트를 돌릴 수 있는 것이라면 무엇이든 이걸 구동할 수 있습니다.

그런 다음 정말 중요한 유일한 파일을 작성합니다:

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

그 파일을 작성하기 전까지는 게이트가 아무 일도 하지 않습니다.

## 처음 5분

생각보다 더 작게 시작하세요. `git diff --check`만 돌리는 `verify.sh`도 이미 갖출 가치가 있고, 통과할 겁니다. 그러면 문제가 없을 때 게이트가 조용하다는 걸 배우게 됩니다.

```bash
printf '#!/bin/bash\nset -eu\ncd "$(dirname "$0")"\ngit diff --check\n' > verify.sh
chmod +x verify.sh
./verify.sh                 # run it yourself first. Never ship a check you have not seen pass.
```

이제 일부러 실패시켜 보면서 게이트가 진짜라는 걸 확인하세요:

```bash
sed -i.bak 's|git diff --check|git diff --check\nexit 1|' verify.sh && rm verify.sh.bak
```

에이전트에게 아무 파일이나 편집하게 시킨 다음 마무리하도록 두세요. 에이전트가 차례를 끝내려 하면 게이트가 `verify.sh`를 실행하고, 그 차례는 막힙니다. `exit 1`을 되돌리면 같은 에이전트가 무사히 통과합니다.

거기서부터 진짜 검사를 하나씩 추가하세요. 실제로 돌리는 테스트 명령, 그다음 타입 체커, 그다음 diff 위생 검사. 검사를 하나 추가할 때마다 *여기서 증명됐다는 게 무슨 뜻인가*에 대한 당신의 답에 한 문장이 채워집니다. 전체가 대략 1분 정도 걸리는 지점에서 멈추세요.

피해야 할 실수는 첫날부터 야심 찬 `verify.sh`를 작성하는 겁니다. 느리거나 불안정한 게이트는 일주일 안에 우회당하고, 우회당한 게이트는 없느니만 못합니다. 검사가 일어나지 않았는데도 일어났다고 알려주니까요.

## 실행 여부를 판단하는 방식

게이트는 기본적으로 조용합니다. 다음 조건이 모두 참일 때만 `verify.sh`를 실행합니다:

- 세션이 실제로 파일을 편집했다 (읽기 전용 세션은 증명할 게 없습니다)
- 레포 루트에 실행 가능한 `verify.sh`가 존재한다
- 워킹 트리에 커밋되지 않은 변경이 있다
- 바로 이 트리 상태가 아직 통과한 적이 없다

마지막 조건은, 통과한 트리는 멈출 때마다가 아니라 한 번만 검증된다는 뜻입니다. 실패하면 출력의 마지막 20줄이 에이전트에게 출력되는데, 대개 이 정도면 따로 알려주지 않아도 에이전트가 원인을 고칩니다.

일부러 게이트를 통과하려면 `PROVE_IT_SKIP=1`. 아예 꺼버리려면 `verify.sh`를 삭제하세요. 둘 다 의도적인 선택입니다. 아무도 못 없애는 게이트는 결국 사람들이 돌아가는 게이트가 됩니다.

## 빠져나갈 수 있다는 게 핵심 기능입니다

가장 다루기 힘든 실패 양상은 불안정한 검사가 아닙니다. `verify.sh`를 통과하지 못하자 조용히 `verify.sh` 자체를 편집해버리는 에이전트입니다. 게이트의 실패 메시지가 대놓고 그렇게 말하고, 스펙은 이걸 명시된 위반으로 규정합니다. 그래도 당신의 diff에서 이걸 눈여겨보세요. diff 증거가 바로 그래서 있는 겁니다.

## `verify.sh` 컨벤션

`hooks/`에 있는 스크립트는 일부러 작게 만들었습니다. 진짜 산출물은 그 스크립트가 구현하는 컨벤션이고, 이건 **[SPEC.md](../../SPEC.md)**에 적혀 있습니다. 레포는 자기가 어떻게 스스로를 증명하는지를 알려진 위치에서 알려진 계약으로 선언하고, 에이전트는 그 증명이 통과하기 전까지 완료를 주장할 수 없습니다.

플러그인은 배포 통로일 뿐 아이디어 자체가 아닙니다. 컨벤션은 어느 한 에이전트보다 오래 살아남도록 만들어졌기에, 스펙은 파일과 종료 코드를 명시할 뿐 특정 벤더는 절대 명시하지 않습니다.

`verify.sh`가 검증해야 할 네 종류의 증거 - 명령 출력, diff, 재현, 교차 확인 - 와 준수 레벨에 대해서는 스펙을 읽어보세요.

**미리 솔직하게 짚어둘 점 하나.** 이 도구가 강제하는 건 딱 하나입니다. 차례가 끝나기 전에 `verify.sh`가 0을 반환했다는 사실. 그 0이 *무언가를 의미하는지*는 전적으로 당신이 작성한 검사에 달려 있습니다. `exit 0`만 들어 있는 `verify.sh`는 이 게이트를 통과하지만 아무것도 증명하지 않습니다. 도구는 Level 1입니다. 증거는 Level 2이고, Level 2는 기능이 아니라 실천입니다.

## 레시피

스택별 출발점이 [`recipes/`](../../recipes/)에 있습니다. 하나를 `verify.sh`로 복사하고 안 맞는 건 잘라내세요. 1분 안쪽으로 유지하고, 느린 검사는 CI에 두세요.

| | |
|---|---|
| [`node.sh`](../../recipes/node.sh) | tests, typecheck, lint, diff hygiene |
| [`python.sh`](../../recipes/python.sh) | pytest, ruff, mypy |
| [`go.sh`](../../recipes/go.sh) | go test, vet, gofmt check |
| [`flutter.sh`](../../recipes/flutter.sh) | analyze, test, format check |

이걸 도입할 때 어려운 부분은 훅을 연결하는 게 아닙니다. "이 레포에서 *증명됐다*는 게 무슨 뜻인가"에 처음으로 답하는 겁니다.

## 원장(ledger)

`PROVE_IT_LEDGER=1`을 설정하면, 잡아낸 거짓 완료 하나하나가 `~/.prove-it/ledger.jsonl`에 한 줄씩 덧붙습니다:

```json
{"ts":"2026-07-09T04:12:33Z","claim":"All tests pass. Ready to merge.",
 "evidence_demanded":"verify.sh exit 0","actual":["3 failed, 41 passed"]}
```

무엇을 주장했고, 무엇을 요구받았고, 무엇이 사실이었는지. 로컬 디스크에만 남고, 절대 전송되지 않으며, 당신이 켜기 전까지는 꺼져 있습니다. 한 달이 지나면 에이전트가 어떻게 실패하는지 짐작하는 걸 그만두고 그냥 읽기 시작하게 됩니다.

## 이 레포는 스스로를 게이트합니다

`prove-it`에는 `verify.sh`가 있고, 임시 디렉터리에서 실제 git 레포를 상대로 게이트를 돌립니다. 실패하는 검사는 막고, 통과하는 검사는 허용하고, 읽기 전용 세션은 건드리지 않고, 깨끗한 트리는 건너뛰고, 우회는 동작합니다.

```bash
./verify.sh
```

안 그랬다면 내놓기에 이상한 물건이었겠죠.

## 기여하기

이슈와 풀 리퀘스트를 환영합니다. 컨벤션 자체를 바꾸는 일은 레퍼런스 구현에 대한 풀 리퀘스트보다 이슈로 올려야 합니다. 컨벤션이 산출물이고, 스크립트는 각주니까요. [CONTRIBUTING.md](../../CONTRIBUTING.md)를 참고하세요.

## 라이선스

MIT.
