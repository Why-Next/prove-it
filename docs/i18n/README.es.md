# prove-it

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

**Tu agente no puede terminar su turno hasta que tu repo se demuestre a sí mismo.**

Los agentes de código dicen "las pruebas pasan" sin haberlas ejecutado, y "arreglado"
sin haber reproducido nunca el error. No por malicia: un agente no puede distinguir lo
que hizo de lo que pretendía hacer, así que reporta la intención.

`prove-it` convierte *hecho* en algo que un agente tiene que aprobar, no algo que puede
simplemente afirmar. Pon un `verify.sh` en la raíz de tu repo. Cuando el agente intenta
detenerse, la barrera lo ejecuta. Salida distinta de cero, y el turno no termina.

```
agent: "All tests pass. Ready to merge."
       └─ tries to end turn
          └─ prove-it runs ./verify.sh
             └─ exit 1:  FAIL src/auth.test.ts  (3 failed, 41 passed)
                └─ turn blocked, agent keeps working

agent: "Actually, three tests were failing. Fixing."
```

Aproximadamente la mitad de las veces, un agente al que se le pide evidencia responde
"tienes razón, todavía no está hecho".

## Instalación

Requiere `bash`, `git`, `python3`. Sin paquetes, sin demonio, nada a lo que registrarse.
Clónalo en cualquier lugar:

```bash
git clone https://github.com/YOUR_ORG/prove-it ~/.local/share/prove-it
```

Conecta los dos hooks a Claude Code fusionando
[`hooks/settings.example.json`](../../hooks/settings.example.json) en tu
`.claude/settings.json` (por repo) o `~/.claude/settings.json` (en todas partes).

Luego escribe el único archivo que importa:

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

Esa es toda la configuración. Todavía no hay ningún `verify.sh` en tu repo, así que hasta
que escribas uno, la barrera no hace absolutamente nada.

## Tus primeros cinco minutos

Empieza más pequeño de lo que crees. Un `verify.sh` que solo ejecuta `git diff --check`
ya vale la pena tenerlo, y pasará, lo que te enseña que la barrera se queda callada
cuando todo está bien.

```bash
printf '#!/bin/bash\nset -eu\ncd "$(dirname "$0")"\ngit diff --check\n' > verify.sh
chmod +x verify.sh
./verify.sh                 # run it yourself first. Never ship a check you have not seen pass.
```

Ahora míralo fallar a propósito, para que sepas que la barrera es real:

```bash
sed -i.bak 's|git diff --check|git diff --check\nexit 1|' verify.sh && rm verify.sh.bak
```

Pídele a tu agente que edite cualquier archivo, y luego déjalo terminar. Intentará terminar
su turno, la barrera ejecutará `verify.sh`, y el turno quedará bloqueado. Deshaz el
`exit 1` y el mismo agente pasa sin problemas.

A partir de ahí, añade una comprobación real a la vez: el comando de pruebas que realmente
ejecutas, luego el verificador de tipos, luego la higiene del diff. Cada comprobación que
añades es una frase en tu respuesta a *qué significa demostrado aquí*. Detente cuando todo
el conjunto tarde alrededor de un minuto.

El error a evitar es escribir un `verify.sh` ambicioso el primer día. Una barrera lenta o
inestable se elude en una semana, y una barrera eludida es peor que ninguna: te dice que
una comprobación ocurrió cuando no fue así.

## Cómo decide si ejecutarse

La barrera se queda callada por defecto. Ejecuta `verify.sh` solo cuando se cumple cada
una de estas condiciones:

- la sesión realmente editó archivos (una sesión de solo lectura no tiene nada que demostrar)
- existe un `verify.sh` ejecutable en la raíz del repo
- el árbol de trabajo tiene cambios sin confirmar
- este estado exacto del árbol no ha pasado ya

Esa última significa que un árbol que pasa se verifica una vez, no en cada parada. Los fallos
imprimen las últimas 20 líneas de salida al agente, lo que suele ser suficiente para que
arregle la causa sin que se le diga.

Para saltarte la barrera a propósito: `PROVE_IT_SKIP=1`. Para desactivarla para siempre:
borra `verify.sh`. Ambas son deliberadas. Una barrera que nadie puede quitar es una barrera
que la gente rodea.

## Optar por salir es la característica

El modo de fallo más difícil no es una comprobación inestable. Es un agente que no puede
pasar `verify.sh` y en su lugar edita `verify.sh` sin decir nada. El mensaje de fallo de la
barrera lo dice con todas las letras, y la especificación lo convierte en una violación
declarada. Aun así, vigílalo en tus diffs. Para eso está la evidencia del diff.

## La convención de `verify.sh`

El script en `hooks/` es pequeño a propósito. El verdadero artefacto es la convención que
implementa, escrita en **[SPEC.md](../../SPEC.md)**: un repositorio declara cómo se demuestra
a sí mismo, en un lugar conocido, con un contrato conocido, y un agente no puede reclamar la
finalización hasta que esa prueba pase.

Lee la especificación para conocer los cuatro tipos de evidencia que un `verify.sh` debería
verificar - salida de comandos, diff, reproducción, comprobación cruzada - y para los niveles
de conformidad.

**Una nota honesta de entrada.** Esta herramienta hace cumplir exactamente una cosa: que
`verify.sh` devolvió cero antes de que el turno terminara. Si ese cero *significa* algo depende
enteramente de las comprobaciones que escribiste. Un `verify.sh` que contenga solo `exit 0`
pasará esta barrera y no demostrará nada. La herramienta es Level 1. La evidencia es Level 2,
y Level 2 es una práctica, no una característica.

## Recetas

Puntos de partida por stack, en [`recipes/`](../../recipes/). Copia uno a `verify.sh` y quita
lo que no aplique. Mantenlo por debajo de un minuto; las comprobaciones lentas pertenecen a CI.

| | |
|---|---|
| [`node.sh`](../../recipes/node.sh) | tests, typecheck, lint, higiene del diff |
| [`python.sh`](../../recipes/python.sh) | pytest, ruff, mypy |
| [`go.sh`](../../recipes/go.sh) | go test, vet, gofmt check |
| [`flutter.sh`](../../recipes/flutter.sh) | analyze, test, format check |

La parte difícil de adoptar esto nunca es conectar el hook. Es responder "qué significa
*demostrado* en este repo" por primera vez.

## El registro

Establece `PROVE_IT_LEDGER=1` y cada finalización falsa detectada añade una línea a
`~/.prove-it/ledger.jsonl`:

```json
{"ts":"2026-07-09T04:12:33Z","claim":"All tests pass. Ready to merge.",
 "evidence_demanded":"verify.sh exit 0","actual":["3 failed, 41 passed"]}
```

Qué se afirmó, qué se exigió, qué era verdad. Solo disco local, nunca transmitido, apagado a
menos que lo enciendas. Después de un mes dejas de adivinar cómo falla tu agente y empiezas a
leerlo.

## Este repo se pone la barrera a sí mismo

`prove-it` tiene un `verify.sh`, y ejecuta la barrera contra repos git reales en un directorio
temporal: comprobación que falla bloquea, comprobación que pasa permite, la sesión de solo
lectura queda intacta, el árbol limpio se omite, el bypass funciona.

```bash
./verify.sh
```

Sería raro publicarlo de otra manera.

## Licencia

MIT.
