# prove-it

[English](../../README.md) ·
[中文](README.zh.md) ·
[Deutsch](README.de.md) ·
[日本語](README.ja.md) ·
[हिन्दी](README.hi.md) ·
[Français](README.fr.md) ·
[Italiano](README.it.md) ·
Português ·
[Русский](README.ru.md) ·
[Español](README.es.md) ·
[한국어](README.ko.md)

**Seu agente não pode encerrar o turno até que seu repositório se prove.**

Agentes de código dizem "os testes passam" sem tê-los executado, e "corrigido" sem
nunca ter reproduzido o bug. Não por má-fé: um agente não consegue distinguir o que
fez daquilo que pretendia fazer, então ele relata a intenção.

O `prove-it` transforma *pronto* em algo que um agente tem que passar, não algo que
ele pode simplesmente dizer. Coloque um `verify.sh` na raiz do seu repositório.
Quando o agente tenta parar, o portão o executa. Saída diferente de zero, e o turno
não termina.

```
agent: "All tests pass. Ready to merge."
       └─ tries to end turn
          └─ prove-it runs ./verify.sh
             └─ exit 1:  FAIL src/auth.test.ts  (3 failed, 41 passed)
                └─ turn blocked, agent keeps working

agent: "Actually, three tests were failing. Fixing."
```

Em cerca de metade das vezes, um agente ao qual se pede evidência responde "você tem
razão, ainda não está pronto".

## Instalação

Requer `bash`, `git`, `python3`. Sem pacotes, sem daemon, nada em que se cadastrar.
Clone em qualquer lugar:

```bash
git clone https://github.com/YOUR_ORG/prove-it ~/.local/share/prove-it
```

Conecte os dois hooks ao Claude Code mesclando
[`hooks/settings.example.json`](../../hooks/settings.example.json) no seu
`.claude/settings.json` (por repositório) ou `~/.claude/settings.json` (em todo lugar).

Depois escreva o único arquivo que importa:

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

Essa é toda a configuração. Ainda não há um `verify.sh` no seu repositório, então até
você escrever um, o portão não faz absolutamente nada.

## Seus primeiros cinco minutos

Comece menor do que você imagina. Um `verify.sh` que roda apenas `git diff --check`
já vale a pena ter, e ele vai passar, o que te ensina que o portão fica quieto quando
está tudo bem.

```bash
printf '#!/bin/bash\nset -eu\ncd "$(dirname "$0")"\ngit diff --check\n' > verify.sh
chmod +x verify.sh
./verify.sh                 # run it yourself first. Never ship a check you have not seen pass.
```

Agora observe-o falhar de propósito, para você saber que o portão é real:

```bash
sed -i.bak 's|git diff --check|git diff --check\nexit 1|' verify.sh && rm verify.sh.bak
```

Peça ao seu agente para editar qualquer arquivo, depois deixe-o terminar. Ele vai
tentar encerrar o turno, o portão vai rodar `verify.sh`, e o turno será bloqueado.
Desfaça o `exit 1` e o mesmo agente passa sem obstáculos.

A partir daí, adicione um teste real de cada vez: o comando de teste que você
realmente roda, depois o verificador de tipos, depois a higiene de diff. Cada teste
que você adiciona é uma frase na sua resposta para *o que significa provado aqui*.
Pare quando a coisa toda levar cerca de um minuto.

O erro a evitar é escrever um `verify.sh` ambicioso no primeiro dia. Um portão lento
ou instável é contornado em uma semana, e um portão contornado é pior do que nenhum:
ele te diz que uma verificação aconteceu quando não aconteceu.

## Como ele decide rodar

O portão fica quieto por padrão. Ele roda `verify.sh` apenas quando cada uma destas
condições é verdadeira:

- a sessão de fato editou arquivos (uma sessão somente leitura não tem nada a provar)
- existe um `verify.sh` executável na raiz do repositório
- a árvore de trabalho tem mudanças não commitadas
- este exato estado da árvore ainda não passou

Essa última significa que uma árvore que passa é verificada uma vez, não a cada
parada. Falhas imprimem as últimas 20 linhas da saída para o agente, o que geralmente
é suficiente para ele corrigir a causa sem que ninguém lhe diga.

Para passar pelo portão de propósito: `PROVE_IT_SKIP=1`. Para desligá-lo de vez:
apague o `verify.sh`. Ambos são deliberados. Um portão que ninguém pode remover é um
portão que as pessoas contornam.

## Poder optar por sair é o recurso

O modo de falha mais difícil não é uma verificação instável. É um agente que não
consegue passar no `verify.sh` e silenciosamente edita o `verify.sh` em vez disso. A
mensagem de falha do portão diz isso com todas as letras, e a spec faz disso uma
violação declarada. Fique de olho nisso nos seus diffs mesmo assim. É para isso que
serve a evidência de diff.

## A convenção do `verify.sh`

O script em `hooks/` é pequeno de propósito. O artefato de verdade é a convenção que
ele implementa, escrita em **[SPEC.md](../../SPEC.md)**: um repositório declara como
se prova, em um lugar conhecido, com um contrato conhecido, e um agente não pode
reivindicar conclusão até que essa prova passe.

Leia a spec para os quatro tipos de evidência que um `verify.sh` deveria afirmar -
saída de comando, diff, reprodução, verificação cruzada - e para os níveis de
conformidade.

**Uma observação honesta logo de início.** Esta ferramenta impõe exatamente uma
coisa: que o `verify.sh` retornou zero antes de o turno terminar. Se esse zero
*significa* alguma coisa depende inteiramente das verificações que você escreveu. Um
`verify.sh` contendo apenas `exit 0` vai passar neste portão e não prova nada. A
ferramenta é Level 1. A evidência é Level 2, e o Level 2 é uma prática, não um recurso.

## Receitas

Pontos de partida por stack, em [`recipes/`](../../recipes/). Copie um para
`verify.sh` e corte o que não se aplica. Mantenha abaixo de um minuto; verificações
lentas pertencem ao CI.

| | |
|---|---|
| [`node.sh`](../../recipes/node.sh) | tests, typecheck, lint, diff hygiene |
| [`python.sh`](../../recipes/python.sh) | pytest, ruff, mypy |
| [`go.sh`](../../recipes/go.sh) | go test, vet, gofmt check |
| [`flutter.sh`](../../recipes/flutter.sh) | analyze, test, format check |

A parte difícil de adotar isto nunca é conectar o hook. É responder "o que significa
*provado* neste repositório" pela primeira vez.

## O registro

Defina `PROVE_IT_LEDGER=1` e cada conclusão falsa flagrada acrescenta uma linha a
`~/.prove-it/ledger.jsonl`:

```json
{"ts":"2026-07-09T04:12:33Z","claim":"All tests pass. Ready to merge.",
 "evidence_demanded":"verify.sh exit 0","actual":["3 failed, 41 passed"]}
```

O que foi reivindicado, o que foi exigido, o que era verdade. Somente disco local,
nunca transmitido, desligado a menos que você ligue. Depois de um mês, você para de
adivinhar como seu agente falha e começa a ler.

## Este repositório aplica o portão a si mesmo

O `prove-it` tem um `verify.sh`, e ele roda o portão contra repositórios git reais em
um diretório temporário: verificação que falha bloqueia, verificação que passa
permite, sessão somente leitura fica intocada, árvore limpa é pulada, o bypass
funciona.

```bash
./verify.sh
```

Seria uma coisa estranha de publicar de outra forma.

## Licença

MIT.
