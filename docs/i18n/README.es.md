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
Español ·
[한국어](README.ko.md)

Tu agente no puede terminar su turno hasta que tu repositorio se demuestre a sí mismo.

Los agentes de código informan de que las pruebas pasan cuando nunca las ejecutaron, y de
que un error está corregido cuando nunca lo reprodujeron. El agente no tiene forma de
comparar lo que hizo con lo que pretendía hacer, así que informa de la intención. Es una
propiedad del diseño, no un defecto de carácter, y ningún prompt lo corrige.

`prove-it` convierte el informe en una comprobación. Pon un `verify.sh` en la raíz de tu
repositorio. Cuando el agente intenta terminar su turno, un hook ejecuta el script, y una
salida distinta de cero mantiene el turno abierto hasta que se corrige la causa.

![prove-it bloquea a un agente que afirma haber terminado](../../docs/demo.svg)

En mi propio uso, algo menos de la mitad de los turnos que topan con una barrera que falla
vuelven con el agente admitiendo que no había terminado. Esos turnos, de otro modo, habrían
acabado con la palabra "hecho".

## Instalación

Como plugin de Claude Code:

```
/plugin marketplace add WhyNext/prove-it
/plugin install prove-it@whynext
```

El plugin registra dos hooks, uno para marcar que una sesión editó archivos y otro para
poner la barrera al turno, y añade dos comandos: `/prove-it:init` escribe tu primer
`verify.sh`, y `/prove-it:ledger` te muestra lo que la barrera ha detectado.

Para cualquier otro agente, clona el repositorio y conecta los mismos dos hooks. Son bash
puro y solo necesitan `bash`, `git` y `python3`:

```bash
git clone https://github.com/WhyNext/prove-it ~/.local/share/prove-it
```

Fusiona [`hooks/settings.example.json`](../../hooks/settings.example.json) en tu
`.claude/settings.json` para un solo repositorio, o `~/.claude/settings.json` para todos.
La barrera lee una carga JSON del Stop hook por stdin y responde con un código de salida,
así que cualquier cosa que pueda ejecutar un script al final del turno puede manejarla.

Luego escribe el archivo que importa:

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

Hasta que ese archivo exista, la barrera no hace absolutamente nada.

## Tus primeros cinco minutos

Empieza más pequeño de lo que querrías. Un `verify.sh` que solo ejecuta `git diff --check`
ya vale la pena, y pasa, lo que te muestra que la barrera se queda callada cuando el
repositorio está en buen estado.

```bash
printf '#!/bin/bash\nset -eu\ncd "$(dirname "$0")"\ngit diff --check\n' > verify.sh
chmod +x verify.sh
./verify.sh                 # run it yourself first
```

Ahora haz que falle a propósito:

```bash
sed -i.bak 's|git diff --check|git diff --check\nexit 1|' verify.sh && rm verify.sh.bak
```

Pídele al agente que edite cualquier archivo y déjalo terminar. Intentará terminar el turno,
la barrera ejecutará `verify.sh`, y el turno se quedará abierto. Quita el `exit 1` y el mismo
agente pasa sin problemas. Nunca publiques una comprobación que no hayas visto fallar.

A partir de ahí, añade una comprobación real cada vez: el comando de pruebas que realmente
ejecutas, luego el verificador de tipos, luego la higiene del diff. Cada comprobación que
añades es una frase en tu respuesta a la pregunta de qué significa "demostrado" en este
repositorio. Detente cuando todo el script tarde alrededor de un minuto.

El error común es escribir un `verify.sh` ambicioso el primer día. Una barrera lenta o
inestable se elude en una semana, y una barrera eludida es peor que ninguna, porque informa
de que una comprobación se ejecutó cuando no lo hizo nada.

## Cómo decide si ejecutarse

La barrera se queda callada salvo que se cumplan todas estas condiciones:

- esta sesión editó archivos en este repositorio
- existe un `verify.sh` ejecutable en la raíz del repositorio
- el árbol de trabajo tiene cambios sin confirmar
- este estado exacto del árbol no ha pasado ya

La última condición significa que un árbol que pasa se verifica una vez, no en cada parada.
Cuando la verificación falla, el agente ve las últimas veinte líneas de salida, lo que suele
bastar para que corrija la causa sin que se le diga qué salió mal.

`PROVE_IT_SKIP=1` salta la barrera a propósito. Borrar `verify.sh` la desactiva para
siempre. Ambas vías de escape son deliberadas: la gente rodea una barrera que no puede quitar.

## Cuando el agente edita la barrera

El modo de fallo más difícil no es una comprobación inestable. Es un agente que no consigue
que `verify.sh` pase y edita `verify.sh` en su lugar. El mensaje de fallo le dice que no lo
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
cómo falla tu agente y leerlo en su lugar. `/prove-it:ledger` te resume el archivo.

## Este repo se pone la barrera a sí mismo

`prove-it` tiene un `verify.sh`, y parte de lo que ejecuta es la propia barrera, contra
repositorios git reales en un directorio temporal: una comprobación que falla bloquea, una
que pasa permite, una sesión de solo lectura queda intacta, un árbol limpio se omite, el
bypass funciona.

```bash
./verify.sh
```

CI ejecuta ese mismo script en Linux y macOS, más un trabajo separado que demuestra que la
barrera sigue bloqueando un repositorio cuyas comprobaciones fallan.

## Contribuir

Los issues y pull requests son bienvenidos. Los cambios a la convención pertenecen a un issue
en vez de a un pull request contra la implementación de referencia. Consulta
[CONTRIBUTING.md](../../CONTRIBUTING.md).

## Licencia

MIT.
