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
[Português](README.pt.md) ·
[Русский](README.ru.md) ·
Español ·
[한국어](README.ko.md)

Tu agente no puede terminar su turno hasta que tu repositorio se demuestre a sí mismo.

Los agentes de código informan de que las pruebas pasan cuando nunca las ejecutaron, y de
que un error está corregido cuando nunca lo reprodujeron. El agente no tiene forma de
comparar lo que hizo con lo que pretendía hacer, así que informa de la intención. Es una
propiedad del diseño, no un defecto de carácter, y ningún prompt lo corrige.

`prove-it` convierte el informe en una comprobación. Pon un `verify.sh` en la raíz de tu
repositorio. Cuando el agente intenta terminar su turno, un hook ejecuta el script, y una
salida distinta de cero devuelve al agente al trabajo en vez de dejarlo parar.

![prove-it bloquea a un agente que afirma haber terminado](../../docs/demo.svg)

La barrera insiste hasta tres veces por turno y luego cede, porque un hook que nunca cede
cuelga la sesión. Ceder no es lo mismo que pasar, así que lo último que ves es una
advertencia de que el turno terminó sin verificar, en vez de la palabra "hecho". Tres es un
número que puedes cambiar, y nada de esto afirma que tu agente no pueda superar la barrera.
Afirma que no puede superarla en silencio.

Úsalo cuando un repositorio tiene un comando local que debe ser cierto antes de que un agente
devuelva el trabajo: pruebas, tipos, lint, comprobaciones de archivos generados, dry runs de
migraciones o una pequeña smoke test que demuestra que el bug desapareció. `prove-it` es más
útil en repositorios donde un agente edita código y dice "hecho" en el mismo hilo.

No lo uses como sandbox, sustituto de CI ni lugar para trabajos largos con red. Si una
comprobación necesita secrets, acceso a producción o más de aproximadamente un minuto, ponla
en CI y deja `verify.sh` para la prueba local que el agente puede ejecutar mientras todavía
está trabajando.

El flujo del primer día es pequeño a propósito. Instala el plugin, ejecuta `/prove-it:init`,
deja el `git diff --check` generado como la única comprobación activa, y activa un comando
real solo después de haberlo visto pasar a mano. Desde entonces, cuando el agente cambia el
repositorio e intenta parar, `verify.sh` decide si puede devolverte el trabajo.

## Instalación

Tres líneas, y la tercera hace el trabajo:

```
/plugin marketplace add Why-Next/prove-it
/plugin install prove-it@whynext
/prove-it:init
```

`/prove-it:init` detecta tu stack, escribe un `verify.sh`, lo ejecuta para que lo veas pasar,
luego ejecuta una copia con `exit 1` añadido para que veas cómo la barrera rechaza un turno.
Tarda alrededor de treinta segundos y nunca sobrescribe un `verify.sh` que ya tengas.

La barrera generada tiene exactamente una comprobación activa, `git diff --check`, con las
comprobaciones para tu stack escritas como comentarios. Pasa el día que la instalas, a
propósito. Una barrera que falla en `main` el día que aterriza enseña a la gente a eludirla en
la primera semana. Activa las comprobaciones comentadas una a una, después de haber visto
pasar cada una a mano.

No se configura nada más, y nada se ejecuta hasta que exista un `verify.sh`. Si abres un
repositorio que no tiene ninguno, el plugin lo dice al inicio de la sesión en vez de quedarse
callado y dejar que supongas que estás cubierto.

## Sin el plugin

Los hooks son bash puro y solo necesitan `bash`, `git` y `python3`:

```bash
git clone https://github.com/Why-Next/prove-it ~/.local/share/prove-it
~/.local/share/prove-it/bin/prove-it init
```

Fusiona [`hooks/settings.example.json`](../../hooks/settings.example.json) en tu
`.claude/settings.json` para un solo repositorio, o `~/.claude/settings.json` para todos.
La barrera lee una carga JSON del Stop hook por stdin y responde con un código de salida,
así que cualquier cosa que pueda ejecutar un script al final del turno puede manejarla.

`prove-it doctor` responde si la barrera se dispararía en el repositorio en el que te
encuentras, y te dice qué la está frenando si no lo haría:

```
repository   /home/you/src/api
verify.sh    present and executable
working tree dirty
blocks       up to 3 per turn, then it yields with a warning
state        /home/you/.local/state/prove-it
ledger       off (export PROVE_IT_LEDGER=1 to record what the gate catches)
```

## Hacer crecer la barrera

Cada comprobación que añades es una frase en tu respuesta a la pregunta de qué significa
"demostrado" en este repositorio. Añade el comando de pruebas que realmente ejecutas, luego el
verificador de tipos, luego lo que tus revisiones sigan detectando. Detente cuando todo el
script tarde alrededor de un minuto; las comprobaciones lentas pertenecen a CI.

Ejecuta cada comprobación a mano antes de activarla. Tampoco publiques nunca una comprobación
que no hayas visto fallar: una comprobación que no puede fallar no es una comprobación, y no lo
descubrirás el día que la necesites.

El error común es escribir un `verify.sh` ambicioso el primer día. Una barrera lenta o
inestable se elude en una semana, y una barrera eludida es peor que ninguna, porque informa
de que una comprobación se ejecutó cuando no lo hizo nada.

## Cómo decide si ejecutarse

La barrera se queda callada salvo que se cumplan todas estas condiciones:

- esta sesión cambió este repositorio
- existe un `verify.sh` ejecutable en la raíz del repositorio
- este estado exacto del árbol no ha pasado ya

"Cambió" lo responde el repositorio, no un registro de qué herramientas se ejecutaron. Al
inicio de una sesión el hook anota cómo se veía el árbol, y en cada parada pregunta si el
árbol sigue viéndose así. Un archivo reescrito por `sed`, un parche aplicado con `git apply`,
un archivo emitido por un generador de código y una confirmación son todos cambios, porque
todos ellos cambian el árbol. Una sesión que solo leyó cuenta como nada, incluso en un
repositorio que ya tenía cambios sin confirmar cuando se abrió.

La última condición significa que un árbol que pasa se verifica una vez, no en cada parada.
Cuando la verificación falla, el agente ve las últimas veinte líneas de salida, lo que suele
bastar para que corrija la causa sin que se le diga qué salió mal.

`PROVE_IT_SKIP=1` salta la barrera a propósito. Borrar `verify.sh` entre sesiones la
desactiva para siempre. Ambas vías de escape son deliberadas: la gente rodea una barrera que
no puede quitar. `PROVE_IT_MAX_BLOCKS` fija cuántas veces se puede devolver un mismo turno, y
`0` hace que la barrera informe sin bloquear nunca.

## Cuando el agente edita la barrera

El modo de fallo más difícil no es una comprobación inestable. Es un agente que no consigue
que `verify.sh` pase y edita `verify.sh` en su lugar.

La versión más barata de eso es desarmar la barrera de plano, así que la barrera lo rechaza.
El hook anota si `verify.sh` era ejecutable cuando la sesión empezó, y una sesión que termina
con él borrado o con su bit de ejecución quitado queda bloqueada, se le dice qué hizo, y se le
dice cómo renunciar con honestidad si eso era lo que pretendía. Borrar `verify.sh` entre
sesiones sigue siendo una renuncia y sigue costando un solo comando.

Lo que queda sin imponer es la versión sutil: un agente que mantiene `verify.sh` ejecutable y
vacía en silencio las comprobaciones que hay dentro. El mensaje de fallo le dice que no lo
haga, y [SPEC.md](../../SPEC.md) lo llama una violación en vez de una corrección, pero
ninguna de esas dos cosas es una imposición. Lee tus diffs. Para eso está la evidencia del
diff en la especificación.

## La convención de `verify.sh`

El script en `hooks/` es pequeño a propósito. Lo que implementa está escrito en
[SPEC.md](../../SPEC.md): un repositorio declara cómo se demuestra a sí mismo, en una ruta
conocida, con un contrato conocido, y un agente no puede reclamar la finalización hasta que
esa prueba pase. La especificación nombra un archivo y un código de salida, y nunca nombra a
un proveedor, así que el plugin es una forma de distribuir la idea, no la idea en sí.

Lee la especificación para conocer los cuatro tipos de evidencia contra los que un
`verify.sh` debería contrastar, que son salida de comandos, diff, reproducción y
comprobación cruzada, y para los niveles de conformidad.

## Lo que esto no hace

La barrera impone una sola cosa: que `verify.sh` devolvió cero antes de que el turno
terminara. Si ese cero significa algo depende por completo de las comprobaciones que
escribiste. Un `verify.sh` que contenga solo `exit 0` pasa esta barrera y no demuestra nada.

La especificación llama a eso Level 1. Level 2 es si tus comprobaciones contrastan contra
evidencia real, y ninguna herramienta puede verificar eso por ti, esta incluida.

Tres límites más, dichos con claridad porque de otro modo los encontrarás en un mal momento.
La barrera cede tras `PROVE_IT_MAX_BLOCKS` rechazos, así que un agente decidido llega al final
de su turno; lo que no puede hacer es llegar allí en silencio. Los archivos que tu `.gitignore`
excluye son invisibles para la detección de cambios, así que un `verify.sh` que lee un `.env`
ignorado puede omitirse cuando solo ese archivo cambió. Y una sesión que empieza fuera del
repositorio que después edita no tiene línea base contra la cual comparar, lo que hace que la
barrera retroceda a la prueba más débil de si el árbol de trabajo tiene cambios.

## Recetas

Los puntos de partida por stack están en [`recipes/`](../../recipes/). Copia uno a
`verify.sh` y quita lo que no aplique. Mantenlo por debajo de un minuto; las comprobaciones
lentas pertenecen a CI.

| | |
|---|---|
| [`node.sh`](../../recipes/node.sh) | tests, typecheck, lint, higiene del diff |
| [`python.sh`](../../recipes/python.sh) | pytest, ruff, mypy |
| [`go.sh`](../../recipes/go.sh) | go test, vet, gofmt check |
| [`flutter.sh`](../../recipes/flutter.sh) | analyze, test, format check |

Conectar el hook es la parte fácil. El trabajo es responder qué significa "demostrado" en tu
repositorio, y ninguna receta lo responde por ti.

## El registro

Establece `PROVE_IT_LEDGER=1` y cada finalización falsa detectada añade una línea a
`~/.prove-it/ledger.jsonl`:

```json
{"ts":"2026-07-09T04:12:33Z","claim":"All tests pass. Ready to merge.",
 "evidence_demanded":"verify.sh exit 0","actual":["3 failed, 41 passed"]}
```

La línea registra lo que el agente afirmó, lo que se le exigió y lo que resultó ser verdad.
El archivo se escribe en disco local con modo `0600`, nada lo transmite a ninguna parte, y
permanece apagado hasta que lo enciendes. Tras un mes de entradas puedes dejar de adivinar
cómo falla tu agente y leerlo en su lugar. `/prove-it:ledger` te resume el archivo, igual que
`prove-it ledger` en la línea de comandos.

## Este repo se pone la barrera a sí mismo

`prove-it` tiene un `verify.sh`, y parte de lo que ejecuta es la propia barrera, contra
repositorios git reales en un directorio temporal: una comprobación que falla bloquea, una
que pasa permite, una sesión de solo lectura queda intacta, un árbol limpio después de un
commit no se confunde con ausencia de trabajo, el bypass funciona.

```bash
./verify.sh
```

CI ejecuta ese mismo script en Linux y macOS, más un trabajo separado que demuestra que la
barrera sigue bloqueando un repositorio cuyas comprobaciones fallan. El repositorio también
ejecuta CodeQL, OpenSSF Scorecard y un workflow de release por etiqueta que empaqueta el
código fuente con checksum y attestation de procedencia de GitHub.

## Confianza del proyecto

Lee [SECURITY.md](../../SECURITY.md) antes de usar esto en repositorios en los que no
confías. `prove-it` ejecuta el `verify.sh` propiedad del repositorio; es una barrera de
seguridad, no una sandbox.

Los pasos de release están en [RELEASE.md](../../RELEASE.md), incluida la lista para
verificación, estado de workflows, checksums y attestation de procedencia. Los límites de
soporte están en [SUPPORT.md](../../SUPPORT.md).

## Contribuir

Los issues y pull requests son bienvenidos. Los cambios a la convención pertenecen a un issue
en vez de a un pull request contra la implementación de referencia. Consulta
[CONTRIBUTING.md](../../CONTRIBUTING.md).

## Licencia

MIT.
