# Mis Quincenas

App personal de finanzas pensada para quien cobra por quincena: muestra cuánto tienes **libre para gastar**, qué pagos fijos te faltan, cómo vas con el presupuesto y cómo avanzan tu fondo de emergencia y tus deudas.

- Funciona en el navegador y se instala en la pantalla de inicio (iPhone y Android).
- Abre sin internet.
- Cuentas de usuario y base de datos con **Supabase**: tus datos se sincronizan entre celular y computador.
- Cada usuario solo puede ver sus propios datos (Row Level Security).

## Instalar en el celular
- **iPhone (Safari):** Compartir → *Agregar a inicio*.
- **Android (Chrome):** menú ⋮ → *Instalar app* o *Agregar a la pantalla principal*.

## Actualizar
Cambia los archivos, sube el número de `CACHE` en `sw.js` y haz push. GitHub Pages publica solo.

## Funciones
- Cuentas de usuario (correo y contraseña) y sincronización en vivo entre dispositivos.
- Quincenas del calendario o de pago a pago (15 y 30).
- Inicio con "Libre para gastar", pagos pendientes y presupuesto por categoría.
- Movimientos con categorías propias, descripción, edición, papelera y deshacer.
- Resumen con gráficas (por categoría, mes a mes, ritmo de la quincena) y metas/deudas.
- Perfil con foto, nombre, frase, color y tema; copias de seguridad; empezar de cero.

## Estructura
- `index.html`: la app completa.
- `config.js`: conexión con Supabase (URL y clave pública).
- `sw.js`, `manifest.webmanifest`, íconos: instalación en el celular y uso sin internet.
- `supabase/migrations/`: estructura de la base de datos, en orden.

## Configurar la base de datos (proyecto nuevo)
1. Crea un proyecto gratis en [supabase.com](https://supabase.com).
2. En **SQL Editor**, ejecuta en orden los archivos de `supabase/migrations/`.
3. En **Authentication → URL Configuration**, pon como *Site URL* la dirección de GitHub Pages.
4. En **Project Settings → API**, copia la *Project URL* y la *anon public key* en `config.js`.
