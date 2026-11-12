/* GENERADO por scripts/generar-catalogo.mjs desde backend/02_datos.sql. No editar a mano. */
export const categorias = [
  {
    "id": "faciales",
    "idBase": 1,
    "nombre": "Faciales y corporales",
    "porcentajeSena": 30,
    "esCirugia": false
  },
  {
    "id": "aparatologia",
    "idBase": 2,
    "nombre": "Aparatología",
    "porcentajeSena": 30,
    "esCirugia": false
  },
  {
    "id": "medicina",
    "idBase": 3,
    "nombre": "Medicina estética",
    "porcentajeSena": 30,
    "esCirugia": false
  },
  {
    "id": "cirugias",
    "idBase": 4,
    "nombre": "Cirugías",
    "porcentajeSena": 40,
    "esCirugia": true
  }
];

export const protocolosBase = [
  {
    "id": "limpieza-facial-profunda",
    "idBase": 1,
    "nombre": "Limpieza facial profunda",
    "descripcion": "Limpieza, extracción y mascarilla.",
    "precio": 90000,
    "duracionMin": 60,
    "categoria": "faciales",
    "activo": true
  },
  {
    "id": "peeling-quimico",
    "idBase": 2,
    "nombre": "Peeling químico",
    "descripcion": "Renovación de la piel con ácidos.",
    "precio": 120000,
    "duracionMin": 45,
    "categoria": "faciales",
    "activo": true
  },
  {
    "id": "hidratacion-facial-hydrafacial",
    "idBase": 3,
    "nombre": "Hidratación facial (hydrafacial)",
    "descripcion": "Limpieza e hidratación con aparato.",
    "precio": 150000,
    "duracionMin": 60,
    "categoria": "faciales",
    "activo": true
  },
  {
    "id": "masaje-descontracturante",
    "idBase": 4,
    "nombre": "Masaje descontracturante",
    "descripcion": "Masaje corporal localizado.",
    "precio": 70000,
    "duracionMin": 50,
    "categoria": "faciales",
    "activo": true
  },
  {
    "id": "drenaje-linfatico",
    "idBase": 5,
    "nombre": "Drenaje linfático",
    "descripcion": "Técnica manual para retención de líquidos.",
    "precio": 80000,
    "duracionMin": 60,
    "categoria": "faciales",
    "activo": true
  },
  {
    "id": "tratamiento-anti-acne",
    "idBase": 6,
    "nombre": "Tratamiento anti-acné",
    "descripcion": "Protocolo para piel con acné activo.",
    "precio": 110000,
    "duracionMin": 50,
    "categoria": "faciales",
    "activo": true
  },
  {
    "id": "dermaplaning",
    "idBase": 7,
    "nombre": "Dermaplaning",
    "descripcion": "Exfoliación mecánica con bisturí.",
    "precio": 85000,
    "duracionMin": 45,
    "categoria": "faciales",
    "activo": true
  },
  {
    "id": "exfoliacion-corporal",
    "idBase": 8,
    "nombre": "Exfoliación corporal",
    "descripcion": "Exfoliación e hidratación corporal.",
    "precio": 95000,
    "duracionMin": 60,
    "categoria": "faciales",
    "activo": true
  },
  {
    "id": "envoltura-reductora",
    "idBase": 9,
    "nombre": "Envoltura reductora",
    "descripcion": "Envoltura con activos reductores.",
    "precio": 100000,
    "duracionMin": 70,
    "categoria": "faciales",
    "activo": true
  },
  {
    "id": "depilacion-laser-zona-chica",
    "idBase": 10,
    "nombre": "Depilación láser (zona chica)",
    "descripcion": "Axilas, bozo o línea de bikini.",
    "precio": 120000,
    "duracionMin": 30,
    "categoria": "aparatologia",
    "activo": true
  },
  {
    "id": "depilacion-laser-piernas-completas",
    "idBase": 11,
    "nombre": "Depilación láser (piernas completas)",
    "descripcion": "Sesión de piernas completas.",
    "precio": 280000,
    "duracionMin": 60,
    "categoria": "aparatologia",
    "activo": true
  },
  {
    "id": "radiofrecuencia-facial",
    "idBase": 12,
    "nombre": "Radiofrecuencia facial",
    "descripcion": "Tensado de la piel del rostro.",
    "precio": 180000,
    "duracionMin": 45,
    "categoria": "aparatologia",
    "activo": true
  },
  {
    "id": "radiofrecuencia-corporal",
    "idBase": 13,
    "nombre": "Radiofrecuencia corporal",
    "descripcion": "Tensado y reducción corporal.",
    "precio": 220000,
    "duracionMin": 60,
    "categoria": "aparatologia",
    "activo": true
  },
  {
    "id": "criolipolisis-por-sesion",
    "idBase": 14,
    "nombre": "Criolipólisis (por sesión)",
    "descripcion": "Reducción de grasa localizada por frío.",
    "precio": 450000,
    "duracionMin": 75,
    "categoria": "aparatologia",
    "activo": true
  },
  {
    "id": "lifting-no-invasivo-hifu",
    "idBase": 15,
    "nombre": "Lifting no invasivo (HIFU)",
    "descripcion": "Ultrasonido focalizado para tensar.",
    "precio": 400000,
    "duracionMin": 60,
    "categoria": "aparatologia",
    "activo": true
  },
  {
    "id": "carboxiterapia",
    "idBase": 16,
    "nombre": "Carboxiterapia",
    "descripcion": "Gas medicinal para celulitis y ojeras.",
    "precio": 140000,
    "duracionMin": 40,
    "categoria": "aparatologia",
    "activo": true
  },
  {
    "id": "luz-pulsada-intensa",
    "idBase": 17,
    "nombre": "Luz pulsada intensa",
    "descripcion": "Manchas, vasos y rejuvenecimiento.",
    "precio": 190000,
    "duracionMin": 40,
    "categoria": "aparatologia",
    "activo": true
  },
  {
    "id": "toxina-botulinica-tercio-superior",
    "idBase": 18,
    "nombre": "Toxina botulínica (tercio superior)",
    "descripcion": "Frente, entrecejo y patas de gallo.",
    "precio": 320000,
    "duracionMin": 30,
    "categoria": "medicina",
    "activo": true
  },
  {
    "id": "acido-hialuronico-en-labios",
    "idBase": 19,
    "nombre": "Ácido hialurónico en labios",
    "descripcion": "Hidratación y volumen de labios.",
    "precio": 450000,
    "duracionMin": 45,
    "categoria": "medicina",
    "activo": true
  },
  {
    "id": "relleno-de-surcos-nasogenianos",
    "idBase": 20,
    "nombre": "Relleno de surcos nasogenianos",
    "descripcion": "Relleno con ácido hialurónico.",
    "precio": 480000,
    "duracionMin": 45,
    "categoria": "medicina",
    "activo": true
  },
  {
    "id": "bioestimuladores-de-colageno",
    "idBase": 21,
    "nombre": "Bioestimuladores de colágeno",
    "descripcion": "Estimulan colágeno propio.",
    "precio": 700000,
    "duracionMin": 60,
    "categoria": "medicina",
    "activo": true
  },
  {
    "id": "mesoterapia-facial",
    "idBase": 22,
    "nombre": "Mesoterapia facial",
    "descripcion": "Microinyecciones de activos.",
    "precio": 260000,
    "duracionMin": 45,
    "categoria": "medicina",
    "activo": true
  },
  {
    "id": "plasma-rico-en-plaquetas",
    "idBase": 23,
    "nombre": "Plasma rico en plaquetas",
    "descripcion": "Rejuvenecimiento con plasma propio.",
    "precio": 380000,
    "duracionMin": 60,
    "categoria": "medicina",
    "activo": true
  },
  {
    "id": "hilos-tensores",
    "idBase": 24,
    "nombre": "Hilos tensores",
    "descripcion": "Lifting con hilos reabsorbibles.",
    "precio": 900000,
    "duracionMin": 90,
    "categoria": "medicina",
    "activo": true
  },
  {
    "id": "consulta-prequirurgica",
    "idBase": 25,
    "nombre": "Consulta prequirúrgica",
    "descripcion": "Evaluación obligatoria antes de una cirugía.",
    "precio": 80000,
    "duracionMin": 30,
    "categoria": "medicina",
    "activo": true
  },
  {
    "id": "rinoplastia",
    "idBase": 26,
    "nombre": "Rinoplastia",
    "descripcion": "Cirugía de nariz.",
    "precio": 4500000,
    "duracionMin": 180,
    "categoria": "cirugias",
    "activo": true
  },
  {
    "id": "lipoescultura",
    "idBase": 27,
    "nombre": "Lipoescultura",
    "descripcion": "Moldeado corporal con liposucción.",
    "precio": 5800000,
    "duracionMin": 240,
    "categoria": "cirugias",
    "activo": true
  },
  {
    "id": "mamoplastia-de-aumento",
    "idBase": 28,
    "nombre": "Mamoplastia de aumento",
    "descripcion": "Aumento mamario.",
    "precio": 7200000,
    "duracionMin": 210,
    "categoria": "cirugias",
    "activo": true
  },
  {
    "id": "blefaroplastia",
    "idBase": 29,
    "nombre": "Blefaroplastia",
    "descripcion": "Cirugía de párpados.",
    "precio": 2500000,
    "duracionMin": 120,
    "categoria": "cirugias",
    "activo": true
  },
  {
    "id": "abdominoplastia",
    "idBase": 30,
    "nombre": "Abdominoplastia",
    "descripcion": "Cirugía de abdomen.",
    "precio": 9000000,
    "duracionMin": 270,
    "categoria": "cirugias",
    "activo": true
  },
  {
    "id": "microneedling-dermapen",
    "idBase": 31,
    "nombre": "Microneedling (dermapen)",
    "descripcion": "Microperforaciones para estimular colágeno y mejorar cicatrices.",
    "precio": 200000,
    "duracionMin": 60,
    "categoria": "aparatologia",
    "activo": true
  },
  {
    "id": "tratamiento-de-manchas",
    "idBase": 32,
    "nombre": "Tratamiento de manchas",
    "descripcion": "Peeling despigmentante con ácido tranexámico y protector.",
    "precio": 130000,
    "duracionMin": 50,
    "categoria": "faciales",
    "activo": true
  },
  {
    "id": "masaje-reductor",
    "idBase": 33,
    "nombre": "Masaje reductor",
    "descripcion": "Masaje modelador para zonas con grasa localizada.",
    "precio": 75000,
    "duracionMin": 50,
    "categoria": "faciales",
    "activo": true
  },
  {
    "id": "depilacion-laser-rostro-completo",
    "idBase": 34,
    "nombre": "Depilación láser (rostro completo)",
    "descripcion": "Sesión de rostro completo, sin zona de cuello.",
    "precio": 150000,
    "duracionMin": 30,
    "categoria": "aparatologia",
    "activo": true
  },
  {
    "id": "depilacion-laser-cuerpo-completo",
    "idBase": 35,
    "nombre": "Depilación láser (cuerpo completo)",
    "descripcion": "Sesión de cuerpo completo en un mismo turno.",
    "precio": 520000,
    "duracionMin": 120,
    "categoria": "aparatologia",
    "activo": true
  },
  {
    "id": "mesoterapia-corporal",
    "idBase": 36,
    "nombre": "Mesoterapia corporal",
    "descripcion": "Microinyecciones de activos en zonas con celulitis.",
    "precio": 240000,
    "duracionMin": 45,
    "categoria": "medicina",
    "activo": true
  },
  {
    "id": "ultracavitacion",
    "idBase": 37,
    "nombre": "Ultracavitación",
    "descripcion": "Ultrasonido de baja frecuencia para grasa localizada.",
    "precio": 130000,
    "duracionMin": 45,
    "categoria": "aparatologia",
    "activo": true
  },
  {
    "id": "presoterapia",
    "idBase": 38,
    "nombre": "Presoterapia",
    "descripcion": "Compresión secuencial para piernas cansadas y retención de líquidos.",
    "precio": 60000,
    "duracionMin": 40,
    "categoria": "aparatologia",
    "activo": true
  },
  {
    "id": "toxina-botulinica-rostro-completo",
    "idBase": 39,
    "nombre": "Toxina botulínica (rostro completo)",
    "descripcion": "Frente, entrecejo, patas de gallo y tercio inferior.",
    "precio": 520000,
    "duracionMin": 45,
    "categoria": "medicina",
    "activo": true
  },
  {
    "id": "relleno-de-ojeras",
    "idBase": 40,
    "nombre": "Relleno de ojeras",
    "descripcion": "Relleno con ácido hialurónico en el surco de la ojera.",
    "precio": 520000,
    "duracionMin": 45,
    "categoria": "medicina",
    "activo": true
  },
  {
    "id": "perfilado-de-menton-y-mandibula",
    "idBase": 41,
    "nombre": "Perfilado de mentón y mandíbula",
    "descripcion": "Definición del contorno inferior con ácido hialurónico.",
    "precio": 650000,
    "duracionMin": 60,
    "categoria": "medicina",
    "activo": true
  },
  {
    "id": "eliminacion-de-lunares-y-verrugas",
    "idBase": 42,
    "nombre": "Eliminación de lunares y verrugas",
    "descripcion": "Electrocoagulación de lesiones benignas, previa revisión.",
    "precio": 90000,
    "duracionMin": 30,
    "categoria": "medicina",
    "activo": true
  },
  {
    "id": "otoplastia",
    "idBase": 43,
    "nombre": "Otoplastia",
    "descripcion": "Cirugía para corregir la posición de las orejas.",
    "precio": 3800000,
    "duracionMin": 150,
    "categoria": "cirugias",
    "activo": true
  },
  {
    "id": "ginecomastia",
    "idBase": 44,
    "nombre": "Ginecomastia",
    "descripcion": "Cirugía para reducir el tejido mamario masculino.",
    "precio": 4200000,
    "duracionMin": 150,
    "categoria": "cirugias",
    "activo": true
  }
];

export const profesionalesBase = [
  {
    "id": 1,
    "matricula": "MN 112233",
    "nombre": "Julieta",
    "apellido": "Marino",
    "activo": true,
    "protocolos": [
      1,
      2,
      22,
      25,
      36,
      42
    ]
  },
  {
    "id": 2,
    "matricula": "MN 445566",
    "nombre": "Andrés",
    "apellido": "Quiroga",
    "activo": true,
    "protocolos": [
      10,
      18,
      22,
      34,
      39
    ]
  },
  {
    "id": 4,
    "matricula": "MN 121963",
    "nombre": "Ricardo",
    "apellido": "Paz",
    "activo": true,
    "protocolos": [
      5,
      6,
      7,
      10,
      14,
      19,
      22,
      25,
      34,
      37,
      40
    ]
  },
  {
    "id": 5,
    "matricula": "MN 129284",
    "nombre": "Ana",
    "apellido": "Beltrán",
    "activo": true,
    "protocolos": [
      1,
      2,
      3,
      6,
      12,
      14,
      17,
      25,
      31,
      42
    ]
  },
  {
    "id": 6,
    "matricula": "MN 136605",
    "nombre": "Hernán",
    "apellido": "Cáceres",
    "activo": true,
    "protocolos": [
      1,
      4,
      5,
      9,
      12,
      18,
      25,
      33,
      39
    ]
  },
  {
    "id": 7,
    "matricula": "MN 143926",
    "nombre": "Lorena",
    "apellido": "Vidal",
    "activo": true,
    "protocolos": [
      2,
      10,
      13,
      19,
      23,
      35,
      41
    ]
  },
  {
    "id": 8,
    "matricula": "MN 151247",
    "nombre": "Gustavo",
    "apellido": "Roldán",
    "activo": true,
    "protocolos": [
      3,
      4,
      6,
      17,
      18,
      21,
      23,
      32,
      39
    ]
  },
  {
    "id": 9,
    "matricula": "MN 158568",
    "nombre": "Patricia",
    "apellido": "Lemos",
    "activo": true,
    "protocolos": [
      9,
      11,
      13,
      18,
      24,
      35
    ]
  },
  {
    "id": 10,
    "matricula": "MN 165889",
    "nombre": "Esteban",
    "apellido": "Maidana",
    "activo": true,
    "protocolos": [
      2,
      6,
      7,
      10,
      19,
      22,
      34,
      36,
      41
    ]
  },
  {
    "id": 11,
    "matricula": "MN 173210",
    "nombre": "Cecilia",
    "apellido": "Bustos",
    "activo": true,
    "protocolos": [
      5,
      7,
      10,
      12,
      13,
      18,
      31,
      35
    ]
  },
  {
    "id": 12,
    "matricula": "MN 180531",
    "nombre": "Federico",
    "apellido": "Arce",
    "activo": true,
    "protocolos": [
      14,
      16,
      20,
      21,
      37,
      40
    ]
  },
  {
    "id": 13,
    "matricula": "MN 187852",
    "nombre": "Mónica",
    "apellido": "Ferrari",
    "activo": true,
    "protocolos": [
      1,
      6,
      11,
      17,
      18,
      23,
      32,
      36,
      42
    ]
  },
  {
    "id": 14,
    "matricula": "MN 195173",
    "nombre": "Joaquín",
    "apellido": "Salas",
    "activo": true,
    "protocolos": [
      1,
      4,
      6,
      17,
      22,
      32,
      38
    ]
  },
  {
    "id": 15,
    "matricula": "MN 202494",
    "nombre": "Valeria",
    "apellido": "Montes",
    "activo": true,
    "protocolos": [
      3,
      7,
      10,
      12,
      38
    ]
  },
  {
    "id": 16,
    "matricula": "MN 209815",
    "nombre": "Rodrigo",
    "apellido": "Ojeda",
    "activo": true,
    "protocolos": [
      4,
      5,
      8,
      11,
      20,
      31,
      33
    ]
  },
  {
    "id": 17,
    "matricula": "MN 217136",
    "nombre": "Silvia",
    "apellido": "Palacios",
    "activo": true,
    "protocolos": [
      4,
      16,
      24,
      25,
      26,
      27,
      28,
      29,
      30,
      41,
      43,
      44
    ]
  },
  {
    "id": 18,
    "matricula": "MN 224457",
    "nombre": "Tomás",
    "apellido": "Escobar",
    "activo": true,
    "protocolos": [
      3,
      9,
      13,
      25,
      26,
      27,
      28,
      29,
      30,
      43,
      44
    ]
  },
  {
    "id": 19,
    "matricula": "MN 231778",
    "nombre": "Elena",
    "apellido": "Quiroz",
    "activo": true,
    "protocolos": [
      10,
      20,
      21,
      25,
      26,
      27,
      28,
      29,
      30,
      40,
      43,
      44
    ]
  },
  {
    "id": 20,
    "matricula": "MN 239099",
    "nombre": "Damián",
    "apellido": "Funes",
    "activo": true,
    "protocolos": [
      4,
      12,
      16,
      18,
      33,
      37,
      38
    ]
  }
];
