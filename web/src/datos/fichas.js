/* Información de cada protocolo que la base no guarda: en qué capa de la piel
 * actúa, qué objeto lo representa en la vitrina, cuántas sesiones suele llevar y
 * qué hacer antes y después. Está agrupada por familia de tratamiento. Es
 * información general: la profesional confirma todo en la consulta.
 * Se relaciona con el catálogo por el id de la base (idBase). */

/* Familias: lo que comparten varios protocolos. */
const familias = {
  limpieza: {
    preparacion: 'Venir sin maquillaje. Evitar ácidos y exfoliantes en los 3 días anteriores.',
    despues: 'Protector solar todos los días y no exponerse al sol directo por 48 horas. Puede haber un poco de enrojecimiento ese día.',
    noApto: 'Piel con herpes activo, quemaduras de sol o heridas abiertas.',
  },
  peeling: {
    preparacion: 'Suspender retinoides y exfoliantes 5 días antes. Contale a la profesional si usás algún medicamento.',
    despues: 'Piel sensible y con descamación leve por unos días: hidratar, no arrancar las pieles y usar protector solar factor 50.',
    noApto: 'Embarazo, lactancia, piel irritada o bronceado reciente.',
  },
  masaje: {
    preparacion: 'Ropa cómoda. Evitar comer pesado en la hora anterior.',
    despues: 'Tomar agua y descansar. Puede quedar sensibilidad en la zona trabajada por un día.',
    noApto: 'Várices severas en la zona, trombosis, fiebre o lesiones en la piel.',
  },
  laser: {
    preparacion: 'Rasurar la zona con máquina 24 horas antes. No usar cera ni pinza por 4 semanas, y venir sin bronceado.',
    despues: 'Evitar sol, sauna y gimnasio 48 horas. Hidratar con crema calmante. El vello cae solo en los días siguientes.',
    noApto: 'Embarazo, bronceado reciente, medicación fotosensibilizante o piel con lesiones en la zona.',
  },
  aparatos: {
    preparacion: 'Venir hidratada y sin cremas en la zona. Retirar joyas y piercings cercanos.',
    despues: 'Tomar agua y retomar la rutina normal. Puede haber calor o enrojecimiento leve por unas horas.',
    noApto: 'Embarazo, marcapasos, implantes metálicos en la zona o infecciones activas.',
  },
  inyectable: {
    preparacion: 'No tomar aspirina, antiinflamatorios ni alcohol 48 horas antes, para reducir los hematomas.',
    despues: 'No masajear la zona, no acostarte ni hacer ejercicio intenso por 4 horas. Pueden aparecer pequeños puntos rojos o un hematoma leve.',
    noApto: 'Embarazo, lactancia, alergias a los componentes, enfermedades autoinmunes o infección en la zona.',
  },
  cirugia: {
    preparacion: 'Requiere una consulta prequirúrgica previa con estudios y evaluación médica. Ayuno y medicación según indique el equipo.',
    despues: 'Reposo y controles según el protocolo de la cirugía. Las indicaciones completas se entregan por escrito.',
    noApto: 'Se define en la consulta prequirúrgica. Solo se agenda si la evaluación da "apto".',
  },
};

/* capa: epidermis | dermis | hipodermis. tipo: objeto de la vitrina (frasco, jeringa, laser, ondas, bisturi). */
const e = (familia, capa, tipo, sesiones, zona, extra = {}) => ({ familia, capa, tipo, sesiones, zona, ...extra });

const porId = {
  1: e('limpieza', 'epidermis', 'frasco', '1 sesión cada 4 a 6 semanas', 'Rostro'),
  2: e('peeling', 'epidermis', 'frasco', '3 a 6 sesiones, una cada 3 semanas', 'Rostro'),
  3: e('limpieza', 'epidermis', 'frasco', '1 sesión por mes', 'Rostro'),
  4: e('masaje', 'hipodermis', 'frasco', '1 sesión, o semanal si hay contractura', 'Espalda, cuello u hombros'),
  5: e('masaje', 'hipodermis', 'frasco', '6 a 10 sesiones, 1 o 2 por semana', 'Piernas, abdomen o brazos'),
  6: e('limpieza', 'epidermis', 'frasco', '4 a 8 sesiones, una cada 2 semanas', 'Rostro y espalda'),
  7: e('limpieza', 'epidermis', 'frasco', '1 sesión cada 4 semanas', 'Rostro'),
  8: e('peeling', 'epidermis', 'frasco', '1 sesión por mes', 'Cuerpo'),
  9: e('masaje', 'hipodermis', 'frasco', '6 a 8 sesiones', 'Abdomen, cintura o muslos'),
  10: e('laser', 'dermis', 'laser', '6 a 8 sesiones cada 4 a 6 semanas', 'Axilas, bozo o bikini'),
  11: e('laser', 'dermis', 'laser', '6 a 8 sesiones cada 6 a 8 semanas', 'Piernas'),
  12: e('aparatos', 'dermis', 'ondas', '6 a 8 sesiones, una por semana', 'Rostro y cuello'),
  13: e('aparatos', 'hipodermis', 'ondas', '8 a 10 sesiones, 1 o 2 por semana', 'Abdomen, muslos o brazos'),
  14: e('aparatos', 'hipodermis', 'ondas', '1 a 3 sesiones, con 6 a 8 semanas entre cada una', 'Abdomen, flancos o muslos'),
  15: e('aparatos', 'dermis', 'ondas', '1 sesión; el efecto se ve a los 2 o 3 meses', 'Rostro y cuello'),
  16: e('aparatos', 'dermis', 'jeringa', '6 a 10 sesiones, 1 o 2 por semana', 'Piernas, abdomen u ojeras'),
  17: e('laser', 'dermis', 'laser', '3 a 5 sesiones, una cada 4 semanas', 'Rostro, escote y manos'),
  18: e('inyectable', 'hipodermis', 'jeringa', '1 sesión cada 4 a 6 meses', 'Frente, entrecejo y patas de gallo'),
  19: e('inyectable', 'dermis', 'jeringa', '1 sesión; se repite a los 8 a 12 meses', 'Labios'),
  20: e('inyectable', 'dermis', 'jeringa', '1 sesión; se repite a los 9 a 12 meses', 'Surcos nasogenianos'),
  21: e('inyectable', 'dermis', 'jeringa', '2 o 3 sesiones, una cada 4 a 6 semanas', 'Rostro'),
  22: e('inyectable', 'dermis', 'jeringa', '4 a 6 sesiones, una cada 2 semanas', 'Rostro y cuello'),
  23: e('inyectable', 'dermis', 'jeringa', '3 sesiones, una cada 3 a 4 semanas', 'Rostro, cuello o cuero cabelludo'),
  24: e('inyectable', 'hipodermis', 'jeringa', '1 sesión; dura entre 12 y 18 meses', 'Rostro y cuello'),
  25: e('cirugia', 'hipodermis', 'bisturi', '1 consulta; es obligatoria antes de cualquier cirugía', 'Según la cirugía', {
    preparacion: 'Traer estudios previos si los tenés y la lista de medicación que tomás.',
    despues: 'Te explicamos si sos apta, qué estudios faltan y los pasos siguientes. Si seguís con la cirugía, el valor de la consulta se devuelve.',
    noApto: 'Si la evaluación no es favorable, se retiene el 10 % de la consulta y se devuelve el resto.',
  }),
  26: e('cirugia', 'hipodermis', 'bisturi', '1 cirugía, con controles a la semana y al mes', 'Nariz'),
  27: e('cirugia', 'hipodermis', 'bisturi', '1 cirugía, con faja y controles posteriores', 'Abdomen, flancos, espalda o muslos'),
  28: e('cirugia', 'hipodermis', 'bisturi', '1 cirugía, con controles posteriores', 'Mamas'),
  29: e('cirugia', 'hipodermis', 'bisturi', '1 cirugía ambulatoria', 'Párpados'),
  30: e('cirugia', 'hipodermis', 'bisturi', '1 cirugía, con faja y controles posteriores', 'Abdomen'),
  31: e('aparatos', 'dermis', 'jeringa', '3 a 6 sesiones, una cada 4 semanas', 'Rostro y cicatrices', {
    preparacion: 'Venir sin maquillaje ni exfoliantes por 3 días. Evitar el sol.',
    despues: 'Enrojecimiento parecido a una quemadura leve por 24 a 48 horas. Hidratar y usar protector solar factor 50.',
    noApto: 'Acné inflamatorio activo, herpes, embarazo o tendencia a cicatrices queloides.',
  }),
  32: e('peeling', 'epidermis', 'frasco', '4 a 6 sesiones, una cada 3 semanas', 'Rostro'),
  33: e('masaje', 'hipodermis', 'frasco', '8 a 12 sesiones, 2 por semana', 'Abdomen, cintura o muslos'),
  34: e('laser', 'dermis', 'laser', '6 a 8 sesiones cada 4 a 6 semanas', 'Rostro'),
  35: e('laser', 'dermis', 'laser', '6 a 8 sesiones cada 6 a 8 semanas', 'Cuerpo completo'),
  36: e('inyectable', 'hipodermis', 'jeringa', '6 a 8 sesiones, una por semana', 'Abdomen, muslos o glúteos'),
  37: e('aparatos', 'hipodermis', 'ondas', '8 a 10 sesiones, una por semana', 'Abdomen, flancos o muslos'),
  38: e('aparatos', 'hipodermis', 'ondas', '10 sesiones, 2 por semana', 'Piernas', {
    noApto: 'Várices complicadas, trombosis, embarazo o infecciones en las piernas.',
  }),
  39: e('inyectable', 'hipodermis', 'jeringa', '1 sesión cada 4 a 6 meses', 'Frente, ojos y parte baja del rostro'),
  40: e('inyectable', 'dermis', 'jeringa', '1 sesión; se retoca a los 9 a 12 meses', 'Ojeras'),
  41: e('inyectable', 'hipodermis', 'jeringa', '1 sesión; dura entre 12 y 18 meses', 'Mentón y mandíbula'),
  42: e('peeling', 'epidermis', 'laser', '1 sesión, con revisión previa de la lesión', 'Rostro y cuerpo', {
    preparacion: 'Venir sin maquillaje en la zona. Si el lunar cambió de forma o color, avisalo: antes hay que revisarlo.',
    despues: 'Costra pequeña que cae sola en 7 a 10 días. No sacarla, mantener limpio y usar protector solar.',
    noApto: 'Lesiones que cambian, sangran o no se ven benignas: en esos casos se deriva a dermatología.',
  }),
  43: e('cirugia', 'hipodermis', 'bisturi', '1 cirugía ambulatoria, con vendaje por 1 semana', 'Orejas'),
  44: e('cirugia', 'hipodermis', 'bisturi', '1 cirugía, con prenda de compresión por 4 semanas', 'Tórax'),
};

/* Ficha completa de un protocolo de la base. */
export function fichaDe(idBase) {
  const { familia, ...datos } = porId[idBase] ?? e('limpieza', 'epidermis', 'frasco', 'Se define en la consulta', '');
  return { ...familias[familia], ...datos };
}

/* Objeto de la vitrina: nombre para mostrar. */
export const tiposDeObjeto = {
  frasco: 'Cosmética y masajes',
  jeringa: 'Inyectables y microinyecciones',
  laser: 'Láser y luz',
  ondas: 'Aparatología',
  bisturi: 'Cirugía',
};
