{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  // Force the full (non-Chromium) CanvasKit variant so images are decoded
  // via Skia's pure-software codec rather than Chrome's hardware ImageDecoder
  // API. The Chromium variant uploads decoded frames as GPU textures which
  // become inaccessible when CanvasKit falls back to CPU rendering (webGL=-1),
  // causing images to appear as blank white rectangles.
  config: {
    canvasKitVariant: "full",
  },
});
