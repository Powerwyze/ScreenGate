importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Initialize Firebase in the service worker
// TODO: Replace with your Firebase config from Firebase Console
firebase.initializeApp({
  apiKey: "AIzaSyCZ46XJGpoIVhaqBVdDc5FRnyNsniqWD9g",
  authDomain: "jtzy4fc5gf6kkrtwvtla28o7qboszo.firebaseapp.com",
  projectId: "jtzy4fc5gf6kkrtwvtla28o7qboszo",
  storageBucket: "jtzy4fc5gf6kkrtwvtla28o7qboszo.firebasestorage.app",
  messagingSenderId: "665559036926",
  appId: "1:665559036926:web:4d066886cdae892027c6af"
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification?.title || 'ScreenGate';
  const notificationOptions = {
    body: payload.notification?.body || 'You have a new notification',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification clicks
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] Notification click received.');
  
  event.notification.close();
  
  // Open or focus the app
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url === '/' && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});
