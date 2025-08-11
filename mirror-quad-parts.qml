import MuseScore 3.0
import QtQuick 2.9

MuseScore {
  menuPath: qsTr("Plugins.Mirror Quad Parts")
  description: "Swap L/R in stickings and lyrics for selected items"
  version: "1.3"
  requiresScore: true

  function swapRL(s) {
    if (!s || typeof s !== "string") return s
    return s.replace(/[LRlr]/g, function(c) {
      return c === "L" ? "R"
           : c === "R" ? "L"
           : c === "l" ? "r"
           : c === "r" ? "l"
           : c
    })
  }

  onRun: {
    if (!curScore || !curScore.selection) return

    curScore.startCmd()

    // Pass 1: operate on selected Lyrics and Sticking elements directly
    var els = curScore.selection.elements
    for (var i = 0; i < els.length; i++) {
      var e = els[i]
      // Lyrics and Sticking are text-like elements with a .text property
      if (e.type === Element.LYRICS || e.type === Element.STICKING) {
        e.text = swapRL(e.text)
      }
    }

    // Optional Pass 2 (best effort): if user selected notes but not their attached text,
    // also walk selected notes and try to flip any attached lyric/sticking text we can reach.
    for (var j = 0; j < els.length; j++) {
      var n = els[j]
      if (n.type === Element.NOTE) {
        // Try attached lyrics via parent chord (if exposed)
        try {
          var chord = n.parent // parent Chord
          if (chord && chord.lyrics) {
            for (var li = 0; li < chord.lyrics.length; li++) {
              if (chord.lyrics[li]) chord.lyrics[li].text = swapRL(chord.lyrics[li].text)
            }
          }
        } catch (_) {}

        // Try attached sticking if accessible from the same segment/track
        try {
          var seg = n.segment
          if (seg) {
            var elAtTrack = seg.elementAt(n.track) // may return the chord/rest
            // scan other elements on this segment; API availability can vary,
            // so guard with try/catch and check for .text before writing
            var segEls = seg.elements || []
            for (var k = 0; k < segEls.length; k++) {
              var se = segEls[k]
              if (se && (se.type === Element.STICKING) && typeof se.text === "string") {
                se.text = swapRL(se.text)
              }
            }
          }
        } catch (_) {}
      }
    }

    curScore.endCmd()
  }
}
