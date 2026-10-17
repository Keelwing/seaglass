// Seaglass site: on a wide screen, the phone beside the features shows the feature in view. Each animation starts
// from its first frame when its feature comes into view. Without this script, every feature shows its own phone.
(function () {
  "use strict";

  var stage = document.querySelector(".stage .screen");
  var features = Array.prototype.slice.call(document.querySelectorAll(".feature[data-shot]"));
  if (!stage || !features.length)
    return;

  var reduced = window.matchMedia("(prefers-reduced-motion: reduce)");
  var images = features.map(function (feature, index) {
    var img = document.createElement("img");
    img.alt = "";
    img.decoding = "async";
    img.dataset.index = index;
    stage.appendChild(img);
    return img;
  });

  function sourceOf(feature) {
    return reduced.matches ? feature.dataset.still : feature.dataset.shot;
  }

  var current = -1;
  function show(index) {
    if (index === current)
      return;
    current = index;
    features.forEach(function (feature, i) {
      feature.classList.toggle("active", i === index);
    });
    images.forEach(function (img, i) {
      if (i === index) {
        // a new src starts an animated image from its first frame
        img.removeAttribute("src");
        img.src = sourceOf(features[i]);
      }
      img.classList.toggle("shown", i === index);
    });
    // the next one, ahead of time
    var next = features[index + 1];
    if (next && !images[index + 1].getAttribute("src"))
      images[index + 1].src = sourceOf(next);
  }

  // the feature at the middle of the screen (the nearest one between two)
  function pick() {
    var middle = window.innerHeight / 2;
    var best = 0;
    var bestDistance = Infinity;
    features.forEach(function (feature, index) {
      var rect = feature.getBoundingClientRect();
      var distance = rect.top <= middle && rect.bottom >= middle ? 0
                     : Math.min(Math.abs(rect.top - middle), Math.abs(rect.bottom - middle));
      if (distance < bestDistance) {
        bestDistance = distance;
        best = index;
      }
    });
    show(best);
  }

  window.addEventListener("scroll", pick, { passive: true });
  window.addEventListener("resize", pick);
  pick();
})();
