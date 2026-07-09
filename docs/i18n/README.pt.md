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
Português ·
[Русский](README.ru.md) ·
[Español](README.es.md) ·
[한국어](README.ko.md)

Seu agente não pode encerrar o turno até que o seu repositório se prove.

Agentes de código relatam que os testes passam quando nunca os rodaram, e que um
bug está corrigido quando nunca o reproduziram. O agente não tem como comparar o
que fez com o que pretendia fazer, então relata a intenção. Isso é uma
propriedade do design, não um defeito de caráter, e nenhum prompt conserta.

O `prove-it` transforma o relato em uma verificação. Coloque um `verify.sh` na
raiz do seu repositório. Quando o agente tenta encerrar o turno, um hook roda o
script, e uma saída diferente de zero mantém o turno aberto até que a causa seja
corrigida.

![prove-it bloqueia um agente que afirma estar pronto](../../docs/demo.svg)

No meu próprio uso, um pouco menos da metade dos turnos que batem em um portão
que falha voltam com o agente admitindo que não tinha terminado. Esses turnos, de
outra forma, teriam terminado com a palavra "pronto".

## Instalação

Três linhas, e a terceira faz o trabalho:

```
/plugin marketplace add WhyNext/prove-it
/plugin install prove-it@whynext
/prove-it:init
```

O `/prove-it:init` detecta a sua stack, escreve um `verify.sh`, roda-o para que
você o veja passar, depois roda uma cópia com `exit 1` acrescentado para que você
veja o portão recusar um turno. Leva cerca de trinta segundos e nunca sobrescreve
um `verify.sh` que você já tenha.

O portão gerado tem exatamente uma verificação ativa, `git diff --check`, com as
verificações para a sua stack escritas como comentários. Ele passa no dia em que
você o instala, deliberadamente. Um portão que falha na `main` no dia em que
chega ensina as pessoas a contorná-lo na primeira semana. Ligue as verificações
comentadas uma de cada vez, depois de ter visto cada uma passar à mão.

Nada mais é configurado, e nada roda até um `verify.sh` existir. Se você abre um
repositório que não tem nenhum, o plugin avisa isso no início da sessão em vez de
ficar quieto e deixar você supor que está coberto.

## Sem o plugin

Os hooks são bash puro e precisam apenas de `bash`, `git` e `python3`:

```bash
git clone https://github.com/WhyNext/prove-it ~/.local/share/prove-it
~/.local/share/prove-it/bin/prove-it init
```

Mescle [`hooks/settings.example.json`](../../hooks/settings.example.json) no seu
`.claude/settings.json` para um repositório, ou `~/.claude/settings.json` para
todos eles. O portão lê um payload JSON do Stop hook no stdin e responde com um
código de saída, então qualquer coisa capaz de rodar um script no fim do turno
consegue acioná-lo.

O `prove-it doctor` responde se o portão dispararia no repositório em que você
está, e diz o que o está impedindo caso não dispare:

```
repository   /home/you/src/api
verify.sh    present and executable
working tree dirty, so the gate would run on the next stop
state        /home/you/.local/state/prove-it
ledger       off (export PROVE_IT_LEDGER=1 to record what the gate catches)
```

## Fazendo o portão crescer

Cada verificação que você adiciona é uma frase na sua resposta à pergunta do que
"provado" significa neste repositório. Adicione o comando de teste que você
realmente roda, depois o verificador de tipos, depois o que quer que as suas
revisões sempre peguem. Pare quando o script inteiro levar cerca de um minuto;
verificações lentas pertencem ao CI.

Rode cada verificação à mão antes de ligá-la. Nunca publique também uma
verificação que você não viu falhar: uma verificação que não consegue falhar não
é uma verificação, e você não vai descobrir isso no dia em que precisar dela.

O erro comum é escrever um `verify.sh` ambicioso no primeiro dia. Um portão lento
ou instável é contornado em uma semana, e um portão contornado é pior do que
nenhum portão, porque relata que uma verificação rodou quando nada rodou.

## Como ele decide rodar

O portão fica quieto a menos que todas estas condições valham:

- esta sessão editou arquivos neste repositório
- existe um `verify.sh` executável na raiz do repositório
- a árvore de trabalho tem mudanças não commitadas
- este exato estado da árvore ainda não passou

A última condição significa que uma árvore que passa é verificada uma vez em vez
de a cada parada. Quando a verificação falha, o agente vê as últimas vinte linhas
da saída, o que costuma bastar para ele corrigir a causa sem que lhe digam o que
deu errado.

`PROVE_IT_SKIP=1` passa pelo portão de propósito. Apagar o `verify.sh` o desliga
de vez. Ambas as saídas de emergência são deliberadas: as pessoas contornam um
portão que não conseguem remover.

## Quando o agente edita o portão

O modo de falha mais difícil não é uma verificação instável. É um agente que não
consegue fazer o `verify.sh` passar e edita o `verify.sh` em vez disso. A
mensagem de falha diz para não fazer isso, e o [SPEC.md](../../SPEC.md) chama
isso de violação, não de correção, mas nenhuma das duas coisas é imposição. Leia
os seus diffs. É para isso que serve a evidência de diff na spec.

## A convenção do `verify.sh`

O script em `hooks/` é pequeno de propósito. O que ele implementa está escrito no
[SPEC.md](../../SPEC.md): um repositório declara como se prova, em um caminho
conhecido, com um contrato conhecido, e um agente não pode reivindicar conclusão
até que essa prova passe. A spec nomeia um arquivo e um código de saída e nunca
nomeia um fornecedor, então o plugin é uma forma de distribuir a ideia, não a
ideia em si.

Leia a spec para os quatro tipos de evidência contra os quais um `verify.sh`
deveria afirmar, que são saída de comando, diff, reprodução e verificação
cruzada, e para os níveis de conformidade.

## O que isto não faz

O portão impõe uma coisa: que o `verify.sh` retornou zero antes de o turno
terminar. Se esse zero significa alguma coisa depende inteiramente das
verificações que você escreveu. Um `verify.sh` que contém apenas `exit 0` passa
neste portão e não prova nada.

A spec chama isso de Level 1. O Level 2 é se as suas verificações afirmam contra
evidência real, e nenhuma ferramenta consegue verificar isso por você, incluindo
esta.

## Receitas

Pontos de partida por stack ficam em [`recipes/`](../../recipes/). Copie um para
`verify.sh` e corte o que não se aplica. Mantenha abaixo de um minuto;
verificações lentas pertencem ao CI.

| | |
|---|---|
| [`node.sh`](../../recipes/node.sh) | testes, typecheck, lint, higiene de diff |
| [`python.sh`](../../recipes/python.sh) | pytest, ruff, mypy |
| [`go.sh`](../../recipes/go.sh) | go test, vet, gofmt check |
| [`flutter.sh`](../../recipes/flutter.sh) | analyze, test, format check |

Conectar o hook é a parte fácil. O trabalho é responder o que "provado" significa
no seu repositório, e nenhuma receita responde isso por você.

## O registro

Defina `PROVE_IT_LEDGER=1` e cada conclusão falsa flagrada acrescenta uma linha a
`~/.prove-it/ledger.jsonl`:

```json
{"ts":"2026-07-09T04:12:33Z","claim":"All tests pass. Ready to merge.",
 "evidence_demanded":"verify.sh exit 0","actual":["3 failed, 41 passed"]}
```

A linha registra o que o agente afirmou, o que foi exigido dele, e o que acabou
sendo verdade. O arquivo é escrito no disco local com o modo `0600`, nada o
transmite para lugar nenhum, e ele fica desligado até você ligar. Depois de um
mês de entradas, você pode parar de adivinhar como o seu agente falha e ler isso
em vez disso. O `/prove-it:ledger` resume o arquivo para você, assim como
`prove-it ledger` na linha de comando.

## Este repositório aplica o portão a si mesmo

O `prove-it` tem um `verify.sh`, e parte do que ele roda é o próprio portão,
contra repositórios git reais em um diretório temporário: uma verificação que
falha bloqueia, uma verificação que passa permite, uma sessão somente leitura
fica intocada, uma árvore limpa é pulada, o bypass funciona.

```bash
./verify.sh
```

O CI roda esse mesmo script no Linux e no macOS, além de um job separado que
prova que o portão ainda bloqueia um repositório cujas verificações falham.

## Contribuindo

Issues e pull requests são bem-vindos. Mudanças na convenção pertencem a uma
issue, não a um pull request contra a implementação de referência. Veja
[CONTRIBUTING.md](../../CONTRIBUTING.md).

## Licença

MIT.
