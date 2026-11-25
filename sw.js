// عامل خدمة بسيط: يجعل المنسّق يعمل بلا إنترنت بعد أول فتح
var CACHE = "munassiq-v32";
var ASSETS = ["./", "./index.html", "./manifest.webmanifest", "./icon.svg"];

self.addEventListener("install", function(e){
  e.waitUntil(caches.open(CACHE).then(function(c){ return c.addAll(ASSETS); }));
  self.skipWaiting();
});

self.addEventListener("activate", function(e){
  e.waitUntil(
    caches.keys().then(function(keys){
      return Promise.all(keys.map(function(k){
        return k === CACHE ? null : caches.delete(k);
      }));
    })
  );
  self.clients.claim();
});

self.addEventListener("fetch", function(e){
  if (e.request.method !== "GET") return;
  // الصفحة نفسها: الشبكة أولاً حتى يصل كل إصدار جديد فوراً، والذاكرة احتياطاً عند غياب الاتصال
  if (e.request.mode === "navigate"){
    e.respondWith(
      fetch(e.request).then(function(res){
        var copy = res.clone();
        caches.open(CACHE).then(function(c){ c.put("./index.html", copy); });
        return res;
      }).catch(function(){ return caches.match("./index.html"); })
    );
    return;
  }
  e.respondWith(
    caches.match(e.request).then(function(hit){
      return hit || fetch(e.request).then(function(res){
        var copy = res.clone();
        caches.open(CACHE).then(function(c){ c.put(e.request, copy); });
        return res;
      });
    })
  );
});
