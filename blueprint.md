# Blueprint: Mi Aplicación Flutter

## Visión General

Esta es una aplicación Flutter simple. El propósito de este documento es mantener un registro de la arquitectura, características y decisiones de diseño de la aplicación a medida que evoluciona.

## Estado Actual: Autenticación Rediseñada

### Estructura del Proyecto

*   `lib/main.dart`: Punto de entrada de la aplicación.
*   `lib/src/app.dart`: Widget raíz de la aplicación.
*   `lib/src/services/auth_service.dart`: Lógica de negocio para la autenticación con Firebase.
*   `lib/src/routing/app_router.dart`: Gestión de la navegación.
*   `lib/src/presentation/screens/auth/`: Contiene las pantallas de autenticación:
    *   `login_screen.dart`
    *   `register_screen.dart`
    *   `forgot_password_screen.dart`
*   `lib/src/presentation/screens/home_screen.dart`: Pantalla principal post-inicio de sesión.
*   `pubspec.yaml`: Dependencias del proyecto.

### Características

*   **Flujo de Autenticación con Email/Contraseña:** La aplicación ahora soporta un flujo de autenticación completo usando email y contraseña a través de Firebase.
*   **Pantallas de Autenticación Rediseñadas:** Se han rediseñado las siguientes pantallas con una interfaz de usuario consistente y centrada:
    *   **Login:** Incluye un logo ('%'), campos para email/usuario y contraseña, botón de ingreso y enlaces para registrarse o recuperar la contraseña.
    *   **Registro:** Incluye el mismo logo, campos para email, nombre de usuario y contraseña, botón de creación de cuenta y un enlace para iniciar sesión.
    *   **Recuperación de Contraseña:** Muestra el logo, un campo para el email, un botón para enviar el correo de recuperación y un enlace para volver al inicio de sesión.
*   **Barra de Navegación Personalizada:** La pantalla de inicio (`HomeScreen`) tiene una `AppBar` personalizada con un menú, logo, barra de búsqueda y un botón de perfil para cerrar sesión.

## Plan de Desarrollo Futuro

1.  **Implementar la lógica del cajón de navegación (drawer):** Añadir funcionalidad al botón de menú en la `AppBar`.
2.  **Desarrollar la funcionalidad de búsqueda:** Implementar la lógica de búsqueda para la barra en la `AppBar`.
3.  **Asociar nombre de usuario con perfil:** Al registrarse, guardar el nombre de usuario en el perfil del usuario de Firebase o en una colección de Firestore.
4.  **Reintroducir los modelos de datos:** Recrear las clases de modelo (`Post`, `Comment`, etc.) para la funcionalidad principal de la aplicación.
