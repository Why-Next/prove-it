# La convención de `verify.sh`

> El texto en inglés de [SPEC.md](../../SPEC.md) es la versión normativa. Existen
> traducciones al
> [中文](SPEC.zh.md) ·
> [Deutsch](SPEC.de.md) ·
> [日本語](SPEC.ja.md) ·
> [हिन्दी](SPEC.hi.md) ·
> [Français](SPEC.fr.md) ·
> [Italiano](SPEC.it.md) ·
> [Português](SPEC.pt.md) ·
> [Русский](SPEC.ru.md) ·
> Español ·
> [한국어](SPEC.ko.md).
> Son informativas. Donde una traducción y el texto en inglés no coincidan,
> prevalece el inglés y la traducción es un error que debe reportarse.

Versión 0.1 (borrador). Un repositorio declara cómo se demuestra a sí mismo, y un agente no
puede reclamar la finalización hasta que esa prueba pase.

Este documento es el contrato. El script en `hooks/` es una implementación de él, y
deliberadamente pequeña. Lee la sección 5 sobre los niveles de conformidad antes de suponer
que la herramienta impone todo lo escrito aquí.

## 1. El problema

Los agentes de código terminan turnos con frases como estas:

- "Las pruebas pasan." Las pruebas nunca se ejecutaron.
- "Corregí el error." El error nunca se reprodujo.
- "La migración es segura." No se aplicó nada a una base de datos de prueba.

No son mentiras en el sentido habitual. Un agente no puede distinguir lo que hizo de lo que
pretendía hacer, así que su informe describe la intención. El fallo es estructural, y el
prompting no lo eliminará. La técnica de prompts además caduca con cada generación de
modelos, mientras que una exigencia de evidencia se sitúa una capa por encima del modelo y
sobrevive a la actualización.

Así, "hecho" deja de ser algo que un agente declara y pasa a ser una comprobación que tiene
que aprobar.

## 2. La convención

Un repositorio conforme tiene un archivo ejecutable `verify.sh` en su raíz.

```
your-repo/
  verify.sh      <- executable, exit 0 means "this tree is provably fine"
```

El contrato:

| | |
|---|---|
| Ubicación | raíz del repositorio |
| Modo | ejecutable (`chmod +x`) |
| Invocación | ejecutado con el CWD en la raíz del repositorio, sin argumentos |
| Código de salida `0` | verificación superada |
| Código de salida distinto de `0` | verificación fallida; stdout y stderr explican por qué |
| Salida | legible para humanos; las últimas 20 líneas son lo que ve un agente |
| Tiempo de ejecución | menos de un minuto; las comprobaciones lentas pertenecen a CI |
| Ausente | sin barrera. La ausencia es un estado válido, no un fallo |

`verify.sh` responde a una pregunta: ¿qué tendría que ser cierto para que un cambio aquí
fuera demostrablemente seguro de devolver? Cada repositorio la responde de forma distinta, y
por eso esta convención nombra el archivo y no su contenido.

Renunciar requiere una sola acción: borrar `verify.sh`, o reducirlo a `exit 0`. Es
intencional. La gente rodea una barrera que no puede quitar, y una barrera que se rodea sigue
informando de éxito.

## 3. Los cuatro tipos de evidencia

Un `verify.sh` debería contrastar contra evidencia y no contra creencias. Cuatro tipos tienen
peso. Un `verify.sh` útil cubre al menos uno, y uno maduro cubre los cuatro a lo largo de las
comprobaciones que ejecuta.

**Salida de comandos.** Un comando se ejecutó y la comprobación leyó su código de salida. No
"las pruebas deberían pasar" sino el veredicto del propio ejecutor de pruebas.

**Diff.** El cambio es lo que se pretendía y nada más: sin sentencias de depuración, sin
archivos sueltos, sin cambios de formato ajenos. `git diff --check` es el mínimo.

**Reproducción.** Para la corrección de un error, el fallo se observó antes del cambio y está
ausente después. Una corrección que nunca se reprodujo es una conjetura sobre qué línea
estaba mal.

**Comprobación cruzada.** Una segunda fuente independiente coincide. Otro modelo, otra
herramienta, un verificador de tipos frente a un conjunto de pruebas. La independencia es lo
que le da valor; dos comprobaciones que comparten una suposición confirman la suposición y no
el código.

Las cuatro categorías existen para que "lo verifiqué" tenga que nombrar un método. Un agente
que no puede decir cuál de los cuatro tipos de evidencia tiene no tiene ninguno.

## 4. Lo que las implementaciones deben hacer

Una implementación de esta convención es una barrera. Para ser conforme debe:

1. Ejecutar `verify.sh` desde la raíz del repositorio antes de que el turno del agente pueda
   terminar.
2. Bloquear el turno ante una salida distinta de cero, y mostrar la salida.
3. No hacer nada cuando `verify.sh` está ausente o no es ejecutable.
4. No hacer nada cuando la sesión no hizo ediciones en ese repositorio.
5. Ofrecer un bypass explícito y localizable con grep. Un bypass silencioso enseña a la gente
   a desconfiar de la barrera; uno auditado la mantiene honesta.

No debe modificar `verify.sh`, y debe decirle al agente que debilitar `verify.sh` para
saltarse la barrera es una violación en vez de una corrección. Este es el modo de fallo más
probable en la práctica. Un agente que no puede pasar una comprobación, si tiene la
oportunidad, editará la comprobación.

## 5. Niveles de conformidad

Sé preciso sobre lo que impone una máquina y lo que practica una persona. Esa distinción
importa más que la ambición detrás de la convención.

**Level 1, la barrera.** `verify.sh` existe, y algo se niega mecánicamente a dejar que un
turno termine mientras falla. La implementación de referencia en `hooks/` impone esto por
completo, y es donde todo repositorio debería empezar.

**Level 2, la evidencia.** Las comprobaciones dentro de `verify.sh` cubren los cuatro tipos
de evidencia de la sección 3. Ninguna herramienta impone esto, esta incluida. La barrera
verifica que tu `verify.sh` devolvió cero. Si ese cero significa algo es una afirmación sobre
las comprobaciones que escribiste, y un `verify.sh` que contenga solo `exit 0` alcanza Level 1
sin demostrar nada.

**Level 3, el registro.** Cada finalización falsa detectada queda registrada, para que los
modos de fallo se vuelvan datos y no anécdota. La implementación de referencia escribe esto
solo cuando se habilita explícitamente.

Level 1 es una propiedad de una herramienta. Level 2 es una propiedad de los hábitos de un
equipo, y cualquier herramienta que afirme entregarlo está entregando Level 1 y esperando que
nadie lea el código fuente.

## 6. El formato del registro

Cuando está habilitado, cada finalización falsa detectada añade un objeto JSON por línea:

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

`claim` contiene el propio último mensaje del agente antes de intentar detenerse. Es el campo
más útil del registro y el más sensible, ya que puede contener cualquier texto de la
conversación. Una implementación debe escribir el registro en disco local con permisos
restrictivos y nunca debe transmitirlo.

Una fila contiene tres cosas: qué se afirmó, qué se exigió y qué era verdad.

## 7. No objetivos

Esta convención no te dice qué comprobar, no ejecuta tu CI, no puntúa tu código y no reemplaza
la revisión. Responde a una sola pregunta, que es si este repositorio se demostró a sí mismo
antes de que el agente se marchara.

---

*Las propuestas para cambiar este documento pertenecen a un issue en vez de a un pull request
contra la implementación de referencia. Cada adición aquí es algo que toda implementación
futura tiene que soportar.*
