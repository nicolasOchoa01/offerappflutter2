# Blueprint: Aplicación de Ofertas

## Visión General

El objetivo de este proyecto es construir una aplicación móvil completa con Flutter y Firebase que permita a los usuarios descubrir y compartir ofertas. La arquitectura sigue un patrón MVVM (Model-View-ViewModel) utilizando `ChangeNotifier` como el componente principal para la lógica de negocio, sirviendo como un ViewModel.

## Arquitectura y Componentes Clave

-   **Provider (`ChangeNotifier`)**: Es el corazón de la gestión de estado. Los `Notifiers` (`AuthNotifier`, `MainNotifier`, `ThemeNotifier`) exponen el estado y la lógica de negocio a la UI.
-   **Repositorios (`AuthRepository`, `PostRepository`)**: Capa de acceso a datos que interactúa directamente con Firebase (Firestore) y otros servicios como Cloudinary. Abstrae el origen de los datos.
-   **GoRouter**: Gestiona la navegación y el enrutamiento de la aplicación, permitiendo una navegación declarativa y manejo de enlaces profundos.
-   **Firebase**: Utilizado para autenticación de usuarios (Authentication) y como base de datos en tiempo real (Firestore).
-   **Cloudinary**: Servicio externo para el almacenamiento y la gestión de imágenes.

## Estado Actual y Funcionalidades Implementadas

-   **Autenticación**: Flujo completo de registro, inicio de sesión y cierre de sesión.
-   **Feed Principal**: Muestra una lista de todas las publicaciones (ofertas) con scroll infinito.
-   **Creación de Posts**: Los usuarios pueden crear nuevas publicaciones con imagen, descripción, precio, etc.
-   **Detalle de Post**: Vista detallada para cada publicación, incluyendo sus comentarios.
-   **Perfiles de Usuario**: Pantalla de perfil donde se muestran las publicaciones, comentarios y favoritos de un usuario.
-   **Lógica de "Seguir"**: Los usuarios pueden seguirse entre sí.
-   **Gestión de Favoritos**: Los usuarios pueden marcar publicaciones como favoritas.

## Problema Actual: Datos no se muestran en el perfil

Se ha diagnosticado que la pantalla de perfil (`profile_screen.dart`) no muestra las publicaciones, comentarios y favoritos del usuario a pesar de que los datos existen en la base de datos. La causa raíz no es un error en el código de la aplicación, sino una **configuración faltante en Firestore**.

### Diagnóstico

Las consultas requeridas para obtener los datos del perfil son compuestas, combinando una cláusula `where` (para filtrar por `userId`) con una cláusula `orderBy` (para ordenar por `timestamp`).

-   `collection("posts").where("userId", "==").orderBy("timestamp")`
-   `collectionGroup("comments").where("userId", "==").orderBy("timestamp")`

Firestore, por defecto, **no permite** este tipo de consultas sin un **índice compuesto** predefinido. Cuando la aplicación intenta ejecutar estas consultas, Firestore no devuelve ningún dato y emite un error silencioso en la consola de depuración del desarrollador. Este error contiene un enlace para crear el índice faltante.

### Solución

Para resolver este problema, es necesario crear los índices requeridos en la consola de Firebase.

1.  **Ejecutar la aplicación en modo de depuración.**
2.  **Navegar a la pantalla de perfil** de cualquier usuario.
3.  **Abrir la "Debug Console"** en el IDE (VS Code, Android Studio, etc.).
4.  **Localizar el mensaje de error de Firestore.** Será un mensaje largo que incluye texto como `FAILED_PRECONDITION: The query requires an index...`.
5.  **Hacer clic en el enlace URL** que se proporciona dentro de ese mensaje de error. Este enlace abre la consola de Firebase directamente en la página de creación de índices con todos los campos necesarios ya rellenados.
6.  **Hacer clic en el botón "Crear"** para confirmar la creación del índice.
7.  **Repetir el proceso si es necesario.** Es probable que se necesiten dos índices: uno para la colección `posts` y otro para el `collectionGroup` de `comments`.

Una vez que los índices se hayan construido en Firebase (puede tardar unos minutos), la pantalla de perfil comenzará a mostrar los datos correctamente sin necesidad de realizar más cambios en el código.

