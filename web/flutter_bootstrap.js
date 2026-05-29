{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerUrl: 'sw.js',
  },
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    
    // Smoothly fade out the splash screen
    const loader = document.getElementById("loading-splash");
    if (loader) {
      loader.classList.add("fade-out");
      // Remove it from the DOM entirely after the 400ms CSS transition finishes
      setTimeout(() => {
        loader.remove();
      }, 400);
    }
    
    await appRunner.runApp();
  }
});
