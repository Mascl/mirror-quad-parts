import MuseScore 3.0
import QtQuick 2.9

MuseScore {
  menuPath: qsTr("Plugins.Mirror Quad Parts")
  description: "Swap L/R in stickings & lyrics; swap Drum1↔Drum2, Drum3↔Drum4, Spock1↔Spock2 on drumset staves"
  version: "1.8"
  requiresScore: true

  property var swaps: ({
    text: { "L": "R", "R": "L", "l": "r", "r": "l" },
    pitch: {
      // Spock 2  <->  Spock 1
      89:101, 101:89,
      95:107, 107:95,
      85:97,  97:85,
      93:105, 105:93,
      84:96,  96:84,

      // Drum 4  <->  Drum 3
      41:53,  53:41,
      40:52,  52:40,
      47:59,  59:47,
      37:49,  49:37,
      45:57,  57:45,
      36:48,  48:36,

      // Drum 2  <->  Drum 1
      65:77,  77:65,
      71:83,  83:71,
      61:73,  73:61,
      69:81,  81:69,
      60:72,  72:60
    }
  })

  function swapText(s) {
    if (!s || typeof s !== "string") return s
    return s.replace(/[LRlr]/g, function(c) { return swaps.text[c] || c })
  }

  function swapPercPitch(note) {
    if (!note || typeof note.pitch !== "number") return false
    var to = swaps.pitch[note.pitch]
    if (typeof to === "number") { note.pitch = to; return true }
    return false
  }

  function flipChordAttachments(chord) {
    if (!chord) return
    try {
      if (chord.lyrics) {
        for (var i = 0; i < chord.lyrics.length; i++) {
          var lyr = chord.lyrics[i]
          if (lyr && typeof lyr.text === "string") lyr.text = swapText(lyr.text)
        }
      }
    } catch(_) {}
    try {
      var seg = chord.segment, t = chord.track
      if (seg && seg.elements) {
        for (var j = 0; j < seg.elements.length; j++) {
          var se = seg.elements[j]
          if (se && se.type === Element.STICKING && typeof se.text === "string") {
            if (typeof t === "number" && typeof se.track === "number") {
              if (se.track === t) se.text = swapText(se.text)
            } else se.text = swapText(se.text)
          }
        }
      }
    } catch(_) {}
  }

  function processChord(ch) {
    if (!ch) return false
    var changed = false
    try {
      var ns = ch.notes || []
      for (var i = 0; i < ns.length; i++) changed = swapPercPitch(ns[i]) || changed
    } catch(_) {}
    flipChordAttachments(ch)
    return changed
  }

  function processAny(e) {
    if (!e) return false
    var changed = false
    if (e.type === Element.LYRICS || e.type === Element.STICKING) {
      if (typeof e.text === "string") e.text = swapText(e.text)
    } else if (e.type === Element.NOTE) {
      changed = swapPercPitch(e)
      try { flipChordAttachments(e.parent) } catch(_) {}
    } else if (e.type === Element.CHORD) {
      changed = processChord(e)
    }
    return changed
  }

  function processRangeSelection() {
    var cursor = curScore.newCursor()
    cursor.rewind(1)
    if (!cursor.segment) return false

    var startStaff = cursor.staffIdx
    cursor.rewind(2)
    var endTick = (cursor.tick === 0) ? (curScore.lastSegment.tick + 1) : cursor.tick
    var endStaff = cursor.staffIdx

    var did = false
    for (var staff = startStaff; staff <= endStaff; staff++) {
      for (var voice = 0; voice < 4; voice++) {
        cursor.rewind(1)
        cursor.staffIdx = staff
        cursor.voice = voice
        while (cursor.segment && cursor.tick < endTick) {
          var el = cursor.element
          if (el && el.type === Element.CHORD) did = processChord(el) || did
          cursor.next()
        }
      }
    }
    return did
  }

  onRun: {
    if (!curScore) return
    curScore.startCmd()

    var didWork = false
    var sel = curScore.selection

    if (sel && sel.elements && sel.elements.length > 0) {
      var list = sel.elements
      for (var i = 0; i < list.length; i++) didWork = processAny(list[i]) || didWork
    } else {
      didWork = processRangeSelection()
      if (!didWork) {
        var one = curScore.selectionElement
        if (one) didWork = processAny(one) || didWork
      }
    }

    curScore.endCmd()
  }
}
