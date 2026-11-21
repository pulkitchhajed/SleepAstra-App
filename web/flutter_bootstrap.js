{{flutter_js}}
{{flutter_build_config}}

// Eradicate any legacy service workers and cache storage
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then(function(registrations) {
    for (var i = 0; i < registrations.length; i++) {
      registrations[i].unregister();
    }
  });
}
if (window.caches) {
  caches.keys().then(function(names) {
    for (var i = 0; i < names.length; i++) {
      caches.delete(names[i]);
    }
  });
}

_flutter.loader.load({
  serviceWorkerSettings: null
});
