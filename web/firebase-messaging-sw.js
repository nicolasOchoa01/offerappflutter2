// Scripts de Firebase
importScripts('https://www.gstatic.com/firebasejs/10.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.0.0/firebase-messaging-compat.js');

// Configuración de la aplicación Firebase
// Reemplaza esto con tu objeto de configuración de Firebase (lo encuentras en tu Consola de Firebase -> Configuración del proyecto -> Aplicaciones Web)
const firebaseConfig = {
    apiKey: "AIzaSyAM4NwtnSUnRW7i3wMNnFy_48uMov7RxeU",
    authDomain: "offerapp2.firebaseapp.com",
    projectId: "offerapp2",
    storageBucket: "offerapp2.firebasestorage.app",
    messagingSenderId: "34389981525",
    appId: "1:34389981525:web:268fa0d5a38a9ccb8197dc"
};

// Inicializar la aplicación Firebase
const app = firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging(app);

// Manejar los mensajes en background/closed state
messaging.onBackgroundMessage((payload) => {
    console.log('[firebase-messaging-sw.js] Mensaje recibido en background: ', payload);

    const notificationTitle = payload.data.custom_title || 'Nuevo Mensaje';
    const notificationOptions = {
        body: payload.data.custom_body || 'Tienes un nuevo post',
        icon: '/favicon.png' // Asegúrate de tener un icono válido aquí
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});