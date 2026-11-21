// Seaglass site: each chapter's phone shows the moment chosen in its list, and an animation starts from its first
// frame when it is chosen or when its chapter comes into view. Without this script, every moment shows its own phone.
(function () {
  "use strict";

  var reduced = window.matchMedia("(prefers-reduced-motion: reduce)");

  function setUp(chapter) {
    var phone = chapter.querySelector(".chapter-stage .phone");
    var screen = phone && phone.querySelector(".screen");
    var moments = Array.prototype.slice.call(chapter.querySelectorAll(".moment"));
    if (!screen || !moments.length)
      return;

    var items = moments.map(function (moment) {
      var picture = moment.querySelector("figure img");
      var still = moment.querySelector("figure source");
      var heading = moment.querySelector("h3");
      var button = document.createElement("button");
      button.type = "button";
      button.textContent = heading.textContent;
      heading.textContent = "";
      heading.appendChild(button);

      var img = document.createElement("img");
      img.alt = picture.alt;
      img.decoding = "async";
      screen.appendChild(img);
      return {
        moment: moment, button: button, img: img,
        shot: picture.getAttribute("src"),
        still: still ? still.getAttribute("srcset") : picture.getAttribute("src"),
        ratio: picture.width / picture.height
      };
    });

    var current = -1;
    var seen = false;

    function play(item) {
      // a new src starts an animated image from its first frame
      item.img.removeAttribute("src");
      item.img.src = reduced.matches ? item.still : item.shot;
    }

    function show(index) {
      var item = items[index];
      current = index;
      items.forEach(function (other, i) {
        other.moment.classList.toggle("active", i === index);
        other.button.setAttribute("aria-pressed", i === index ? "true" : "false");
        other.img.classList.toggle("shown", i === index);
      });
      // a picture of the top of the screen only (the search, above the keyboard) gets a phone cut off below it
      var cut = item.ratio > 0.55;
      phone.classList.toggle("cut", cut);
      screen.style.aspectRatio = cut ? String(item.ratio) : "";
      if (seen)
        play(item);
    }

    items.forEach(function (item, index) {
      item.button.addEventListener("click", function () {
        show(index);
        // on a narrow screen the phone is under the list: bring it into view
        var rect = phone.getBoundingClientRect();
        if (rect.top > window.innerHeight * 0.6)
          phone.scrollIntoView({ behavior: reduced.matches ? "auto" : "smooth", block: "center" });
      });
    });
    show(0);

    // nothing is fetched before the chapter is near; coming back to it starts its animation again
    if (!("IntersectionObserver" in window)) {
      seen = true;
      play(items[current]);
      return;
    }
    new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting && !seen)
          play(items[current]);
        seen = entry.isIntersecting;
      });
    }, { rootMargin: "200px 0px" }).observe(chapter);
  }

  Array.prototype.forEach.call(document.querySelectorAll(".chapter"), setUp);

  // the install command, to paste into the terminal
  Array.prototype.forEach.call(document.querySelectorAll("[data-copy]"), function (button) {
    var source = document.getElementById(button.getAttribute("data-copy"));
    if (!source || !navigator.clipboard)
      return;
    var label = button.textContent;
    button.hidden = false;
    button.addEventListener("click", function () {
      navigator.clipboard.writeText(source.textContent).then(function () {
        button.textContent = "Copied";
        setTimeout(function () { button.textContent = label; }, 2000);
      });
    });
  });
})();
