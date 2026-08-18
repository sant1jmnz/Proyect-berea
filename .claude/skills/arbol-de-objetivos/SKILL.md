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

## Mapeo fino — a qué se convierte exactamente cada nodo

Esta es la tabla de conversión de la cátedra, y es la parte que más se equivoca.
No alcanza con "las causas se vuelven medios": **según el nivel de la causa, el
destino en la Matriz de Marco Lógico es distinto**.

| En el Árbol de Problemas | Se convierte en | Y en la MML termina siendo |
|---|---|---|
| Efectos indirectos | Fines indirectos | Fin |
| Efectos directos | Fines directos | Fin |
| **Problema central** | **Objetivo central / general** | Propósito |
| **Causas directas** | **Objetivos específicos** | Componentes |
| **Causas indirectas** | **Medios** | Actividades |

Por eso importa haber distinguido bien causas directas de indirectas en el árbol
anterior: si una causa quedó al nivel equivocado, termina como actividad algo que
debía ser un componente del sistema, o al revés.

**Fechar el objetivo.** Igual que el problema lleva lugar y año, el objetivo
lleva la meta y el año al que se quiere llegar: si el problema era *"Alta tasa de
analfabetismo en el Cantón X al 2017"*, el objetivo es *"Disminuir la tasa de
analfabetismo a Z en el Cantón X a 2019"*. Ese par —línea de base y meta con
fecha— es exactamente lo que después se copia al indicador de la MML.

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

## Es un método, no un molde

La cátedra lo dice explícitamente: *es un método y debe ser todo lo flexible que
sea necesario*. Si al espejar un nodo el resultado es absurdo o redundante, se
ajusta — pero se deja constancia de por qué, porque romper el espejo sin
explicación es lo que rompe la trazabilidad.

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
