# Blueprint: Refactorización de Repositorios e Implementación de Notifiers

## Visión General

El objetivo es alinear la arquitectura de la aplicación Flutter con la de la app nativa. Se refactorizaron los repositorios de datos y ahora se implementará la capa de lógica de negocio utilizando el patrón `ChangeNotifier` con `provider`, que es el equivalente al patrón ViewModel utilizado en la versión de Kotlin.

## Fase 1: Refactorización de Repositorios (Completada)

- Se reescribieron `AuthRepository` y `PostRepository` para que su estructura y lógica sean una réplica fiel de las implementaciones nativas.

## Fase 2: Implementación de la Lógica de Negocio (ViewModels/Notifiers)

### 1. Crear `SessionManager`

-   **Archivo:** `lib/src/data/services/session_manager.dart`
-   **Propósito:** Gestionar el estado de la sesión y las preferencias del usuario de forma persistente.
-   **Dependencia:** Se añadirá `shared_preferences` al `pubspec.yaml`.
-   **Funcionalidad:**
    -   Guardar/leer el estado de `isLoggedIn`.
    -   Guardar/leer la preferencia del tema (`isDarkMode`).
    -   Exponer `Streams` (equivalentes a `Flow`) para escuchar cambios en estos valores.

### 2. Crear `AuthNotifier` (Equivalente a `AuthViewModel`)

-   **Archivo:** `lib/src/application/auth/auth_notifier.dart`
-   **Propósito:** Manejar toda la lógica y el estado relacionados con la autenticación.
-   **Estructura:**
    -   Heredará de `ChangeNotifier`.
    -   Dependerá de `AuthRepository` y `SessionManager`.
    -   Se creará un archivo `auth_state.dart` para definir los diferentes estados (Idle, Loading, Success, Error).
-   **Funcionalidad:**
    -   Métodos `login`, `register`, `logout`, `resetPassword`.
    -   Gestión del estado de la UI (e.g., `_state.value = AuthState.Loading`).
    -   Actualización del `SessionManager` tras un login/logout exitoso.

### 3. Crear `ThemeNotifier` (Equivalente a `ThemeViewModel`)

-   **Archivo:** `lib/src/application/theme/theme_notifier.dart`
-   **Propósito:** Gestionar el tema de la aplicación.
-   **Estructura:**
    -   Heredará de `ChangeNotifier`.
    -   Dependerá de `SessionManager`.
-   **Funcionalidad:**
    -   Exponer el estado actual del tema (`isDarkMode`).
    -   Método `setTheme` para cambiar y persistir la preferencia.

### 4. Crear `MainNotifier` (Equivalente a `MainViewModel`)

-   **Archivo:** `lib/src/application/main/main_notifier.dart`
-   **Propósito:** Orquestar la lógica de negocio principal de la aplicación.
-   **Estructura:**
    -   Heredará de `ChangeNotifier`.
    -   Dependerá de `AuthRepository` y `PostRepository`.
-   **Funcionalidad:** Replicará todos los métodos y propiedades de `MainViewModel`, incluyendo:
    -   Carga y paginación de posts (`loadMorePosts`, `refreshPosts`).
    -   Gestión de posts (favoritos, de usuario, etc.).
    -   Gestión de comentarios.
    -   Lógica de perfiles de usuario (seguir, dejar de seguir).
    -   Manejo de estado de carga, filtros y ordenación.

### 5. Integración con `MultiProvider`

-   **Archivo:** `lib/main.dart`
-   **Acción:** Envolver el widget principal de la aplicación con `MultiProvider` para registrar e inyectar `AuthNotifier`, `ThemeNotifier` y `MainNotifier` en el árbol de widgets, haciéndolos accesibles para toda la UI.

## Pasos de Ejecución

1.  Actualizar este archivo `blueprint.md`.
2.  Añadir la dependencia `shared_preferences` a `pubspec.yaml`.
3.  Crear `lib/src/data/services/session_manager.dart`.
4.  Crear `lib/src/application/auth/auth_state.dart`.
5.  Crear `lib/src/application/auth/auth_notifier.dart`.
6.  Crear `lib/src/application/theme/theme_notifier.dart`.
7.  Crear `lib/src/application/main/main_notifier.dart`.
8.  Actualizar `lib/main.dart` para usar `MultiProvider`.
