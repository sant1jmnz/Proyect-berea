---
name: arbol-de-objetivos
description: Transformar el Árbol de Problemas en Árbol de Objetivos (medios y fines) y elegir la alternativa de intervención. Usar al pasar del diagnóstico a la propuesta de solución, al redactar objetivo general y objetivos específicos.
---

# Árbol de Objetivos

Es el Árbol de Problemas dado vuelta: cada estado negativo se convierte en el
estado positivo que se quiere alcanzar. No se inventan nodos nuevos.

```
Efectos   → Fines            (copa)
Problema  → Objetivo general (tronco)
Causas    → Medios           (raíces)
```

## Procedimiento

1. **Espejar nodo por nodo.** Recorrer el Árbol de Problemas y reescribir cada
   elemento en positivo, en **infinitivo**. Mantener la numeración en paralelo:
   la causa `C2` se convierte en el medio `M2`.
2. **Objetivo general** = problema central resuelto. Uno solo, concreto,
   alcanzable y medible en el tiempo del proyecto.
3. **Objetivos específicos** = los medios de primer nivel. Son los cambios
   necesarios sin los cuales el objetivo general no se alcanza. Numerar
   `OE1, OE2…`.
4. **Verificar la lógica medios-fines**: "si logro este medio, contribuyo a este
   objetivo, que produce este fin".
5. **Seleccionar la alternativa de intervención.** No todos los medios se
   atacan con software. Elegir el conjunto de medios que va a cubrir el sistema
   y justificar por qué: viabilidad técnica en el tiempo disponible, impacto
   sobre el problema central, recursos del equipo.

## Reglas de redacción

- Infinitivo siempre: "Reducir", "Automatizar", "Centralizar" — no "Reducción"
  ni "Se reducirá".
- Un objetivo, una acción. Si aparece un "y", probablemente son dos objetivos.
- Concreto y verificable: "Reducir a menos de 5 minutos la carga de asistencia",
  no "Mejorar la gestión".
- Nada de nodos huérfanos: cada objetivo tiene que apuntar a una causa del árbol
  anterior. Si no la tiene, sobra — o falta esa causa en el diagnóstico.

## Formato de salida

`docs/02-arbol-de-objetivos.md`: el diagrama Mermaid espejado, el objetivo
general destacado, la tabla de objetivos específicos con la causa que atiende
cada uno, y la sección de alternativa elegida con su justificación y el alcance
excluido.
