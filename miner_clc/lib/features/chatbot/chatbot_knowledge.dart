/// Base de conocimiento exhaustiva y estructurada de MINER CLC para el Chatbot Asistente
class ChatbotTopic {
  const ChatbotTopic({
    required this.id,
    required this.title,
    required this.category,
    required this.keywords,
    required this.summary,
    required this.fullResponse,
    required this.suggestions,
  });

  final String id;
  final String title;
  final String category;
  final List<String> keywords;
  final String summary;
  final String fullResponse;
  final List<String> suggestions;
}

class ChatbotKnowledge {
  static const List<ChatbotTopic> topics = [
    // ── 1. GENERALIDADES DEL SOFTWARE ──
    ChatbotTopic(
      id: 'general_info',
      title: '¿Qué es MINER CLC y para qué sirve?',
      category: 'General',
      keywords: ['que es', 'para que sirve', 'software', 'sistema', 'miner clc', 'ayuda', 'informacion', 'como funciona', 'inicio', 'manual'],
      summary: 'Sistema integral de monitoreo de gases, control de ventilación y seguridad para minería subterránea.',
      fullResponse: '''
**MINER CLC** es el sistema especializado de gestión y seguridad minera desarrollado para monitorear en tiempo real las condiciones ambientales en galerías subterráneas.

**Funciones principales:**
1. 📊 **Monitoreo de Gases:** Lectura continua de CO, O2, CO2, CH4, H2S y temperatura en 5 zonas clave.
2. 💨 **Control de Ventilación:** Gestión de ventiladores en modos **Automático** (regulación inteligente según gases) o **Manual** (0-100% de potencia).
3. 🚨 **Gestión de Alertas:** Detección instantánea de riesgos (Info, Advertencia, Peligro) y registro de resolución.
4. 👥 **Seguridad y Acceso:** Autenticación con cuentas de Google reales verificadas o usuarios locales protegidos por hashing SHA-256.
5. 🗄️ **Base de Datos y Auditoría:** Almacenamiento seguro en PostgreSQL con copias de respaldo y registro de auditoría (*Anexo A*).
''',
      suggestions: ['Límites de gases permitidos', '¿Cómo funciona la ventilación automática?', '¿Cómo inicio con Google?'],
    ),

    // ── 2. GASES Y LÍMITES PERMISIBLES ──
    ChatbotTopic(
      id: 'gas_limits',
      title: 'Límites de gases y umbrales de seguridad minera',
      category: 'Gases',
      keywords: ['limites', 'gases', 'umbrales', 'co', 'o2', 'co2', 'ch4', 'h2s', 'temperatura', 'niveles', 'norma', 'seguridad', 'ppm'],
      summary: 'Valores normales y límites de peligro legal para CO, O2, CO2, CH4, H2S y temperatura.',
      fullResponse: '''
**Tabla de Umbrales de Seguridad Minera en MINER CLC:**

• **CO (Monóxido de Carbono):**
  - Normal: `< 25 ppm`
  - Advertencia: `25 a 50 ppm`
  - ⚠️ **Peligro:** `> 50 ppm` (Riesgo grave de intoxicación/asfixia química).

• **O2 (Oxígeno):**
  - ⚠️ **Peligro por asfixia:** `< 19.5%` (Evacuar de inmediato).
  - Normal / Seguro: `19.5% a 23.5%` (Óptimo: 20.9%).
  - ⚠️ **Enriquecido:** `> 23.5%` (Alto riesgo de combustión espontánea).

• **CO2 (Dióxido de Carbono):**
  - Normal: `< 0.5% (5000 ppm)`
  - Peligro: `> 1.0%` (Pérdida de conciencia a >3%).

• **CH4 (Metano - Grisú):**
  - Normal: `< 0.5%`
  - Advertencia: `1.0%` (Revisar flujo de aire).
  - 🚨 **PELIGRO CRÍTICO:** `≥ 2.0%` (Límite legal para corte de energía eléctrica y evacuación por riesgo de explosión).

• **H2S (Ácido Sulfhídrico):**
  - Advertencia: `> 5 ppm`
  - ⚠️ **Peligro:** `> 10 ppm` (Altamente tóxico, paraliza el olfato).

• **Temperatura:**
  - Óptimo en labor: `18°C a 28°C`
  - Advertencia por estrés térmico: `> 30°C`.
''',
      suggestions: ['¿Qué hacer ante alerta de metano CH4?', '¿Cómo se mide el oxígeno O2?', '¿Cómo funciona la ventilación automática?'],
    ),

    // ── 3. METANO Y PROTOCOLO DE EMERGENCIA ──
    ChatbotTopic(
      id: 'ch4_emergency',
      title: 'Protocolo ante presencia o alerta de Metano (CH4)',
      category: 'Emergencias',
      keywords: ['metano', 'ch4', 'grisu', 'explosion', 'emergencia', 'alerta roja', 'fuga', 'peligro metano', 'que hacer'],
      summary: 'Procedimiento operativo de emergencia ante concentraciones elevadas de gas metano.',
      fullResponse: '''
🚨 **PROTOCOLO DE EMERGENCIA POR METANO (CH4):**

El metano forma mezclas explosivas con el aire entre el **5% y el 15%** (Límite Inferior y Superior de Explosividad).

**Pasos a seguir si el sensor marca ≥ 1.5% o 2.0%:**
1. **Corte Eléctrico:** Interrumpir el suministro eléctrico de la zona afectada para evitar chispas.
2. **Evacuación Inmediata:** Todo el personal del nivel debe retirarse hacia las vías de ventilación de aire fresco.
3. **Activar Ventilación al 100%:** En el módulo de Ventilación, forzar el ventilador de la zona a velocidad máxima para barrer el gas acumulado.
4. **No usar equipos no antiexplosivos:** Prohibido encender linternas o radios convencionales.
5. **Reportar al Centro de Control:** Notificar al Ingeniero de Seguridad y verificar en la pantalla de MINER CLC la disminución del porcentaje.
''',
      suggestions: ['Límites de gases permitidos', '¿Cómo activar ventilación manual?', '¿Cómo resolver una alerta?'],
    ),

    // ── 4. VENTILACIÓN ──
    ChatbotTopic(
      id: 'ventilation_modes',
      title: '¿Cómo funciona el sistema de ventilación (AUTO vs MANUAL)?',
      category: 'Ventilación',
      keywords: ['ventilacion', 'ventiladores', 'modo auto', 'modo manual', 'velocidad', 'control', 'como cambiar', 'potencia', 'aire'],
      summary: 'Diferencias y forma de operar el modo Automático inteligente y el modo Manual forzado.',
      fullResponse: '''
**El módulo de Ventilación de MINER CLC cuenta con dos modos:**

1. 🔄 **Modo AUTOMÁTICO (Recomendado):**
   - El sistema analiza continuamente las lecturas de los sensores de cada zona.
   - Si los gases se elevan (por ejemplo, CO > 30 ppm o CH4 > 0.8%), el algoritmo incrementa automáticamente la velocidad del ventilador del **20% al 100%**.
   - Cuando los niveles vuelven a la normalidad, la velocidad se reduce para optimizar el consumo de energía.

2. ⚙️ **Modo MANUAL:**
   - Permite al operador tomar el control absoluto del ventilador de una zona.
   - Puedes encender (**ON**), apagar (**OFF**) o deslizar la barra de velocidad entre **0% y 100%**.
   - Ideal para labores de mantenimiento, avance de frentes o barrido previo a detonaciones.

*Para cambiar el modo, ingresa a la pestaña "Ventilación" en el menú lateral y haz clic en el interruptor de la zona deseada.*
''',
      suggestions: ['Límites de gases permitidos', '¿Qué zonas tiene la mina?', '¿Qué hacer ante alerta de metano CH4?'],
    ),

    // ── 5. ZONAS MINERAS ──
    ChatbotTopic(
      id: 'zones_mapping',
      title: 'Zonas y niveles mineros monitoreados',
      category: 'Zonas',
      keywords: ['zonas', 'niveles', 'galerias', 'donde estan', 'zona 1', 'zona 2', 'norte', 'sur', 'este', 'oeste', 'central'],
      summary: 'Descripción de las 5 zonas monitoreadas por el sistema MINER CLC.',
      fullResponse: '''
**En MINER CLC se monitorean 5 zonas estratégicas de la mina:**

• **Zona 1 (Norte - Nivel 1):** Entrada principal y frente de explotación norte. Mayor flujo de aire fresco.
• **Zona 2 (Sur - Nivel 2):** Nivel intermedio de transporte y carga. Mayor tráfico de maquinaria diésel (vigilar CO).
• **Zona 3 (Este - Nivel 3):** Zona profunda de extracción. Alta concentración térmica y propensa a grisú (vigilar CH4 y O2).
• **Zona 4 (Oeste - Nivel 1):** Galería de desagüe y servicios auxiliares. Monitoreo constante de H2S.
• **Zona 5 (Central - Nivel 2):** Chimenea de ventilación central y cruce de galerías principales.

*Cada zona posee sensores dedicados de gases y ventiladores auxiliares sincronizados.*
''',
      suggestions: ['Límites de gases permitidos', '¿Cómo funciona la ventilación automática?', '¿Cómo resolver una alerta?'],
    ),

    // ── 6. ALERTAS Y CÓMO RESOLVERLAS ──
    ChatbotTopic(
      id: 'alerts_management',
      title: '¿Cómo funcionan y cómo se resuelven las alertas?',
      category: 'Alertas',
      keywords: ['alertas', 'alarma', 'resolver alerta', 'como resolver', 'notificaciones', 'quitar alerta', 'danger', 'warn', 'info'],
      summary: 'Explicación del ciclo de vida de una alerta y cómo marcarla como resuelta.',
      fullResponse: '''
**Gestión de Alertas en MINER CLC:**

**Clasificación de Alertas:**
• 🟢 **INFO:** Eventos del sistema, cambios de modo de ventilación o conexión de sensores.
• 🟡 **WARN (Advertencia):** Nivel de gas acercándose a límites permisibles. Requiere inspección preventiva.
• 🔴 **DANGER (Peligro):** Valor crítico superado. Se activa alarma visual y requiere acción inmediata.

**¿Cómo marcar una alerta como resuelta?**
1. Dirígete a la pestaña **"Alertas"** en el menú de la izquierda.
2. Identifica la alerta activa que ya fue atendida por la brigada de seguridad.
3. Haz clic en el botón verde **"Resolver"**.
4. El sistema registrará la fecha y hora exacta (`resolved_at`) en la base de datos PostgreSQL y la removerá del panel de alertas activas.
''',
      suggestions: ['Límites de gases permitidos', 'Protocolo ante presencia o alerta de Metano (CH4)', '¿Qué zonas tiene la mina?'],
    ),

    // ── 7. AUTENTICACIÓN CON GOOGLE REAL ──
    ChatbotTopic(
      id: 'google_auth',
      title: '¿Cómo iniciar sesión o registrarse con cuenta de Google real?',
      category: 'Seguridad',
      keywords: ['google', 'cuenta de google', 'gmail', 'iniciar con google', 'registrarse con google', 'cuenta real', 'oauth', 'login'],
      summary: 'Pasos para acceder con una cuenta auténtica de Google verificada.',
      fullResponse: '''
**Acceso con Cuenta de Google REAL en MINER CLC:**

El sistema cuenta con integración directa para autenticación con cuentas reales de Google:

1. En la pantalla de bienvenida / login, haz clic en el botón blanco **"Continuar con Google"**.
2. Ingresa tu correo electrónico de Google auténtico (por ejemplo: `tu_nombre@gmail.com` o correo corporativo).
3. El validador verificará que el correo cumpla con los estándares de Google y que no sea una cuenta temporal ni descartable.
4. Si es tu primera vez, **el sistema te registrará automáticamente** en la base de datos PostgreSQL asignándote el rol de Minero y sincronizando tu nombre.
5. Si ya estabas registrado, ingresarás inmediatamente al Dashboard principal.
''',
      suggestions: ['¿Cómo recuperar mi contraseña?', '¿Cómo funciona la ventilación automática?', '¿Qué es MINER CLC y para qué sirve?'],
    ),

    // ── 8. RECUPERACIÓN DE CONTRASEÑA ──
    ChatbotTopic(
      id: 'password_reset',
      title: '¿Cómo recuperar u olvidar mi contraseña?',
      category: 'Seguridad',
      keywords: ['recuperar contrasena', 'olvide contrasena', 'cambiar clave', 'password', 'olvido', 'restablecer'],
      summary: 'Procedimiento de recuperación de contraseña validando el documento de identidad.',
      fullResponse: '''
**Para restablecer tu contraseña en MINER CLC:**

1. En la pantalla de inicio de sesión, haz clic en el enlace **"Olvidé mi contraseña"**.
2. Ingresa tu nombre de **usuario** registrado.
3. Ingresa tu **Documento de Identidad (Cédula/DNI)** con el cual creaste tu cuenta.
4. Escribe la nueva contraseña y confírmala.
5. Presiona **"Restablecer"**.

*Por seguridad, si el documento no coincide con el registrado en la base de datos, el sistema denegará el cambio.*
''',
      suggestions: ['¿Cómo iniciar sesión o registrarse con cuenta de Google real?', '¿Qué es MINER CLC y para qué sirve?'],
    ),

    // ── 9. BASE DE DATOS Y RESPALDOS (ANEXO A) ──
    ChatbotTopic(
      id: 'db_backups',
      title: '¿Cómo realizar respaldos y consultar la base de datos?',
      category: 'Base de Datos',
      keywords: ['base de datos', 'respaldo', 'backup', 'postgresql', 'anexo a', 'restaurar', 'copia de seguridad', 'guardar'],
      summary: 'Información sobre la base de datos PostgreSQL, copias de seguridad y recuperación.',
      fullResponse: '''
**Base de Datos y Respaldos en MINER CLC (Cumplimiento Anexo A):**

• **Motor:** PostgreSQL (`miner_clc` en `localhost:5432`).
• **Tablas:** `usuarios`, `lecturas_gases`, `ventilacion`, `alertas`, `auditoria_logs` y `respaldos_historial`.

**Cómo generar un respaldo:**
1. Ejecuta el script automatizado:
   `python scripts/backup_database.py`
2. El script generará un archivo `.sql` con timestamp y compresión, calculando el checksum criptográfico **SHA-256**.
3. El respaldo queda registrado automáticamente en la tabla `respaldos_historial` y en `auditoria_logs`.

*Para restaurar una copia, utiliza `python scripts/restore_database.py` indicando el archivo a restablecer.*
''',
      suggestions: ['Límites de gases permitidos', '¿Qué es MINER CLC y para qué sirve?', '¿Cómo funciona la ventilación automática?'],
    ),
  ];
}
