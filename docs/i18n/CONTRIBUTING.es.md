# Contribuir

## Dónde encaja un cambio

Este repositorio contiene dos cosas de distinto peso.

[SPEC.md](../../SPEC.md) describe una convención que otras herramientas deberían poder
implementar sin leer una sola línea de este código. Los cambios en ella empiezan como un
issue, para que la discusión ocurra antes de que alguien escriba un parche. Un pull request
que ensancha el contrato sin decir nada es más difícil de rebatir que una propuesta que dice
con claridad qué quiere cambiar.

`hooks/prove-it.sh` es una implementación de esa convención, unas setenta y pico líneas, y los
pull requests contra él no necesitan ceremonia.

Si no estás seguro de cuál de las dos estás tocando, abre un issue y pregunta.

## La barrera también se te aplica a ti

Este repositorio tiene un `verify.sh`. Ejecútalo antes de abrir un pull request:

```bash
./verify.sh
```

Comprueba la sintaxis del shell, ejecuta shellcheck, valida los manifiestos del plugin, impone
las reglas de prosa de abajo, mantiene las traducciones fieles a los originales en inglés, y
ejecuta el propio conjunto de pruebas de la barrera contra repositorios git reales en un
directorio temporal. CI ejecuta el mismo script en Linux y macOS, más un trabajo separado que
demuestra que la barrera sigue bloqueando un repositorio cuyas comprobaciones fallan.

Si `verify.sh` falla, corrige la causa. No debilites `verify.sh`. Ese es el único cambio que
este proyecto no fusionará, por la razón por la que el proyecto existe.

## Añadir una comprobación

Una nueva comprobación es bienvenida cuando habría detectado un error real. Rompe algo a
propósito, observa cómo tu comprobación lo detecta, luego corrígelo y confirma ambos. Una
comprobación que nadie ha visto fallar no es una comprobación.

Dos de los scripts en `scripts/` existen porque sus primeras versiones pasaron contra una base
de código que ya estaba rota.

## Traducciones

`README.md` y `SPEC.md` son canónicos, y el texto en inglés de `SPEC.md` prevalece donde una
traducción no coincide con él. `scripts/check_i18n.py` mantiene cada traducción fiel a su
original: el número de encabezados, si los encabezados se tradujeron o no, si los acentos
sobrevivieron, si los bloques de código son idénticos byte a byte al inglés, y si los enlaces
relativos resuelven.

Dos reglas hacen tropezar a la gente.

Nunca uses un guion largo. Ni raya, ni semirraya, ni barra horizontal, ni signo menos. Solo el
guion ASCII simple, en todos los idiomas, incluidos aquellos cuya tipografía prefiere lo
contrario, porque un guion largo se lee como texto escrito por una máquina. (Este párrafo
nombra los caracteres en vez de mostrarlos, ya que `scripts/check_no_long_dash.py` también lee
este archivo.)

Conserva siempre los acentos. La regla del guion cubre seis caracteres concretos y no es una
prohibición de lo que no sea ASCII. `décidé` sigue siendo `décidé`, y `è` nunca se convierte
en `e'`. Una traducción temprana eliminó todos los acentos del archivo por aplicar en exceso
la primera regla.

## Recetas

Una receta es un punto de partida para un stack, no un `verify.sh` terminado. Mantenla por
debajo de un minuto de ejecución, prefiere comprobaciones que producen evidencia frente a las
que producen opiniones, y anota cuál de los cuatro tipos de evidencia de la especificación
entrega cada comprobación.

## Commits

Commits convencionales (`feat:`, `fix:`, `docs:`, `chore:`). Di en el cuerpo qué cambió y por
qué. Si corregiste un error, di cómo lo reprodujiste.
