# Contribuindo

## Onde uma mudança pertence

Este repositório contém duas coisas de peso diferente.

O [SPEC.md](../../SPEC.md) descreve uma convenção que outras ferramentas deveriam
conseguir implementar sem ler uma linha deste código. Mudanças nele começam como
uma issue, para que a discussão aconteça antes de alguém escrever um patch. Um
pull request que amplia o contrato em silêncio é mais difícil de contestar do que
uma proposta que diz com clareza o que quer mudar.

O `hooks/prove-it.sh` é uma implementação dessa convenção, com umas setenta e
poucas linhas, e pull requests contra ele não precisam de cerimônia.

Se você não tiver certeza de qual dos dois está tocando, abra uma issue e
pergunte.

## O portão se aplica a você também

Este repositório tem um `verify.sh`. Rode-o antes de abrir um pull request:

```bash
./verify.sh
```

Ele verifica a sintaxe do shell, roda o shellcheck, valida os manifestos do
plugin, impõe as regras de prosa abaixo, mantém as traduções fiéis aos originais
em inglês, e roda a própria suíte de testes do portão contra repositórios git
reais em um diretório temporário. O CI roda o mesmo script no Linux e no macOS,
além de um job separado que prova que o portão ainda bloqueia um repositório
cujas verificações falham.

Se o `verify.sh` falhar, corrija a causa. Não enfraqueça o `verify.sh`. Essa é a
única mudança que este projeto não vai integrar, pela razão pela qual o projeto
existe.

## Adicionando uma verificação

Uma nova verificação é bem-vinda quando teria pego um bug real. Quebre algo de
propósito, observe a sua verificação notar, depois corrija e commite as duas
coisas. Uma verificação que ninguém viu falhar não é uma verificação.

Dois dos scripts em `scripts/` existem porque as suas primeiras versões passaram
contra uma base de código que já estava quebrada.

## Traduções

O `README.md` e o `SPEC.md` são canônicos, e o texto em inglês do `SPEC.md`
prevalece onde uma tradução discorda dele. O `scripts/check_i18n.py` mantém cada
tradução fiel ao seu original: contagem de títulos, se os títulos foram de fato
traduzidos, se os acentos sobreviveram, se os blocos de código são idênticos byte
a byte ao inglês, e se os links relativos resolvem.

Duas regras derrubam as pessoas.

Nunca use um traço longo. Nada de travessão, meia-risca, barra horizontal ou
sinal de menos. Apenas o hífen ASCII comum, em todo idioma, incluindo aqueles
cuja tipografia prefere o contrário, porque um traço longo soa como texto escrito
por máquina. (Este parágrafo nomeia os caracteres em vez de mostrá-los, já que o
`scripts/check_no_long_dash.py` também lê este arquivo.)

Sempre mantenha os acentos. A regra do traço cobre seis caracteres específicos e
não é uma proibição de não-ASCII. `décidé` continua `décidé`, e `è` nunca vira
`e'`. Uma tradução antiga removeu todos os acentos do arquivo por aplicar demais
a primeira regra.

## Receitas

Uma receita é um ponto de partida para uma stack, não um `verify.sh` acabado.
Mantenha-a abaixo de um minuto de execução, prefira verificações que produzem
evidência a verificações que produzem opiniões, e anote qual dos quatro tipos de
evidência da spec cada verificação entrega.

## Commits

Conventional commits (`feat:`, `fix:`, `docs:`, `chore:`). Diga no corpo o que
mudou e por quê. Se você corrigiu um bug, diga como o reproduziu.

## Releases

Mantenedores seguem [RELEASE.md](../../RELEASE.md). Uma release precisa de um
`./verify.sh` local limpo, workflows `verify`, `codeql` e `scorecard` verdes em
`main`, e o checksum mais a attestation de proveniência do workflow de tag. Não
publique a partir de uma árvore não verificada.
