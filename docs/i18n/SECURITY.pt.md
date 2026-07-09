# Segurança

## O que este software faz na sua máquina

O `prove-it` roda um script que vive no repositório que você tem aberto. Se você
abre um repositório em que não confia, e o `verify.sh` dele é executável, o seu
agente encerrando um turno vai executar esse arquivo.

Esse comportamento é o design, não um defeito nele, e o risco é o mesmo que você
já aceita quando roda `npm install` ou abre um projeto com um `Makefile`. Leia um
`verify.sh` desconhecido antes de deixar um agente trabalhar no repositório que o
contém, do mesmo jeito que você leria um script `postinstall` desconhecido.

O portão só roda quando a sessão editou arquivos **naquele mesmo repositório**, a
árvore de trabalho está suja, e existe um `verify.sh` executável na raiz do
repositório. Clonar e ler um repositório nunca o dispara, e editar um repositório
nunca faz o `verify.sh` de outro repositório rodar.

## O que ele escreve no disco

Dois marcadores, ambos em um diretório privado criado com o modo `0700`:
`$XDG_STATE_HOME/prove-it/`, ou `~/.local/state/prove-it/` quando isso não está
definido. Sobrescreva com `PROVE_IT_STATE_DIR`. Nada é escrito no `/tmp`
compartilhado, porque esses nomes de arquivo são derivados do caminho do
repositório e portanto previsíveis, e um nome previsível em um diretório gravável
por todos é um alvo de symlink.

O registro opcional (`PROVE_IT_LEDGER=1`, **desligado por padrão**) acrescenta
uma linha JSON por conclusão falsa flagrada a `~/.prove-it/ledger.jsonl`, criado
com o modo `0600` dentro de um diretório `0700`. Cada linha guarda:

- a última mensagem do agente antes de ele tentar parar, truncada em 300
  caracteres e extraída do seu transcript local, então pode conter qualquer coisa
  que estava na sua conversa
- o caminho absoluto do repositório
- o código de saída e as últimas cinco linhas da saída do seu `verify.sh`
- um timestamp

Trate-o como dados de conversa. Nada neste projeto o lê de volta ou o envia para
lugar nenhum, mas ele continua sendo um arquivo comum, então os seus backups vão
copiá-lo e qualquer pessoa com acesso de leitura ao seu diretório home pode
abri-lo.

## O que ele envia

Nada. O software que roda na sua máquina não contém telemetria, nenhuma chamada
de rede, e nenhuma verificação de atualização. Você pode confirmar isso com um
único grep por `curl`, `wget`, `urllib`, `requests` ou `socket` em `hooks/` e
`scripts/`.

A integração contínua é a única exceção, e não é código que você roda: o workflow
do GitHub Actions instala o `shellcheck` a partir do `apt` ou do `brew` antes de
rodar o mesmo `verify.sh` que você rodaria localmente.

## Reportando uma vulnerabilidade

Escreva para **hello@whynext.app** com os detalhes e uma reprodução. Por favor,
não abra uma issue pública para nada que permita a um repositório escapar dos
limites descritos acima.

Espere uma confirmação dentro de alguns dias. Uma pessoa mantém isto, então
paciência ajuda, e a reprodução também. Um relato que eu não consigo reproduzir é
um que eu não consigo corrigir.

## Versões suportadas

A versão mais recente. Este projeto é pequeno o bastante para que o backporting
não seja um serviço do qual alguém se beneficiaria.
