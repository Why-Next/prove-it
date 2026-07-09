# prove-it

[![verify](https://github.com/Why-Next/prove-it/actions/workflows/verify.yml/badge.svg)](https://github.com/Why-Next/prove-it/actions/workflows/verify.yml)
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
script, e uma saída diferente de zero manda o agente de volta ao trabalho em vez
de deixá-lo parar.

![prove-it bloqueia um agente que afirma estar pronto](../../docs/demo.svg)

O portão empurra de volta até três vezes por turno e então cede, porque um hook
que nunca cede trava a sessão. Ceder não é o mesmo que passar, então a última
coisa que você vê é um aviso de que o turno terminou sem verificação, e não a
palavra "pronto". Três é um número que você pode mudar, e nada disso é uma
afirmação de que o seu agente não consegue passar pelo portão. É uma afirmação de
que ele não consegue passar pelo portão em silêncio.

Use quando um repositório tem um comando local que precisa ser verdadeiro antes
de um agente devolver o trabalho: testes, checagem de tipos, lint, verificações
de arquivos gerados, dry runs de migração ou um pequeno smoke test que prova que
o bug sumiu. `prove-it` é mais útil em repositórios onde um agente edita código e
diz "pronto" na mesma conversa.

Não use como sandbox, substituto de CI, nem lugar para jobs longos com rede. Se
uma verificação precisa de secrets, acesso de produção ou mais de cerca de um
minuto, coloque essa verificação no CI e mantenha o `verify.sh` como a prova
local que o agente consegue rodar enquanto ainda está trabalhando.

O fluxo do primeiro dia é pequeno de propósito. Instale o plugin, rode
`/prove-it:init`, mantenha o `git diff --check` gerado como a única verificação
ativa, e então ligue um comando real depois de vê-lo passar manualmente. A partir
daí, quando o agente muda o repositório e tenta parar, o `verify.sh` decide se
ele pode devolver o trabalho.

## Instalação

Três linhas, e a terceira faz o trabalho:

```
/plugin marketplace add Why-Next/prove-it
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
git clone https://github.com/Why-Next/prove-it ~/.local/share/prove-it
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
working tree dirty
blocks       up to 3 per turn, then it yields with a warning
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

- esta sessão mudou este repositório
- existe um `verify.sh` executável na raiz do repositório
- este exato estado da árvore ainda não passou

"Mudou" é respondido pelo repositório, não por um registro de quais ferramentas
rodaram. No início de uma sessão o hook registra como a árvore estava, e a cada
parada ele pergunta se a árvore ainda está assim. Um arquivo reescrito pelo
`sed`, um patch aplicado com `git apply`, um arquivo emitido por um gerador de
código, e um commit são todos mudanças, porque todos eles mudam a árvore. Uma
sessão que só leu não conta como nada, mesmo em um repositório que já estava sujo
quando ela abriu.

A última condição significa que uma árvore que passa é verificada uma vez em vez
de a cada parada. Quando a verificação falha, o agente vê as últimas vinte linhas
da saída, o que costuma bastar para ele corrigir a causa sem que lhe digam o que
deu errado.

`PROVE_IT_SKIP=1` passa pelo portão de propósito. Apagar o `verify.sh` entre
sessões o desliga de vez. Ambas as saídas de emergência são deliberadas: as
pessoas contornam um portão que não conseguem remover. `PROVE_IT_MAX_BLOCKS`
define quantas vezes um turno pode ser mandado de volta, e `0` faz o portão
relatar sem nunca bloquear.

## Quando o agente edita o portão

O modo de falha mais difícil não é uma verificação instável. É um agente que não
consegue fazer o `verify.sh` passar e edita o `verify.sh` em vez disso.

A versão mais barata disso é desarmar o portão de vez, então o portão a recusa. O
hook registra se o `verify.sh` era executável quando a sessão começou, e uma
sessão que termina com ele apagado ou com o seu bit de execução removido é
bloqueada, informada do que fez, e informada de como optar por sair honestamente
se era isso que ela queria. Apagar o `verify.sh` entre sessões ainda é uma saída
e ainda leva um comando.

O que continua sem imposição é a versão sutil: um agente que mantém o `verify.sh`
executável e silenciosamente esvazia as verificações dentro dele. A mensagem de
falha diz para não fazer isso, e o [SPEC.md](../../SPEC.md) chama isso de
violação, não de correção, mas nenhuma das duas coisas é imposição. Leia os seus
diffs. É para isso que serve a evidência de diff na spec.

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

Mais três fronteiras, ditas claramente porque de outra forma você as encontrará
em um mau momento. O portão cede depois de `PROVE_IT_MAX_BLOCKS` recusas, então
um agente determinado chega ao fim do seu turno; o que ele não consegue fazer é
chegar lá em silêncio. Os arquivos que o seu `.gitignore` exclui são invisíveis
para a detecção de mudanças, então um `verify.sh` que lê um `.env` ignorado pode
ser pulado quando só esse arquivo mudou. E uma sessão que começa fora do
repositório que ela depois edita não tem baseline para comparar, o que rebaixa o
portão ao teste mais fraco de se a árvore de trabalho está suja.

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
fica intocada, uma árvore limpa depois de um commit não é confundida com ausência
de trabalho, o bypass funciona.

```bash
./verify.sh
```

O CI roda esse mesmo script no Linux e no macOS, além de um job separado que
prova que o portão ainda bloqueia um repositório cujas verificações falham. O
repositório também roda CodeQL, OpenSSF Scorecard e um workflow de release por
tag que empacota o código-fonte com checksum e attestation de proveniência do
GitHub.

## Confiança no projeto

Leia [SECURITY.md](../../SECURITY.md) antes de usar isto em repositórios nos
quais você não confia. `prove-it` executa o `verify.sh` pertencente ao
repositório; é uma guardrail, não uma sandbox.

Os passos de release ficam em [RELEASE.md](../../RELEASE.md), incluindo a
checklist de verificação, status dos workflows, checksums e attestation de
proveniência. Os limites de suporte ficam em [SUPPORT.md](../../SUPPORT.md).

## Contribuindo

Issues e pull requests são bem-vindos. Mudanças na convenção pertencem a uma
issue, não a um pull request contra a implementação de referência. Veja
[CONTRIBUTING.md](../../CONTRIBUTING.md).

## Licença

MIT.
