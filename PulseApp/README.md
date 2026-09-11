# Pulse — App iOS nativa (SwiftUI + WidgetKit)

App iOS 17+ para compartir el estado de ánimo con tu pareja en tiempo real, con un widget
interactivo de Lock Screen. Optimizada para 120 Hz ProMotion.

## Targets

| Target | Carpeta | Responsabilidad |
| --- | --- | --- |
| `PulseApp` | `PulseApp/` | App principal: onboarding, pairing, mood grid, ajustes, push. |
| `PulseWidgetExtension` | `PulseWidgetExtension/` | Widget interactivo de Lock Screen (`.accessoryRectangular`) y Home Screen (`.systemSmall`). |

Ambos targets comparten el App Group `group.com.pulse.app` y compilan el mismo conjunto de
modelos/servicios (`DesignSystem`, `Models`, `Shared`, `PulseAPIClient`) para que la lectura del
widget y la escritura de la app nunca diverjan de formato.

## Arquitectura

- **`Shared/PulseSharedStore.swift`**: única puerta de entrada al `UserDefaults(suiteName:)`
  compartido. La app y el widget leen/escriben exclusivamente a través de este tipo.
- **`Services/PulseAPIClient.swift`**: cliente `URLSession` async/await para el backend Go
  (`https://api.tu-vps.com/api/v1`).
- **`Services/PairingStore.swift`**: `ObservableObject` que orquesta el estado de pairing
  (`ConnectionState`) y el mood propio, sincronizando siempre con `PulseSharedStore`.
- **`App/PulseAppDelegate.swift`**: registro de push, y el pipeline
  `content-available` → `PulseSharedStore` → `WidgetCenter.reloadAllTimelines()`.
- **`PulseWidgetExtension/UpdateMoodIntent.swift`**: `AppIntent` que corre botones interactivos
  del widget de Lock Screen sin abrir la app (`openAppWhenRun = false`).

## Máquina de estados de conexión

`ConnectionState` (`idle` → `pendingOutgoing`/`pendingIncoming` → `connected`) determina qué
sección central muestra `MainView`, y se persiste en el App Group para que tanto la app como el
widget conozcan si hay una pareja conectada.

## Rendimiento 120 Hz

- `CADisableMinimumFrameDurationOnPhone = true` en `Info.plist` habilita ProMotion sin límite de
  frame duration.
- Todas las transiciones de estado usan `.spring(response: 0.35, dampingFraction: 0.75)` y
  hápticos (`UIImpactFeedbackGenerator`) en las interacciones clave (copiar código, aceptar/
  rechazar, cambiar de mood).

## Notificaciones push

- Autorización `.alert`, `.sound`, `.badge` vía `UNUserNotificationCenter`.
- `mood_update` (`content-available: 1`): actualiza `PulseSharedStore`, recarga timelines del
  widget y responde `.newData`.
- `connection_request`: banner local visible ("[Partner] quiere conectarse contigo").

## Widget de Lock Screen

`PulseWidgetProvider` lee exclusivamente de `PulseSharedStore` (nunca red) para renderizar sin
latencia. La fila 1 muestra el mood del partner con marca de tiempo relativa; la fila 2 expone tres
botones (`Button(intent: UpdateMoodIntent(mood:))`) que escriben el nuevo mood de inmediato y
disparan `POST /status` en segundo plano.
