# SubTracker — Documentación técnica de la app (iOS)

App iOS nativa en SwiftUI para llevar el control de suscripciones recurrentes. Guarda las
suscripciones localmente con SwiftData, las sincroniza con el backend (ver
[`SubTrackerBackend/README.md`](../SubTrackerBackend/README.md)) y genera recordatorios de pago
(notificación local + evento de calendario).

## Arquitectura

| Capa | Archivo | Responsabilidad |
| --- | --- | --- |
| Entrada | `App/SubTrackerApp.swift` | Punto de entrada. Crea el contenedor SwiftData (`Subscription`, `ExchangeRatesCache`) e inicia la `DashboardView`. |
| Modelos | `Models/Models.swift` | Modelos SwiftData (`Subscription`, `ExchangeRatesCache`) y DTOs de la API (`ApiSubscription`, `ApiExchangeRates`). |
| Servicios | `Services/ApiClient.swift` | Cliente HTTP del backend (`http://localhost:8080/api`). |
| Servicios | `Services/Services.swift` | Permisos, notificaciones, eventos de calendario y lógica de cobro (`BillingLogic`). |
| Vistas | `Views/Views.swift` | `DashboardView`, `SubscriptionRow`, `AddSubscriptionView`, `EditSubscriptionView`. |

## Flujo general

1. La app arranca con la `DashboardView` y dispara `syncData()` al aparecer la vista (`.task`).
2. La sincronización hace dos llamadas secuenciales al backend:
   - `GET /api/rates` → actualiza o crea la fila `ExchangeRatesCache` local (tasas USD/PEN y ARS/PEN).
   - `GET /api/subscriptions` → inserta en SwiftData cada suscripción del backend que la app aún
     no tenga localmente (comparación por `id`; las locales no se borran — sync simplificada, sin
     diff real ni borrado remoto).
3. Si alguna de las dos llamadas falla, se muestra la alerta *"Couldn't Sync"* con opción de
   reintentar. La app sigue funcionando con los datos locales.
4. También se puede sincronizar manualmente con el gesto *pull-to-refresh* de la lista.

## Flujo de alta (agregar suscripción)

1. El botón **+** de la barra abre `AddSubscriptionView` (hoja).
2. El formulario pide nombre, costo, moneda (`PEN`, `USD`, `ARS`) y día de cobro (1–31).
   El botón *Save* se deshabilita si el nombre está vacío o el costo ≤ 0.
3. Al guardar:
   - Se inserta la `Subscription` en el contexto SwiftData local.
   - Se piden permisos de notificaciones y calendario (si aún no están) y se agenda el recordatorio.
   - En background, `POST /api/subscriptions` crea la suscripción en el backend (se espera HTTP 201).
4. Se cierra la hoja y la fila aparece en el dashboard.

## Flujo de edición

1. Tocar una fila abre `EditSubscriptionView` con los valores actuales precargados.
2. Al guardar:
   - Se actualizan los campos de la suscripción en el contexto local.
   - Se re-agenda la notificación y el evento con la nueva fecha de cobro
     (`scheduleNotificationAndEvent` reemplaza la notificación usando el `id` de la suscripción).
   - En background, `PUT /api/subscriptions` actualiza el backend (se espera HTTP 200).

## Flujo de borrado

1. *Swipe-to-delete* no borra de inmediato: muestra un diálogo de confirmación (*confirmationDialog*)
   describiendo qué se elimina.
2. Al confirmar:
   - Se elimina la `Subscription` del contexto local.
   - Se cancela la notificación pendiente del recordatorio (`cancelNotification`).
   - En background, `DELETE /api/subscriptions?id=<id>` borra en el backend (se espera HTTP 200).

## Conversión a PEN y totales

- `ExchangeRatesCache` guarda las tasas `usdPen` y `arsPen`; si aún no hay fila se usan los valores
  por defecto (USD/PEN = 3.8, ARS/PEN = 0.003).
- El dashboard suma mensualmente cada suscripción convertida a PEN (`convertToPEN`) y muestra
  además el total anual (mensual × 12).
- Cada fila muestra el costo en su moneda original y, si no es PEN, el equivalente aproximado.

## Próxima fecha de cobro y recordatorios (`SystemIntegrations` / `BillingLogic`)

- `BillingLogic.calculateNextBillingDate(billingDay:)` calcula la próxima fecha de cobro a partir
  del día del mes, manejando los meses cortos (p. ej. día 31 en febrero → último día del mes).
  Si el día ya pasó este mes, la fecha salta al mes siguiente.
- Al agregar/editar una suscripción se agenda:
  - Notificación local (`UNCalendarNotificationTrigger`) un día antes de la fecha de cobro, con
    el texto *"Your subscription for \<nombre\> is due tomorrow"*.
  - Evento de calendario (*"Pay \<nombre\>"*) de una hora el día del cobro, si el acceso al
    calendario está autorizado.
- `requestPermissions()` pide permisos de notificaciones y calendario juntos (granular: API ≥ 17
  usa acceso completo a eventos).

## Contrato con la API (resumen)

| Operación | Método y ruta | Código esperado |
| --- | --- | --- |
| Obtener tasas | `GET /api/rates` | 200 |
| Listar suscripciones | `GET /api/subscriptions` | 200 |
| Crear suscripción | `POST /api/subscriptions` | 201 |
| Actualizar suscripción | `PUT /api/subscriptions` | 200 |
| Borrar suscripción | `DELETE /api/subscriptions?id=<id>` | 200 |

El `baseURL` apunta a `http://localhost:8080/api`, por lo que el backend debe estar corriendo para
que la sincronización tenga éxito (si no, la app funciona offline con datos locales y avisa al
sincronizar).
