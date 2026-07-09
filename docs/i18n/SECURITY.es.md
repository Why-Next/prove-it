# Seguridad

## Qué hace este software en tu máquina

`prove-it` ejecuta un script que vive en el repositorio que tienes abierto. Si abres un
repositorio en el que no confías, y su `verify.sh` es ejecutable, tu agente al terminar un
turno ejecutará ese archivo.

Ese comportamiento es el diseño y no un defecto en él, y el riesgo es el que ya aceptas cuando
ejecutas `npm install` o abres un proyecto con un `Makefile`. Lee un `verify.sh` desconocido
antes de dejar que un agente trabaje en el repositorio que lo contiene, igual que leerías un
script `postinstall` desconocido.

La barrera solo se ejecuta cuando la sesión cambió **ese mismo repositorio** y existe un
`verify.sh` ejecutable en su raíz. Clonar y leer un repositorio nunca la activa, y cambiar un
repositorio nunca hace que se ejecute el `verify.sh` de otro repositorio.

`prove-it doctor` es la excepción, y es deliberada: le pediste que ejecutara la barrera, así
que ejecuta `verify.sh` de inmediato, en el repositorio en el que estés. No lo ejecutes dentro
de un repositorio cuyo `verify.sh` no hayas leído.

Nada de esto es un sandbox. Los hooks y su contabilidad se ejecutan como tú, y el shell
del agente también, así que un agente empeñado en derrotar la barrera podría borrar el
directorio de estado y luego desarmar `verify.sh`. `prove-it` es una barrera de protección
contra un agente que se equivoca con confianza, que es el que tienes. No es una frontera
contra uno hostil. Una comprobación que un agente hostil no puede alcanzar tiene que
ejecutarse en algún lugar que no pueda alcanzar, y ese lugar es la CI.

## Qué escribe en el disco

Pequeños archivos de contabilidad, todos en un directorio privado creado con modo `0700`:
`$XDG_STATE_HOME/prove-it/`, o `~/.local/state/prove-it/` cuando eso no está definido. Anúlalo
con `PROVE_IT_STATE_DIR`. Registran cómo se veía el árbol cuando empezó una sesión, si la
barrera estaba armada en ese momento, en qué repositorios ha escrito una sesión, qué estados
del árbol ya han pasado, y cuántas veces se ha devuelto el turno actual. Cada uno contiene una
suma de comprobación o un entero pequeño, nunca contenido de archivos. No se escribe nada en el
`/tmp` compartido, porque estos nombres de archivo se derivan de la ruta del repositorio y por
tanto son predecibles, y un nombre predecible en un directorio con escritura para todos es un
objetivo de enlace simbólico.

El identificador de sesión llega en la carga JSON del hook y acaba dentro de uno de esos
nombres de archivo, así que se reduce a letras, dígitos, guion y guion bajo antes de usarse.
Una carga no es una fuente confiable de componentes de ruta.

El registro opcional (`PROVE_IT_LEDGER=1`, **desactivado por defecto**) añade una línea JSON
por cada finalización falsa detectada a `~/.prove-it/ledger.jsonl`, creado con modo `0600`
dentro de un directorio `0700`. Cada línea contiene:

- el último mensaje del agente antes de intentar detenerse, truncado a 300 caracteres y tomado
  de tu transcripción local, así que puede contener cualquier cosa que estuviera en tu
  conversación
- la ruta absoluta del repositorio
- el código de salida, y las líneas de la salida de tu `verify.sh` que nombran un fallo
- una marca de tiempo

Trátalo como datos de conversación. Nada en este proyecto lo vuelve a leer ni lo envía a
ninguna parte, pero sigue siendo un archivo corriente, así que tus copias de seguridad lo
copiarán y cualquiera con acceso de lectura a tu directorio personal puede abrirlo.

## Qué envía

Nada. El software que se ejecuta en tu máquina no contiene telemetría, ni llamadas de red, ni
comprobación de actualizaciones. Puedes confirmarlo con un solo grep de `curl`, `wget`,
`urllib`, `requests` o `socket` en `hooks/` y `scripts/`.

La integración continua es la única excepción, y no es código que tú ejecutas: el flujo de
trabajo de GitHub Actions instala `shellcheck` desde `apt` o `brew` antes de ejecutar el mismo
`verify.sh` que ejecutarías localmente.

## Reportar una vulnerabilidad

Escribe a **hello@whynext.app** con los detalles y una reproducción. Por favor, no abras un
issue público para nada que permita a un repositorio escapar de los límites descritos arriba.

Espera un acuse de recibo en unos pocos días. Una sola persona mantiene esto, así que la
paciencia ayuda, y también la reproducción. Un informe que no puedo reproducir es uno que no
puedo corregir.

## Versiones soportadas

La última publicación. Este proyecto es lo bastante pequeño como para que el backporting no sea
un servicio del que nadie se beneficiaría.
