# A convenção do `verify.sh`

> Este texto em inglês é a versão normativa. Existem traduções para
> [中文](SPEC.zh.md) ·
> [Deutsch](SPEC.de.md) ·
> [日本語](SPEC.ja.md) ·
> [हिन्दी](SPEC.hi.md) ·
> [Français](SPEC.fr.md) ·
> [Italiano](SPEC.it.md) ·
> Português ·
> [Русский](SPEC.ru.md) ·
> [Español](SPEC.es.md) ·
> [한국어](SPEC.ko.md).
> Elas são informativas. Onde uma tradução e este texto discordarem, o texto em
> inglês em [SPEC.md](../../SPEC.md) prevalece e a tradução é um bug a ser reportado.

Versão 0.1 (rascunho). Um repositório declara como se prova, e um agente não pode
reivindicar conclusão até que essa prova passe.

Este documento é o contrato. O script em `hooks/` é uma implementação dele, e
deliberadamente pequena. Leia a seção 5 sobre níveis de conformidade antes de
supor que a ferramenta impõe tudo o que está escrito aqui.

## 1. O problema

Agentes de código encerram turnos com frases como estas:

- "Os testes passam." Os testes nunca foram rodados.
- "Corrigi o bug." O bug nunca foi reproduzido.
- "A migração é segura." Nada foi aplicado a um banco de dados de teste.

Essas não são mentiras no sentido comum. Um agente não consegue distinguir o que
fez do que pretendia fazer, então o seu relato descreve a intenção. A falha é
estrutural, e prompt nenhum vai removê-la. A técnica de prompt também envelhece a
cada geração de modelo, enquanto uma exigência de evidência fica uma camada acima
do modelo e sobrevive à atualização.

Então "pronto" deixa de ser algo que um agente declara e se torna uma verificação
que ele tem que passar.

## 2. A convenção

Um repositório conforme tem um arquivo executável `verify.sh` na sua raiz.

```
your-repo/
  verify.sh      <- executable, exit 0 means "this tree is provably fine"
```

O contrato:

| | |
|---|---|
| Local | raiz do repositório |
| Modo | executável (`chmod +x`) |
| Invocação | rodado com o CWD na raiz do repositório, sem argumentos |
| Saída `0` | verificação passou |
| Saída diferente de `0` | verificação falhou; stdout e stderr explicam por quê |
| Saída (output) | legível por humanos; as últimas 20 linhas são o que um agente vê |
| Tempo de execução | abaixo de um minuto; verificações lentas pertencem ao CI |
| Ausente | sem portão. A ausência é um estado válido, não uma falha |

O `verify.sh` responde uma pergunta: o que precisaria ser verdade para que uma
mudança aqui fosse comprovadamente segura de devolver? Cada repositório responde
isso de um jeito, e é por isso que esta convenção nomeia o arquivo e não o seu
conteúdo.

Optar por sair leva uma ação: apague o `verify.sh`, ou reduza-o a `exit 0`. Isso
é intencional. As pessoas contornam um portão que não conseguem remover, e um
portão contornado ainda relata sucesso.

## 3. Os quatro tipos de evidência

Um `verify.sh` deveria afirmar contra evidência, não contra crença. Quatro tipos
têm peso. Um `verify.sh` útil cobre pelo menos um, e um maduro cobre os quatro ao
longo das verificações que roda.

**Saída de comando.** Um comando rodou e a verificação leu o seu código de saída.
Não "os testes deveriam passar", mas o veredito do próprio executor de testes.

**Diff.** A mudança é o que foi pretendido e nada além disso: sem instruções de
depuração, sem arquivos soltos, sem rebuliço de formatação sem relação. O
`git diff --check` é o piso.

**Reprodução.** Para a correção de um bug, a falha foi observada antes da mudança
e está ausente depois dela. Uma correção que nunca foi reproduzida é um palpite
sobre qual linha estava errada.

**Verificação cruzada.** Uma segunda fonte, independente, concorda. Outro modelo,
outra ferramenta, um verificador de tipos contra uma suíte de testes. A
independência é o que dá valor a isso; duas verificações que compartilham uma
suposição confirmam a suposição, não o código.

As quatro categorias existem para que "eu verifiquei" tenha que nomear um método.
Um agente que não consegue dizer qual dos quatro tipos de evidência ele tem não
tem nenhum deles.

## 4. O que as implementações devem fazer

Uma implementação desta convenção é um portão. Para ser conforme, ela deve:

1. Rodar o `verify.sh` a partir da raiz do repositório antes que o turno do
   agente possa terminar.
2. Bloquear o turno em uma saída diferente de zero, e mostrar a saída.
3. Não fazer nada quando o `verify.sh` está ausente ou não é executável.
4. Não fazer nada quando a sessão não fez edições naquele repositório.
5. Fornecer um bypass explícito e localizável com grep. Um bypass silencioso
   ensina as pessoas a desconfiar do portão; um auditado o mantém honesto.

Ela não deve modificar o `verify.sh`, e deve dizer ao agente que enfraquecer o
`verify.sh` para passar pelo portão é uma violação, não uma correção. Esse é o
modo de falha mais provável na prática. Um agente que não consegue passar em uma
verificação vai, dada a oportunidade, editar a verificação.

## 5. Níveis de conformidade

Seja preciso sobre o que uma máquina impõe e o que uma pessoa pratica. Essa
distinção importa mais do que a ambição por trás da convenção.

**Level 1, o portão.** O `verify.sh` existe, e algo mecanicamente se recusa a
deixar um turno terminar enquanto ele falha. A implementação de referência em
`hooks/` impõe isso por completo, e é onde todo repositório deveria começar.

**Level 2, a evidência.** As verificações dentro do `verify.sh` cobrem os quatro
tipos de evidência da seção 3. Nenhuma ferramenta impõe isso, incluindo esta. O
portão verifica que o seu `verify.sh` retornou zero. Se esse zero significa
alguma coisa é uma afirmação sobre as verificações que você escreveu, e um
`verify.sh` que contém apenas `exit 0` alcança o Level 1 sem provar nada.

**Level 3, o registro.** Cada conclusão falsa flagrada é registrada, para que os
modos de falha se tornem dados em vez de anedota. A implementação de referência
escreve isso apenas quando explicitamente habilitado.

O Level 1 é uma propriedade de uma ferramenta. O Level 2 é uma propriedade dos
hábitos de uma equipe, e qualquer ferramenta que afirme entregá-lo está
entregando o Level 1 e torcendo para que ninguém leia o código-fonte.

## 6. O formato do registro

Quando habilitado, cada conclusão falsa flagrada acrescenta um objeto JSON por
linha:

```json
{
  "ts": "2026-07-09T04:12:33Z",
  "repo": "/home/you/src/api",
  "exit_code": 1,
  "claim": "All tests pass. Ready to merge.",
  "evidence_demanded": "verify.sh exit 0",
  "actual": ["FAIL src/auth.test.ts", "3 failed, 41 passed"]
}
```

`claim` guarda a última mensagem do próprio agente antes de ele tentar parar. É o
campo mais útil do registro e o mais sensível, já que pode conter qualquer texto
da conversa. Uma implementação deve escrever o registro no disco local com
permissões restritivas e nunca deve transmiti-lo.

Uma linha guarda três coisas: o que foi afirmado, o que foi exigido, e o que era
verdade.

## 7. Não-objetivos

Esta convenção não diz o que você deve verificar, não roda o seu CI, não pontua o
seu código, e não substitui a revisão. Ela responde uma única pergunta, que é se
este repositório se provou antes de o agente ir embora.

---

*Propostas para mudar este documento pertencem a uma issue, não a um pull request
contra a implementação de referência. Cada adição aqui é algo que toda
implementação futura tem que carregar.*
