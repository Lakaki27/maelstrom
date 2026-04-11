## Concepts:
Render images/video via <canvas> — breaks right-click save, breaks <img src> scraping
Tile/scramble the image server-side, reassemble in canvas JS — even if they get the network request, they get puzzle pieces
Signed expiring URLs for the actual media segments (S3-style, or roll your own with a token + TTL in your backend)
Invisible per-viewer watermark (steganography) — if it leaks, you know who leaked it
Detect screenshot shortcuts (limited, but visibilitychange + blur events catch some cases) → pause/black out video
Token-bound sessions: media only streams if the auth token is active, one session at a time



set common screenshot shortcuts to something different

remove the pictures from print version (via css)

cut the images in like 32 stripes and load a blurred version as default and then replace it with the 32 images after they are loaded

maybe stream them like in a video stream

of course use watermarks

write your own image format and write a renderer that shows them in the browser

add some listeners if exists for browser window going inactive and remove the images (taking screenshots with inactive browser window)

try to check user agent strings in the headers

add one time tokens (csrf maybe), generate a one time url for the image using the token, insert that into the image tag

and so on…


 -cut the image into chunks and put them together on the client side. Find a way panorama software can't put them together.

-watermarks everywhere. Especially in parts of images with many details, so it's harder to remove

-own image format (or at least make a mess with existing ones)

-maybe encrypt the images on the server and decrypt on the client. That way, youh never transfer them directly as image, which complicates usage of direct web requests (scrapers need to read the key from the code). Also, depending on how much computing power you want to waste on this, use different keys for each request

-remove images from prints with css

-don't use standard image or picture tags. Most tools specialise on them. Use canvas (js) or background images (css). I think I read about a css method that can use canvas content as css background. Not sure if it exists, but if it does, maybe it is an option.

-try to disable screenshots. Intercept common shortcuts

-disable selection and drag and drop (using css and js)

-disable right clicking

-disable ctrl s (save page) and ctrl c (copy)

-disable focus for the image (HTML, css, js)

-look into drm (I don't know a lot about it, but it could help)

-be as non-standard as possible

-maybe even use broken html that is fixed by the browser

-add invisible watermarks so you can prove that the images are yours

-try to detect bots (e.g. Captcha, User agent)

-try to only show the image when the tab is active

-add the corresponding meta tags 

 You might look into https://en.wikipedia.org/wiki/High-bandwidth_Digital_Content_Protection an attempt to encrypt traffic between all connections, even from the video card to the monitor.

This would prevent screenshotting or any other method that uses what's on the computer, since the computer would only have a scrambled copy of the image

To prevent people from simply taking pictures of the monitor, you could:

    Slightly vary the frequency of the monitor constantly in such a way that people can't notice, but that will baffle cameras the way old CRTs did unintentionally (the black bars, still or rolling, that occur when you film old TVs and sometimes even newer monitors)

    Cameras see colors slightly different than the human eye. You might be able to exploit this to create images people can see but cameras can't

    Vary the brightness, contrast, or other features of the image constantly to exploit differences in how cameras and human eyes work

Of course, all of these would require people buy and use these special monitors, and that the image would not be visible on non-compliant monitors 

Access Control (Server-Side)

One-time tokens — generate a UUID per share link; invalidate it the moment the first request hits your server
Signed expiring URLs — token encodes expiry + signature; server rejects replays even if copied
IP binding — tie the token to the requester's IP at generation time; reject if IP changes on access
Device fingerprinting — bind tokens to browser fingerprint (user agent, screen res, timezone, etc.)
Session binding — require auth, bind the view to a specific session ID
View counter in DB — increment atomically on each request; hard-reject anything > 1
Token rotation — even if someone intercepts a URL mid-flight, the token is already burned

Image Delivery Tricks

Never serve the raw file — stream bytes through your server, never expose S3/CDN URL directly
Serve as canvas-rendered fragments — split image into tiles, reassemble in JS on a <canvas>; no single downloadable file exists
Tile shuffling — serve tiles in scrambled order, reorder client-side; makes partial captures useless
Single-pixel streaming — render pixel rows progressively via JS, never a complete image in DOM at once
WebGL rendering — decode and render entirely in a WebGL context; harder to intercept than a plain <img> tag
Encrypted payload — send AES-encrypted image bytes, decrypt key delivered separately (second request, also burned)
Server-side rendering to video stream — stream the image as a short video (MJPEG/HLS); no static file

Anti-Screenshot / Visual Deterrents

CSS user-select: none + pointer-events: none — minor deterrent
Invisible watermark — steganographically embed recipient ID in the image pixels; you can trace leaks even if screenshots happen
Visible personalized watermark — overlay the viewer's name/email/IP/timestamp directly on the image
Dynamic noise overlay — subtly animate pixel noise on the canvas so screenshots capture a degraded version
Flicker/strobe rendering — rapidly alternate between the real image and a blank/noise frame; screenshots land on the wrong frame ~50% of the time
Color channel splitting — display image across overlapping semi-transparent layers with CSS blend modes; screenshot captures the blend, not individual layers (though the blend looks correct to human eyes)
Periodic CSS transform scramble — briefly transform/distort the image at random intervals
Right-click / context menu blocking — preventDefault on contextmenu event (trivial to bypass but raises the floor)
Drag prevention — block dragstart events on image elements
Dev tools detection — detect open DevTools (window size delta tricks, debugger timing attacks) and hide/destroy the image if detected
Print blocking — @media print { display: none } to prevent print-to-PDF captures
Window blur detection — destroy/hide image if the window loses focus (deters Alt+Tab → Snipping Tool flows)
Inactivity timeout — auto-destroy the view after N seconds of no mouse movement

Client-Side Obfuscation

No <img> tag — render exclusively to <canvas>; right-click save-as doesn't work
Disable long-press on mobile — CSS touch-action + JS to block the native image save sheet
CSS pointer-events: none on canvas — prevents touch-hold save on iOS
Obfuscated JS — minify/obfuscate the decryption and rendering logic so it's harder to reverse
WASM renderer — move the decryption/rendering pipeline into a WebAssembly module; much harder to inspect
Service Worker interception — route image bytes through a service worker that strips headers and prevents caching
Disable browser cache — Cache-Control: no-store, no-cache, Pragma: no-cache on every response
Delete from DOM immediately after paint — after canvas draw, null out the source data in JS

UX / Social Engineering Layer

Countdown timer — show image for only 5–10 seconds then fade/destroy
Require active interaction — only show image while mouse button is held down (hard to screenshot one-handed)
"You are being watched" notice — visible message that the view is logged with IP/timestamp; psychological deterrent
Legal notice on access — make user click-through a warning that redistribution is prohibited

Infrastructure / Logging

Log every access — IP, user agent, timestamp, referrer; useful for abuse investigation
Alert on re-access attempts — notify the sender if someone tries to reuse a burned token
Geolocation anomaly detection — flag if recipient IP is in an unexpected country
Rate limiting on the token endpoint — prevent brute-force guessing of token space

## My ideas:
display code on the picture so i can know who accesses it and when, register in DB the source of whoever opens which picture
blink picture at around 60ms intervals

## Future improvements:
video ?
