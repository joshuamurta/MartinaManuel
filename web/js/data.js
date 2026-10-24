// Contenido del sitio: editá acá las cabañas y las opiniones.
window.SITE = {
  whatsapp: '5401126978208',
  // Proyecto de Firebase de la app de gestión ("flutter app"): de ahí sale qué
  // noches están ocupadas. Vacío = el calendario no muestra disponibilidad.
  firebaseProjectId: 'martina-manuel-gestion',

  cabins: [
    {
      id: 1, name: 'Cabaña 1', tag: 'Para dos', capacity: '2 adultos + niño', size: 35, photos: 14,
      blurb: 'Dos ambientes con vista al parque y la montaña.',
      features: [
        'Vista a la montaña',
        'Cocina comedor integrado',
        'Heladera con freezer, horno, microondas, pava eléctrica, cafetera y tostadora',
        'Habitación con cama matrimonial, placard y caja de seguridad',
        'Baño y antebaño con secador de pelo',
        'TV y aire acondicionado frío/calor',
        'Pérgola con parrillero',
        'Cochera cubierta'
      ]
    },
    {
      id: 2, name: 'Cabaña 2', tag: 'Con estufa a leña', capacity: '3 a 4 personas', size: 52, photos: 13,
      blurb: 'Dos ambientes con vista al parque y la montaña.',
      features: [
        'Vista a la montaña',
        'Cocina comedor integrado',
        'Heladera con freezer, horno, microondas, pava eléctrica, cafetera y tostadora',
        'Habitación con cama matrimonial, placard y caja de seguridad',
        '2 camas simples',
        'Baño y antebaño con secador de pelo',
        'TV y aire acondicionado frío/calor',
        'Estufa a leña',
        'Pérgola con parrillero',
        'Cochera cubierta'
      ]
    },
    {
      id: 3, name: 'Cabaña 3', tag: 'Vista a la montaña', capacity: 'hasta 5 personas', size: 48, photos: 14,
      blurb: 'Dos ambientes amplios con vista al parque y la montaña.',
      features: [
        'Cocina comedor integrado',
        'Heladera con freezer, horno, microondas, pava eléctrica, cafetera y tostadora',
        'Habitación con cama matrimonial, placard y caja de seguridad',
        '4 camas simples',
        'Baño y antebaño con secador de pelo',
        'TV y 2 aires acondicionados frío/calor',
        'Estufa a leña',
        'Pérgola con parrillero',
        'Cochera cubierta'
      ]
    },
    {
      id: 4, name: 'Cabaña 4', tag: 'Vista al río', capacity: 'hasta 5 personas', size: 48, photos: 12,
      blurb: 'Dos ambientes amplios frente a las piscinas, con vista al río.',
      features: [
        'Frente a las piscinas (exterior y climatizada)',
        'Cocina comedor integrado',
        'Heladera con freezer, horno, microondas, pava eléctrica, cafetera y tostadora',
        'Habitación con cama matrimonial, placard y caja de seguridad',
        '4 camas simples',
        'Baño y antebaño con secador de pelo',
        'TV y 2 aires acondicionados frío/calor',
        'Estufa a leña',
        'Pérgola con parrillero',
        'Cochera cubierta'
      ]
    },
    {
      id: 5, name: 'Cabaña 5', tag: 'Para familias', capacity: '6 a 7 personas', size: 78, photos: 19,
      blurb: 'Dos plantas y dos baños, con ambientes espaciosos.',
      features: [
        'Vista a la montaña',
        'Cocina comedor integrado',
        'Heladera con freezer, horno, microondas, pava eléctrica, cafetera y tostadora',
        '2 habitaciones en planta alta: 2 camas matrimoniales y 2 simples, o 4 simples. Placards y caja de seguridad',
        'Sofá cama en planta baja',
        'Un baño en cada planta, con secador de pelo',
        'TV y 3 aires acondicionados frío/calor',
        'Pérgola con parrillero',
        'Cochera cubierta'
      ]
    },
    {
      id: 6, name: 'Cabaña 6', tag: 'Superior · jacuzzi', capacity: 'hasta 6 personas', size: 65, photos: 10,
      blurb: 'Jardín privado con jacuzzi y dos habitaciones en suite.',
      features: [
        'Jardín privado con jacuzzi',
        '2 habitaciones en suite con cama matrimonial (configurable en camas simples), placard y caja de seguridad',
        'Cocina y comedor integrado de categoría',
        'Heladera con freezer, horno, microondas, pava eléctrica, cafetera y tostadora',
        'Baños con antebaño y secador de pelo',
        'TV y 2 aires acondicionados frío/calor',
        'Pérgola con parrillero, con vista al parque y la montaña',
        'Cochera cubierta'
      ]
    }
  ],

  reviews: [
    { name: 'Mauricio Bethular', text: 'Recomendable al cien por cien, ¡lugar soñado! La atención es excelente, Claudio y Eugenia impecables en su calidad humana. Sin dudas, cuando vuelva a San Rafael ya tengo un lugar donde alojarme.' },
    { name: 'Luciana Gambina', text: 'Complejo hermoso y súper recomendable. Muy bien ubicado, con bajada privada al río y con el mejor parque de los complejos de la zona. Cabañas cómodas con lo necesario. ¡Nos fuimos convencidos de volver ni bien podamos!' },
    { name: 'Adriana', text: 'Bellísimo lugar, todo impecable, los dueños están en todos los detalles. Las vistas de las cabañas son impagables, la pileta cubierta y el quincho con vista al río. Siempre está todo muy limpio y cuidado.' },
    { name: 'Carolina Giovazzini', text: 'Hermoso lugar, súper tranquilo (lo que buscábamos). Nos atendieron en todo momento, muy amables y cordiales. Pudimos disfrutar de ambas piletas, limpias, muy importante. Cada cabaña tenía su espacio privado.' },
    { name: 'Gonzalo Rodríguez', text: 'Excelente lugar para relajarte unos días en el Cañón del Atuel junto al río. Muy cómodo y con todos los servicios: piscinas, terrazas y fogonero. ¡Pasamos unos días maravillosos, volveremos! Gracias Eugenia y Claudio por estar atentos a cada detalle.' },
    { name: 'Facundo Paleato', text: 'Hermoso lugar. Bien equipado, prolijo y limpio. Las piletas son geniales, y el espacio de asador y horno de barro a orillas del río es un sueño. Eugenia y Claudio siempre atentos. Tienen una proveeduría muy completa. Gracias totales.' },
    { name: 'Valeria Mancuso', text: 'Las cabañas son hermosas, con todo lo necesario. Pileta climatizada y otra al aire libre, salida al río preciosa, reposeras, parrillas, horno de barro, muy completo todo. La atención, súper. ¡Volveremos!' },
    { name: 'Patricia Martinez', text: 'Espectacular entorno que elegimos con amigos. La vegetación, con especies diferentes de árboles y plantas, y el río Atuel al fondo... ¡impresionante! Tranquilidad total para quien necesita descansar y reconectar.' },
    { name: 'Macarena Heredia Mollani', text: 'Muy hermoso el lugar, bien completo, con parrillas individuales y comunitarias, pileta al aire libre y una climatizada. La verdad que bárbaro todo. ¡Súper recomendable!' }
  ]
};
