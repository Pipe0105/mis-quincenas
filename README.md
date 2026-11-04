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

## Configurar la base de datos (una sola vez)
1. Crea un proyecto gratis en [supabase.com](https://supabase.com).
2. En **SQL Editor**, pega y ejecuta `schema.sql`.
3. En **Authentication → URL Configuration**, pon como *Site URL* la dirección de GitHub Pages (ej. `https://pipe0105.github.io/mis-quincenas/`).
4. En **Project Settings → API**, copia la *Project URL* y la *anon public key* en `config.js`.
