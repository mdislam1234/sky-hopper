{{flutter_js}}
{{flutter_build_config}}

// Flutter 3.47's generated worker retires legacy caching. Keep that supported
// migration behavior; do not revive the deprecated offline-first worker.
_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}}
  },
  onEntrypointLoaded: async function(engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
    } catch (_) {
      window.skyHopperStartup?.fail();
    }
  }
}).catch(() => window.skyHopperStartup?.fail());

