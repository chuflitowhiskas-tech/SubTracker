# SubTracker — Documentación técnica del backend

Backend en Go que expone una API REST para suscripciones y tasas de cambio, con persistencia en
SQLite y un worker que actualiza las tasas automáticamente. Lo consume la app iOS
(ver [`SubTrackerApp/README.md`](../SubTrackerApp/README.md)).

## Arranque (`main.go`)

1. `db.InitDB()` abre la base SQLite (`./subtracker.db`), crea las tablas si no existen e inserta
   tasas por defecto si la tabla `exchange_rates` está vacía.
2. `worker.StartWorker()` lanza en una goroutine el worker de tasas (ver más abajo).
3. Se registran las rutas y el servidor escucha en el puerto `:8080`.

## Base de datos (`db/db.go`)

- `subscriptions`: `id` (PK), `name`, `cost`, `currency`, `billingDay`.
- `exchange_rates`: `id` (autoincremental), `usd_pen`, `ars_pen`, `updated_at` (timestamp).
  Guarda historial de tasas; la API lee siempre la fila más reciente
  (`ORDER BY updated_at DESC LIMIT 1`).
- Si no hay tasas, se inserta una fila inicial con USD/PEN = 3.8 y ARS/PEN = 0.003.

## Endpoints

### `GET /api/rates` → `handlers.RatesHandler`

Flujo: rechaza métodos que no sean GET (405) → consulta la última fila de `exchange_rates` →
responde JSON `{"usd_pen": ..., "ars_pen": ...}`. Si la consulta falla: **500**.

### `/api/subscriptions` → `handlers.SubscriptionsHandler`

Un solo handler que despacha según el método HTTP (cualquier otro método → **405**):

| Método | Comportamiento | Códigos de estado |
| --- | --- | --- |
| `GET` | Lista todas las suscripciones como JSON (array vacío si no hay). | 200 |
| `POST` | Decodifica el cuerpo JSON y ejecuta un `INSERT`. | 201; 400 si el payload es inválido; 500 si falla la consulta |
| `PUT` | Decodifica el cuerpo y ejecuta un `UPDATE WHERE id=?`. | 200; 404 si el `id` no existe (0 filas afectadas); 400/500 |
| `DELETE` | Toma `id` de la query string (`/api/subscriptions?id=<id>`) y elimina. | 200; 400 si falta el `id`; 404 si el `id` no existe; 500 |

Detalles del contrato:

- El `POST` requiere el `id` en el cuerpo (lo genera la app iOS con un UUID) y no valida campos
  más allá del parseo JSON.
- El `DELETE` usa query string en lugar de la ruta (`/api/subscriptions?id=`).
- Errores SQL a nivel de fila en el `GET` se saltan (`continue`), por lo que una fila corrupta no
  tumba el listado.

## Worker de tasas (`worker/worker.go`)

Goroutine que se ejecuta al arrancar y luego cada **1 hora**:

1. `fetchUSDPEN()`: consulta `https://open.er-api.com/v6/latest/USD` y extrae `rates.PEN`.
2. `fetchUSDARS()`: consulta `https://api.bluelytics.com.ar/v2/latest` y extrae el valor *blue*
   `blue.value_sell` (ARS por USD).
3. Calcula `arsPen = usdPen / usdArs`.
4. `insertRate()` inserta la fila en `exchange_rates` (con historial) y lo registra en el log.

Si alguna de las dos fuentes falla, el worker registra el error y **no** inserta nada,
conservando las tasas anteriores. Las funciones de fetch son inyectables
(`updateRatesWith`) para poder probar el flujo completo sin llamar a las APIs reales.

## Tests

- `handlers/handlers_test.go`: pruebas del handler de suscripciones.
- `worker/worker_test.go`: pruebas del flujo de actualización de tasas con fetchers simulados.

## Estructura y dependencias

- Módulo: `subtrackerbackend` (Go 1.24.3).
- Dependencia: `github.com/mattn/go-sqlite3` (driver SQLite).
- Ejecutar con `go run .` desde `SubTrackerBackend/`; la base `subtracker.db` se crea en el
  directorio de trabajo.
