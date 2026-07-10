// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, uri_does_not_exist, undefined_function, depend_on_referenced_packages

import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import '../../models/composite_draft.dart';

class WebRecorder {
  static bool get isSupported => true;

  static String createBlobUrl(Uint8List bytes) {
    final blob = html.Blob([bytes], 'image/png');
    return html.Url.createObjectUrlFromBlob(blob);
  }

  static Future<void> startRecording({
    required List<String> pageImageUrls,
    required int initialPageIndex,
  }) async {
    _ensureJsRecorderInjected();

    final recorder = js_util.getProperty(html.window, 'storybridgeRecorder');
    final promise = js_util.callMethod(recorder, 'start', [
      pageImageUrls,
      initialPageIndex,
    ]);
    await js_util.promiseToFuture(promise);
  }

  static void updatePageIndex(int index) {
    _ensureJsRecorderInjected();
    final hasRecorder = js_util.hasProperty(html.window, 'storybridgeRecorder');
    if (hasRecorder) {
      final recorder = js_util.getProperty(html.window, 'storybridgeRecorder');
      js_util.callMethod(recorder, 'updateIndex', [index]);
    }
    final hasBookRecorder = js_util.hasProperty(html.window, 'storybridgeBookRecorder');
    if (hasBookRecorder) {
      final bookRecorder = js_util.getProperty(html.window, 'storybridgeBookRecorder');
      js_util.callMethod(bookRecorder, 'updateIndex', [index]);
    }
  }

  static Future<String?> stopRecording() async {
    _ensureJsRecorderInjected();
    final hasRecorder = js_util.hasProperty(html.window, 'storybridgeRecorder');
    if (hasRecorder) {
      final recorder = js_util.getProperty(html.window, 'storybridgeRecorder');
      final promise = js_util.callMethod(recorder, 'stop', []);
      final result = await js_util.promiseToFuture(promise);
      return result as String?;
    }
    return null;
  }

  static Future<void> startBookTrack({
    required int width,
    required int height,
    required List<String> pageImageUrls,
    required int initialPageIndex,
  }) async {
    _ensureJsRecorderInjected();
    final bookRecorder = js_util.getProperty(html.window, 'storybridgeBookRecorder');
    js_util.callMethod(bookRecorder, 'start', [width, height, pageImageUrls, initialPageIndex]);
  }

  static void appendBookFrame(Uint8List bytes, int width, int height) {
    _ensureJsRecorderInjected();
    final bookRecorder = js_util.getProperty(html.window, 'storybridgeBookRecorder');
    js_util.callMethod(bookRecorder, 'appendFrame', [bytes, width, height]);
  }

  static Future<String?> stopBookTrack() async {
    _ensureJsRecorderInjected();
    final bookRecorder = js_util.getProperty(html.window, 'storybridgeBookRecorder');
    final promise = js_util.callMethod(bookRecorder, 'stop', []);
    final result = await js_util.promiseToFuture(promise);
    return result as String?;
  }

  static Future<String?> compositeVideo({
    required CompositeDraft draft,
    required bool isPortrait,
  }) async {
    _ensureJsRecorderInjected();
    final bookVideoPath = draft.bookVideoPath;
    final faceVideoPath = draft.rawFaceVideoPath;
    final modeStr = draft.mode.name; // e.g. "faceLed", "bookLed", etc.
    final offsetMs = draft.timestampOffsetMs;
    final durationSec = draft.durationSeconds;

    final compositor = js_util.getProperty(html.window, 'storybridgeCompositor');
    final promise = js_util.callMethod(compositor, 'composite', [
      bookVideoPath ?? '',
      faceVideoPath ?? '',
      modeStr,
      offsetMs,
      isPortrait,
      durationSec,
    ]);
    final result = await js_util.promiseToFuture(promise);
    return result as String?;
  }

  static void _ensureJsRecorderInjected() {
    // If the objects are already set, don't re-inject to avoid resetting ongoing state
    if (js_util.hasProperty(html.window, 'storybridgeRecorder') &&
        js_util.hasProperty(html.window, 'storybridgeBookRecorder') &&
        js_util.hasProperty(html.window, 'storybridgeCompositor')) {
      return;
    }

    const scriptContent = r'''
window.storybridgeRecorder = {
  recording: false,
  mediaRecorder: null,
  recordedChunks: [],
  currentPageIndex: 0,
  cameraStream: null,

  start(urls, initialIndex) {
    return new Promise(async (resolve) => {
      try {
        this.recordedChunks = [];
        this.currentPageIndex = initialIndex;
        this.cameraStream = null;

        // Acquire camera + mic
        try {
          this.cameraStream = await navigator.mediaDevices.getUserMedia({
            video: { facingMode: 'user', width: { ideal: 640 }, height: { ideal: 480 } },
            audio: true
          });
          console.log('[recorder] camera+mic acquired');
        } catch (videoErr) {
          console.warn('[recorder] camera+mic failed, trying audio only:', videoErr);
          try {
            this.cameraStream = await navigator.mediaDevices.getUserMedia({ audio: true });
          } catch (audioErr) {
            console.warn('[recorder] mic-only also failed:', audioErr);
          }
        }

        if (!this.cameraStream) {
          this.recording = false;
          resolve();
          return;
        }

        this.recording = true;

        let mimeType = 'video/webm;codecs=vp8,opus';
        if (!MediaRecorder.isTypeSupported(mimeType)) {
          mimeType = 'video/webm';
          if (!MediaRecorder.isTypeSupported(mimeType)) {
            mimeType = 'video/mp4';
            if (!MediaRecorder.isTypeSupported(mimeType)) mimeType = '';
          }
        }

        const mr = new MediaRecorder(this.cameraStream, mimeType ? { mimeType } : {});
        mr.ondataavailable = (e) => {
          if (e.data && e.data.size > 0) {
            this.recordedChunks.push(e.data);
          }
        };
        mr.start(100);
        this.mediaRecorder = mr;
        console.log('[recorder] started raw camera recording, mimeType=' + (mimeType || 'default'));
        resolve();
      } catch (err) {
        console.error('[recorder] start caught error:', err);
        this.recording = false;
        resolve();
      }
    });
  },

  updateIndex(index) {
    this.currentPageIndex = index;
  },

  stop() {
    return new Promise((resolve) => {
      let resolved = false;
      const done = (val) => { if (!resolved) { resolved = true; resolve(val); } };

      setTimeout(() => {
        console.warn('[recorder] stop timed out');
        done(null);
      }, 5000);

      if (this.cameraStream) {
        this.cameraStream.getTracks().forEach(t => t.stop());
        this.cameraStream = null;
      }

      if (!this.recording && !this.mediaRecorder) {
        done(null);
        return;
      }

      this.recording = false;

      if (!this.mediaRecorder) {
        done(null);
        return;
      }

      this.mediaRecorder.onstop = () => {
        try {
          const mimeType = this.mediaRecorder.mimeType || 'video/webm';
          const blob = new Blob(this.recordedChunks, { type: mimeType });
          const blobUrl = URL.createObjectURL(blob);
          console.log('[recorder] stopped camera recording. size=' + blob.size);
          done(blobUrl);
        } catch (e) {
          console.error('[recorder] stop callback error:', e);
          done(null);
        }
      };

      try {
        this.mediaRecorder.stop();
      } catch (e) {
        console.error('[recorder] mediaRecorder.stop failed:', e);
        done(null);
      }
    });
  }
};

window.storybridgeBookRecorder = {
  recording: false,
  canvas: null,
  ctx: null,
  mediaRecorder: null,
  recordedChunks: [],
  urls: [],
  currentPageIndex: 0,
  images: [],
  animationFrameId: null,

  start(width, height, urls, initialIndex) {
    this.recordedChunks = [];
    this.urls = urls || [];
    this.currentPageIndex = initialIndex || 0;
    this.images = [];
    this.recording = true;

    this.canvas = document.createElement('canvas');
    this.canvas.width = width;
    this.canvas.height = height;
    this.ctx = this.canvas.getContext('2d');

    // Preload all page images in JS
    const loadPromises = this.urls.map((url, index) => {
      return new Promise((resolve) => {
        if (!url) {
          resolve(null);
          return;
        }
        const img = new Image();
        // Skip CORS anonymous header for local blob or data URLs to avoid browser security blocking.
        if (!url.startsWith('blob:') && !url.startsWith('data:')) {
          img.crossOrigin = 'anonymous';
        }
        img.src = url;
        img.onload = () => {
          this.images[index] = img;
          resolve(img);
        };
        img.onerror = () => {
          console.warn('[bookRecorder] failed to load image index ' + index);
          resolve(null);
        };
      });
    });

    Promise.all(loadPromises).then(() => {
      console.log('[bookRecorder] all images preloaded:', this.images.length);
    });

    const stream = this.canvas.captureStream(30);

    let mimeType = 'video/webm;codecs=vp8';
    if (!MediaRecorder.isTypeSupported(mimeType)) {
      mimeType = 'video/webm';
      if (!MediaRecorder.isTypeSupported(mimeType)) {
        mimeType = 'video/mp4';
        if (!MediaRecorder.isTypeSupported(mimeType)) mimeType = '';
      }
    }

    this.mediaRecorder = new MediaRecorder(stream, mimeType ? { mimeType } : {});
    this.mediaRecorder.ondataavailable = (e) => {
      if (e.data && e.data.size > 0) this.recordedChunks.push(e.data);
    };
    this.mediaRecorder.start(100);
    console.log('[bookRecorder] started, size=' + width + 'x' + height + ', mimeType=' + mimeType);

    const draw = () => {
      if (!this.recording) return;

      this.ctx.fillStyle = '#FBFBFB';
      this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

      const img = this.images[this.currentPageIndex];
      if (img) {
        const scale = Math.min(this.canvas.width / img.width, this.canvas.height / img.height);
        const drawW = img.width * scale;
        const drawH = img.height * scale;
        const dx = (this.canvas.width - drawW) / 2;
        const dy = (this.canvas.height - drawH) / 2;
        this.ctx.drawImage(img, dx, dy, drawW, drawH);
      } else {
        this.ctx.fillStyle = '#666666';
        this.ctx.font = '24px sans-serif';
        this.ctx.textAlign = 'center';
        this.ctx.fillText('Loading Page ' + (this.currentPageIndex + 1) + '...', this.canvas.width / 2, this.canvas.height / 2);
      }

      // Use recursive setTimeout instead of requestAnimationFrame so background/unattached canvas continues drawing
      this.animationFrameId = setTimeout(draw, 33);
    };
    draw();
  },

  updateIndex(index) {
    this.currentPageIndex = index;
    console.log('[bookRecorder] index updated to ' + index);
  },

  appendFrame(bytes, width, height) {
    // No-op on web: drawing is handled internally
  },

  stop() {
    return new Promise((resolve) => {
      if (!this.recording || !this.mediaRecorder) {
        resolve(null);
        return;
      }
      this.recording = false;
      if (this.animationFrameId) {
        clearTimeout(this.animationFrameId);
        this.animationFrameId = null;
      }

      this.mediaRecorder.onstop = () => {
        try {
          const mimeType = this.mediaRecorder.mimeType || 'video/webm';
          const blob = new Blob(this.recordedChunks, { type: mimeType });
          const blobUrl = URL.createObjectURL(blob);
          console.log('[bookRecorder] stopped. size=' + blob.size);
          resolve(blobUrl);
        } catch (e) {
          console.error('[bookRecorder] stop error:', e);
          resolve(null);
        }
      };

      try {
        this.mediaRecorder.stop();
      } catch (e) {
        console.error('[bookRecorder] stop failed:', e);
        resolve(null);
      }
    });
  }
};

window.storybridgeCompositor = {
  composite(bookVideoUrl, cameraVideoUrl, modeStr, timestampOffsetMs, isPortrait, durationSec) {
    return new Promise(async (resolve) => {
      try {
        console.log('[compositor] Starting composition:', { bookVideoUrl, cameraVideoUrl, modeStr, timestampOffsetMs, isPortrait, durationSec });

        const canvas = document.createElement('canvas');
        const outW = isPortrait ? 720 : 1280;
        const outH = isPortrait ? 1280 : 720;
        canvas.width = outW;
        canvas.height = outH;
        const ctx = canvas.getContext('2d');

        const bookVideo = document.createElement('video');
        bookVideo.muted = true;
        bookVideo.setAttribute('muted', '1');
        bookVideo.setAttribute('playsinline', '1');
        bookVideo.setAttribute('autoplay', '1');

        const cameraVideo = document.createElement('video');
        // Unmute cameraVideo so Web Audio API createMediaElementSource captures audio instead of absolute silence.
        cameraVideo.muted = false;
        cameraVideo.setAttribute('playsinline', '1');
        cameraVideo.setAttribute('autoplay', '1');

        // Hidden style to attach them to the DOM for proper decoding and streaming
        const hideVideo = (v) => {
          v.style.position = 'absolute';
          v.style.width = '1px';
          v.style.height = '1px';
          v.style.left = '-9999px';
          v.style.top = '-9999px';
          v.style.opacity = '0';
          v.style.pointerEvents = 'none';
          document.body.appendChild(v);
        };
        hideVideo(bookVideo);
        hideVideo(cameraVideo);

        let hasCamera = !!cameraVideoUrl && modeStr !== 'audioOnly';

        // Create and resume the AudioContext NOW — before any async awaits —
        // so we are still inside the user-gesture call stack on iOS Safari.
        let audioCtx = null;
        let dest = null;
        let audioTracks = [];

        if (hasCamera) {
          try {
            audioCtx = new (window.AudioContext || window.webkitAudioContext)();
            if (audioCtx.state === 'suspended') {
              audioCtx.resume();
            }
          } catch (audioInitErr) {
            console.warn('[compositor] AudioContext init failed:', audioInitErr);
            audioCtx = null;
          }
        }

        const loadVideo = (video, url) => {
          return new Promise((res) => {
            video.src = url;
            video.onloadedmetadata = () => res(true);
            video.onerror = () => res(false);
            setTimeout(() => res(false), 5000);
          });
        };

        const loadPromises = [];
        if (bookVideoUrl) {
          loadPromises.push(loadVideo(bookVideo, bookVideoUrl));
        }
        if (hasCamera && cameraVideoUrl) {
          loadPromises.push(loadVideo(cameraVideo, cameraVideoUrl));
        }

        if (loadPromises.length > 0) {
          await Promise.all(loadPromises);
        }
        console.log('[compositor] Videos loaded metadata successfully');

        // Wire up the audio graph after videos are ready.
        if (hasCamera && cameraVideoUrl && audioCtx) {
          try {
            const source = audioCtx.createMediaElementSource(cameraVideo);
            dest = audioCtx.createMediaStreamDestination();
            source.connect(dest);
            
            // Connect to speakers with 0 gain to prevent Chrome from pausing the audio decode
            const gainNode = audioCtx.createGain();
            gainNode.gain.value = 0;
            source.connect(gainNode);
            gainNode.connect(audioCtx.destination);

            audioTracks = dest.stream.getAudioTracks();
            console.log('[compositor] Extracted camera audio tracks:', audioTracks.length);
          } catch (audioErr) {
            console.warn('[compositor] AudioContext wiring failed:', audioErr);
            if (cameraVideo.captureStream) {
              const stream = cameraVideo.captureStream();
              audioTracks = stream.getAudioTracks();
            }
          }
        }

        if (modeStr === 'audioOnly') {
          if (hasCamera && cameraVideoUrl && audioTracks.length > 0) {
            const audioOnlyRecorder = new MediaRecorder(new MediaStream(audioTracks), { mimeType: 'audio/webm' });
            const audioChunks = [];
            audioOnlyRecorder.ondataavailable = (e) => {
              if (e.data && e.data.size > 0) audioChunks.push(e.data);
            };
            audioOnlyRecorder.onstop = () => {
              const blob = new Blob(audioChunks, { type: 'audio/webm' });
              resolve(URL.createObjectURL(blob));
            };
            audioOnlyRecorder.start(100);
            
            cameraVideo.play().catch(err => {
              console.warn('cameraVideo.play() audioOnly failed, trying muted:', err);
              cameraVideo.muted = true;
              cameraVideo.play().catch(e => console.error('cameraVideo.play() muted failed:', e));
            });
            cameraVideo.onended = () => {
              audioOnlyRecorder.stop();
            };
            const duration = durationSec || 30;
            setTimeout(() => {
              if (audioOnlyRecorder.state !== 'inactive') audioOnlyRecorder.stop();
            }, duration * 1000 + 2000);
            return;
          } else {
            resolve(cameraVideoUrl || bookVideoUrl);
            return;
          }
        }

        const canvasStream = canvas.captureStream(30);
        const recordTracks = [...canvasStream.getVideoTracks()];
        audioTracks.forEach(t => recordTracks.push(t));

        const recordStream = new MediaStream(recordTracks);

        let mimeType = audioTracks.length > 0 ? 'video/webm;codecs=vp8,opus' : 'video/webm;codecs=vp8';
        if (!MediaRecorder.isTypeSupported(mimeType)) {
          mimeType = 'video/webm';
          if (!MediaRecorder.isTypeSupported(mimeType)) {
            mimeType = 'video/mp4';
            if (!MediaRecorder.isTypeSupported(mimeType)) mimeType = '';
          }
        }

        const recordedChunks = [];
        const mediaRecorder = new MediaRecorder(recordStream, mimeType ? { mimeType } : {});
        mediaRecorder.ondataavailable = (e) => {
          if (e.data && e.data.size > 0) recordedChunks.push(e.data);
        };

        let compositionActive = true;
        let animationId = null;
        let compositionTimer = null;

        const stopComposition = () => {
          if (!compositionActive) return;
          compositionActive = false;

          if (compositionTimer) {
            clearTimeout(compositionTimer);
            compositionTimer = null;
          }

          if (animationId) {
            clearTimeout(animationId);
            animationId = null;
          }

          try { bookVideo.pause(); bookVideo.remove(); } catch (_) {}
          try { cameraVideo.pause(); cameraVideo.remove(); } catch (_) {}

          mediaRecorder.onstop = () => {
            try {
              const outMime = mediaRecorder.mimeType || 'video/webm';
              const blob = new Blob(recordedChunks, { type: outMime });
              const blobUrl = URL.createObjectURL(blob);
              console.log('[compositor] Finished composition. Blob size:', blob.size);

              recordStream.getTracks().forEach(t => t.stop());
              if (dest && dest.stream) {
                dest.stream.getTracks().forEach(t => t.stop());
              }
              if (audioCtx) {
                audioCtx.close();
              }

              resolve(blobUrl);
            } catch (err) {
              console.error('[compositor] Error creating final blob:', err);
              resolve(null);
            }
          };

          try {
            mediaRecorder.stop();
          } catch (e) {
            console.error('[compositor] Error stopping mediaRecorder:', e);
            resolve(null);
          }
        };

        const drawFrame = () => {
          if (!compositionActive) return;

          if (bookVideoUrl && bookVideo.currentTime >= duration) {
            console.log('[compositor] currentTime reached duration limit:', bookVideo.currentTime);
            stopComposition();
            return;
          }

          ctx.fillStyle = '#000000';
          ctx.fillRect(0, 0, outW, outH);

          if (modeStr === 'bookOnly') {
            if (bookVideoUrl) ctx.drawImage(bookVideo, 0, 0, outW, outH);
          } else if (modeStr === 'faceLed') {
            if (hasCamera && cameraVideoUrl) {
              drawCover(ctx, cameraVideo, 0, 0, outW, outH);
            } else {
              ctx.fillStyle = '#1e1e1e';
              ctx.fillRect(0, 0, outW, outH);
            }
            if (bookVideoUrl) {
              const pipW = Math.round(outW / 3.5);
              const pipH = Math.round(pipW * 1.77);
              const pipX = outW - pipW - 16;
              const pipY = 16;
              drawFit(ctx, bookVideo, pipX, pipY, pipW, pipH);
            }
          } else if (modeStr === 'bookLed') {
            if (bookVideoUrl) drawFit(ctx, bookVideo, 0, 0, outW, outH);
            if (hasCamera && cameraVideoUrl) {
              const pipW = Math.round(outW / 3.5);
              const pipH = Math.round(pipW * 1.33);
              const pipX = outW - pipW - 16;
              const pipY = 16;
              drawCover(ctx, cameraVideo, pipX, pipY, pipW, pipH, true);
            }
          } else if (modeStr === 'splitView') {
            if (isPortrait) {
              const halfH = Math.round(outH / 2);
              if (bookVideoUrl) drawFit(ctx, bookVideo, 0, 0, outW, halfH);
              if (hasCamera && cameraVideoUrl) {
                drawCover(ctx, cameraVideo, 0, halfH, outW, halfH, true);
              } else {
                ctx.fillStyle = '#1e1e1e';
                ctx.fillRect(0, halfH, outW, halfH);
              }
            } else {
              const halfW = Math.round(outW / 2);
              if (bookVideoUrl) drawFit(ctx, bookVideo, 0, 0, halfW, outH);
              if (hasCamera && cameraVideoUrl) {
                drawCover(ctx, cameraVideo, halfW, 0, halfW, outH, true);
              } else {
                ctx.fillStyle = '#1e1e1e';
                ctx.fillRect(halfW, 0, halfW, outH);
              }
            }
          }

          // Use setTimeout instead of requestAnimationFrame so canvas draws correctly even in background/hidden tabs
          animationId = setTimeout(drawFrame, 33);
        };

        function drawFit(c, img, x, y, w, h) {
          try {
            const imgW = img.videoWidth || w;
            const imgH = img.videoHeight || h;
            const scale = Math.min(w / imgW, h / imgH);
            const drawW = imgW * scale;
            const drawH = imgH * scale;
            const dx = x + (w - drawW) / 2;
            const dy = y + (h - drawH) / 2;
            c.drawImage(img, dx, dy, drawW, drawH);
          } catch (_) {}
        }

        function drawCover(c, img, x, y, w, h, mirror = false) {
          try {
            const imgW = img.videoWidth || w;
            const imgH = img.videoHeight || h;
            const scale = Math.max(w / imgW, h / imgH);
            const drawW = imgW * scale;
            const drawH = imgH * scale;
            const dx = x + (w - drawW) / 2;
            const dy = y + (h - drawH) / 2;

            c.save();
            c.beginPath();
            c.rect(x, y, w, h);
            c.clip();

            if (mirror) {
              c.translate(x + w, y);
              c.scale(-1, 1);
              c.drawImage(img, (w - drawW) / 2, (h - drawH) / 2, drawW, drawH);
            } else {
              c.drawImage(img, dx, dy, drawW, drawH);
            }
            c.restore();
          } catch (_) {}
        }

        mediaRecorder.start(100);

        if (bookVideoUrl) {
          bookVideo.onended = () => {
            console.log('[compositor] Book video ended');
            stopComposition();
          };
        }

        const duration = durationSec || (bookVideoUrl ? bookVideo.duration : 0) || 30;
        console.log('[compositor] Duration limit set to:', duration);
        compositionTimer = setTimeout(stopComposition, duration * 1000 + 500);

        const offsetSec = timestampOffsetMs / 1000.0;
        if (hasCamera && cameraVideoUrl) {
          if (bookVideoUrl) {
            if (offsetSec > 0) {
              bookVideo.play().catch(err => {
                console.warn('bookVideo.play() failed, trying muted:', err);
                bookVideo.muted = true;
                bookVideo.play().catch(e => console.error('bookVideo.play() muted retry failed:', e));
              });
              setTimeout(() => {
                if (compositionActive) {
                  cameraVideo.play().catch(err => {
                    console.warn('cameraVideo.play() failed, trying muted:', err);
                    cameraVideo.muted = true;
                    cameraVideo.play().catch(e => console.error('cameraVideo.play() muted retry failed:', e));
                  });
                }
              }, timestampOffsetMs);
            } else if (offsetSec < 0) {
              cameraVideo.play().catch(err => {
                console.warn('cameraVideo.play() failed, trying muted:', err);
                cameraVideo.muted = true;
                cameraVideo.play().catch(e => console.error('cameraVideo.play() muted retry failed:', e));
              });
              setTimeout(() => {
                if (compositionActive) {
                  bookVideo.play().catch(err => {
                    console.warn('bookVideo.play() failed, trying muted:', err);
                    bookVideo.muted = true;
                    bookVideo.play().catch(e => console.error('bookVideo.play() muted retry failed:', e));
                  });
                }
              }, -timestampOffsetMs);
            } else {
              bookVideo.play().catch(err => {
                console.warn('bookVideo.play() failed, trying muted:', err);
                bookVideo.muted = true;
                bookVideo.play().catch(e => console.error('bookVideo.play() muted retry failed:', e));
              });
              cameraVideo.play().catch(err => {
                console.warn('cameraVideo.play() failed, trying muted:', err);
                cameraVideo.muted = true;
                cameraVideo.play().catch(e => console.error('cameraVideo.play() muted retry failed:', e));
              });
            }
          } else {
            cameraVideo.play().catch(err => {
              console.warn('cameraVideo.play() failed, trying muted:', err);
              cameraVideo.muted = true;
              cameraVideo.play().catch(e => console.error('cameraVideo.play() muted retry failed:', e));
            });
          }
        } else if (bookVideoUrl) {
          bookVideo.play().catch(err => {
            console.warn('bookVideo.play() failed, trying muted:', err);
            bookVideo.muted = true;
            bookVideo.play().catch(e => console.error('bookVideo.play() muted retry failed:', e));
          });
        }

        drawFrame();

      } catch (err) {
        console.error('[compositor] Fatal error:', err);
        resolve(null);
      }
    });
  }
};
    ''';

    final script = html.ScriptElement()..text = scriptContent;
    html.document.head!.append(script);
  }

  static double getCompositionProgress() {
    try {
      final jsProgress = js_util.getProperty(html.window, 'storybridgeCompositionProgress');
      if (jsProgress != null) {
        return (jsProgress as num).toDouble();
      }
    } catch (_) {}
    return 0.0;
  }

  static void setCompositionProgress(double value) {
    try {
      js_util.setProperty(html.window, 'storybridgeCompositionProgress', value);
    } catch (_) {}
  }
}
