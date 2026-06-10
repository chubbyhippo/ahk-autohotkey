; =============================================================================
;  wins.ahk — AutoHotkey v2 port of wins.kbd (kanata)
;  urob-style "timerless" home row mods + NAV / SYM / NUM / FUN layers
;
;  REQUIRES: AutoHotkey v2.0+  (https://www.autohotkey.com)
;  Run it by double-clicking, or right-click → Run as administrator if you
;  want remaps inside elevated apps. Add a shortcut to shell:startup to
;  launch at login.
;
;  WHAT MATCHES THE KANATA CONFIG
;   • Type fast = plain letters; pause 250 ms = home row mods arm (GASC:
;     A=Win S=Alt D=Shift F=Ctrl, J=Ctrl K=Shift L=Alt ;=Win, G/H=Hyper)
;   • Letter ORDER is preserved: all typing keys are hooked and re-sent by
;     scancode in sequence (also makes it work in any input language)
;   • Caps Lock: tap = Esc, hold = Ctrl
;   • Left Ctrl: tap = language switch (Win+Space), hold = Ctrl
;   • Left Win:  tap = Start, hold = NUM layer        (c-hold = NUM too)
;   • Left Alt:  hold = NAV layer                     (z-hold = FUN too)
;   • Right Alt: hold = SYM layer;  both Alts = FUN layer
;   • NAV: arrows on i/j/k/l, Home/End/PgUp/PgDn, Bspc/Enter/Del,
;     Alt-Tab swapper on W, browser back/fwd on G/T, tabs on E/R,
;     undo/cut/copy/paste on Z/X/C/V, media + volume, one-shot mods
;   • SYM: full symbol map incl. Space = underscore
;   • NUM: right-hand numpad, ( ) on Q/W, 000 and ,00 macros on V/B
;   • FUN: 1–0 on top row, F1–F12, Space = real Caps Lock toggle
;   • One-shot mods on every layer's home row (tap, then press the key)
;
;  WHAT IS DIFFERENT (AutoHotkey limitations / pragmatic choices)
;   • Chord combos are NOT ported (w+e+r=Esc, s+d+f=Enter, d+k=CapsWord,
;     m+,+.=NumWord, etc.). AHK can't buffer chords cleanly. Instead:
;       - Caps Word  = Shift+CapsLock
;       - Muggle mode (stock keyboard) = Ctrl+Alt+M
;       - Num Word: just hold LWin or C
;   • Cross-hand mod chords resolve a bit slower than kanata: either hold
;     the mod ~0.3 s before the other key, or use the layer one-shots.
;   • No live-reload combo — right-click the tray icon → Reload Script.
;   • kanata is still the technically better engine. Use this when kanata
;     isn't an option.
;
;  PANIC: Ctrl+Alt+M = stock keyboard. Tray icon → Exit kills everything.
; =============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook true
InstallKeybdHook true
SendMode "Input"
SetKeyDelay 20, 10            ; used by SendEvent (the Alt-Tab swapper)
ProcessSetPriority "High"
A_MaxHotkeysPerInterval := 400
A_HotkeyInterval := 1000
SetCapsLockState "AlwaysOff"

; ------------------------------------------------------------------ timings
global IDLE_MS := 250        ; require-prior-idle: mods arm after this pause
global TERM_MS := 300        ; tapping term: hold this long = modifier/layer
global CAPSWORD_MS := 5000   ; caps word auto-off

; --------------------------------------------------- scancodes (positional)
; Hotkeys and sends use scancodes, so this works in any keyboard language.
global SC := Map(
  "q","sc010","w","sc011","e","sc012","r","sc013","t","sc014",
  "y","sc015","u","sc016","i","sc017","o","sc018","p","sc019",
  "a","sc01E","s","sc01F","d","sc020","f","sc021","g","sc022",
  "h","sc023","j","sc024","k","sc025","l","sc026",";","sc027","'","sc028",
  "z","sc02C","x","sc02D","c","sc02E","v","sc02F","b","sc030",
  "n","sc031","m","sc032",",","sc033",".","sc034","/","sc035",
  "space","sc039")

; ------------------------------------------------- home row mod definitions
global HRM := Map(                       ; key → mods held (GASC + Hyper)
  "a",["LWin"], "s",["LAlt"], "d",["LShift"], "f",["LCtrl"],
  "g",["LCtrl","LShift","LAlt","LWin"],
  "h",["LCtrl","LShift","LAlt","LWin"],
  "j",["RCtrl"], "k",["RShift"], "l",["LAlt"], ";",["RWin"])
global HRMLAYER := Map("z","fun", "c","num")   ; key → layer held

global PLAIN := ["q","w","e","r","t","y","u","i","o","p",
                 "x","v","b","n","m",",",".","/","'","space"]

; same-hand non-mod keys: pressing one instantly resolves a pending mod as TAP
global LEFT_TAPS  := Map("q",1,"w",1,"e",1,"r",1,"t",1,"x",1,"v",1,"b",1)
global RIGHT_TAPS := Map("y",1,"u",1,"i",1,"o",1,"p",1,"n",1,"m",1,",",1,".",1,"/",1,"'",1)
global LEFT_HAND  := Map("q",1,"w",1,"e",1,"r",1,"t",1,"a",1,"s",1,"d",1,"f",1,"g",1,"z",1,"x",1,"c",1,"v",1,"b",1)

; ------------------------------------------------------------- engine state
global lastAct  := 0          ; tick of last typing activity
global pend1    := 0          ; pending tap-hold: {key, tick, timerFn}
global pendQ    := []         ; keys pressed while pend1 undecided: {key,hrm}
global heldHolds := Map()     ; key → resolved hold ({mods} or {layer})
global physDown := Map()      ; phys-down guard for auto-repeat
global nextMods := ""         ; armed one-shot prefixes ("^!+#")
global capsWord := false
global navHeld := false, symHeld := false
global numCount := 0, funCount := 0
global swapping := false      ; Alt-Tab swapper active
global winDown := false, winTick := 0

; ============================================================ core senders

SendLetter(key) {
  global nextMods, capsWord, lastAct
  pfx := nextMods, nextMods := ""
  if (capsWord && key ~= "^[a-z]$")
    pfx .= "+"
  Send "{Blind}" pfx "{" SC[key] "}"
  if (capsWord && key = "space")
    CapsWordOff()
  lastAct := A_TickCount
}

LayerSend(spec) {             ; spec like "{Tab}" or "^{sc02C}"; one-shots apply
  global nextMods, lastAct
  pfx := nextMods, nextMods := ""
  Send "{Blind}" pfx spec
  lastAct := A_TickCount
}

SymText(str) {                ; literal characters, layout-independent
  global nextMods, lastAct
  nextMods := ""
  SendText str
  lastAct := A_TickCount
}

ArmOneShot(prefix) {          ; "^" "!" "+" "#" — stack freely
  global nextMods
  if !InStr(nextMods, prefix)
    nextMods .= prefix
}

CapsWordOn() {
  global capsWord := true
  SetTimer CapsWordOff, -CAPSWORD_MS
  TrayTip "CAPS WORD"
}
CapsWordOff(*) {
  global capsWord := false
  SetTimer CapsWordOff, 0
}

; ===================================================== tap-hold engine
; The kanata logic, miniaturized:
;  • typing mode (last activity < 250 ms ago): HRM keys are instant letters
;  • after a pause: HRM key goes "pending"
;       - released alone quickly         → letter
;       - held 300 ms                    → modifier / layer
;       - same-hand plain key pressed    → everything resolves as letters
;       - other key pressed, pend key
;         still held when it's released  → modifier applied to that key
;  Keys pressed while pending are queued and re-sent IN ORDER — this is what
;  prevents the "os" → "so" letter swapping.

HrmDown(key, *) {
  Critical "On"
  global pend1, pendQ, lastAct, physDown
  if physDown.Has(key) {                       ; keyboard auto-repeat
    if (heldHolds.Has(key) || (pend1 && pend1.key = key) || InQ(key))
      return
    SendLetter(key)                            ; repeating a tapped letter
    return
  }
  physDown[key] := 1
  if capsWord {
    SendLetter(key)
    return
  }
  if (GetKeyState("Ctrl") || GetKeyState("Alt") || GetKeyState("LWin") || GetKeyState("RWin")) {
    SendLetter(key)                            ; a real chord is in progress
    return
  }
  if (A_TickCount - lastAct < IDLE_MS) {       ; typing fast → plain letter
    SendLetter(key)
    return
  }
  if !pend1 {                                  ; first key after a pause
    fn := HoldTimer.Bind(key)
    pend1 := {key: key, tick: A_TickCount, timerFn: fn}
    SetTimer fn, -TERM_MS
    return
  }
  if (pendQ.Length >= 3) {                     ; runaway burst → all letters
    FlushAllTaps()
    SendLetter(key)
    return
  }
  pendQ.Push({key: key, hrm: true})            ; second mod candidate: queue
}

HrmUp(key, *) {
  Critical "On"
  global pend1, pendQ, physDown, heldHolds
  if physDown.Has(key)
    physDown.Delete(key)
  if heldHolds.Has(key) {                      ; was acting as mod/layer
    ReleaseHold(key)
    return
  }
  if (pend1 && pend1.key = key) {              ; released alone/first → TAP
    SetTimer pend1.timerFn, 0
    p := pend1, pend1 := 0
    SendLetter(p.key)
    FlushQueueAsTaps()
    return
  }
  ; a QUEUED key released while pend1 is still held → pend1 becomes the mod
  for i, e in pendQ {
    if (e.key = key) {
      ResolveHold()                            ; pend1 → modifier (flushes Q)
      return
    }
  }
}

PlainDown(key, *) {
  Critical "On"
  global pend1, pendQ
  if capsWord {
    SendLetter(key)
    return
  }
  if !pend1 {
    SendLetter(key)
    return
  }
  if InQ(key)                                  ; auto-repeat while queued
    return
  ; same-hand plain key → kanata's "tap-keys" rule: everything is letters
  sameHand := LEFT_HAND.Has(pend1.key) ? LEFT_TAPS.Has(key) : RIGHT_TAPS.Has(key)
  if sameHand {
    FlushAllTaps()
    SendLetter(key)
    return
  }
  if (pendQ.Length >= 3) {
    FlushAllTaps()
    SendLetter(key)
    return
  }
  pendQ.Push({key: key, hrm: false})           ; cross-hand: keep order, wait
}

HoldTimer(key, *) {                            ; held 300 ms → it's a hold
  Critical "On"
  global pend1
  if (pend1 && pend1.key = key)
    ResolveHold()
}

ResolveHold() {
  global pend1, pendQ, heldHolds, lastAct
  p := pend1, pend1 := 0
  SetTimer p.timerFn, 0
  if HRMLAYER.Has(p.key)
    ActivateLayer(p.key, HRMLAYER[p.key])
  else {
    for m in HRM[p.key]
      Send "{Blind}{" m " down}"
    heldHolds[p.key] := {mods: HRM[p.key]}
  }
  ; flush whatever was waiting; plain keys now carry the mod (e.g. Ctrl+J).
  ; a still-held second HRM key gets promoted to its own pending decision.
  q := pendQ, pendQ := []
  for e in q {
    if (e.hrm && GetKeyState(SC[e.key], "P") && !pend1) {
      fn := HoldTimer.Bind(e.key)
      pend1 := {key: e.key, tick: A_TickCount, timerFn: fn}
      SetTimer fn, -TERM_MS
    } else
      SendLetter(e.key)
  }
  lastAct := A_TickCount
}

ReleaseHold(key) {
  global heldHolds
  h := heldHolds[key]
  heldHolds.Delete(key)
  if h.HasOwnProp("layer")
    DeactivateLayer(h.layer)
  else
    for m in h.mods
      Send "{Blind}{" m " up}"
}

ActivateLayer(key, layer) {
  global heldHolds, numCount, funCount
  heldHolds[key] := {layer: layer}
  if (layer = "num")
    numCount += 1
  else if (layer = "fun")
    funCount += 1
}
DeactivateLayer(layer) {
  global numCount, funCount
  if (layer = "num")
    numCount := Max(0, numCount - 1)
  else if (layer = "fun")
    funCount := Max(0, funCount - 1)
}

FlushAllTaps() {
  global pend1, pendQ
  if pend1 {
    SetTimer pend1.timerFn, 0
    p := pend1, pend1 := 0
    SendLetter(p.key)
  }
  FlushQueueAsTaps()
}
FlushQueueAsTaps() {
  global pendQ
  q := pendQ, pendQ := []
  for e in q
    SendLetter(e.key)
}
InQ(key) {
  global pendQ
  for e in pendQ
    if (e.key = key)
      return true
  return false
}

SafetyReset() {                                ; on muggle toggle / suspend
  global pend1, pendQ, heldHolds, navHeld, symHeld, numCount, funCount
  global swapping, nextMods, capsWord
  if pend1
    SetTimer pend1.timerFn, 0
  pend1 := 0, pendQ := []
  for key, h in heldHolds.Clone()
    ReleaseHold(key)
  if swapping {
    SendEvent "{LAlt up}"
    swapping := false
  }
  navHeld := false, symHeld := false, numCount := 0, funCount := 0
  nextMods := "", capsWord := false
}

; =================================================== layer condition logic
FunActive(*)  => (funCount > 0) || (navHeld && symHeld)
NumActive(*)  => (numCount > 0) && !FunActive()
NavActive(*)  => navHeld && !symHeld && !FunActive() && !NumActive()
SymActive(*)  => symHeld && !navHeld && !FunActive() && !NumActive()
BaseActive(*) => !FunActive() && !NumActive() && !navHeld && !symHeld

; ============================================================== layer maps
; helpers
L(spec)  => (*) => LayerSend(spec)             ; send keys (one-shots apply)
TX(str)  => (*) => SymText(str)                ; send literal characters
OS(pfx)  => (*) => ArmOneShot(pfx)             ; one-shot modifier
NOP(*)   => 0                                  ; do nothing (kanata's XX)
GuardSelf(key, fn) => (*) => (heldHolds.Has(key) ? 0 : fn())  ; ignore the layer's own held key

Swapper(*) {                                   ; kanata's tri-state Alt-Tab
  global swapping
  if !swapping {
    swapping := true
    SendEvent "{LAlt down}{Tab}"
  } else
    SendEvent "{Tab}"
}
ToggleRealCaps(*) {
  if GetKeyState("CapsLock", "T")
    SetCapsLockState "AlwaysOff"
  else
    SetCapsLockState "AlwaysOn"
}

global NAVMAP := Map(
  "q",L("{Tab}"),   "w",Swapper,       "e",L("+^{Tab}"),  "r",L("^{Tab}"),   "t",L("!{Right}"),
  "y",L("{PgUp}"),  "u",L("{Home}"),   "i",L("{Up}"),     "o",L("{End}"),    "p",L("{Backspace}"),
  "a",OS("#"),      "s",OS("!"),       "d",OS("+"),       "f",OS("^"),       "g",L("!{Left}"),
  "h",L("{PgDn}"),  "j",L("{Left}"),   "k",L("{Down}"),   "l",L("{Right}"),  ";",L("{Enter}"),
  "z",L("^{sc02C}"),"x",L("^{sc02D}"), "c",L("^{sc02E}"), "v",L("^{sc02F}"), "b",L("{F18}"),
  "n",L("{Media_Play_Pause}"), "m",L("{F19}"), ",",L("{Volume_Down}"), ".",L("{Volume_Up}"), "/",L("{Delete}"),
  "space",L("{space}"))

global SYMMAP := Map(
  "q",L("{Esc}"),   "w",TX("{"),  "e",TX("["),  "r",TX("("),  "t",TX("%"),
  "y",TX("&"),      "u",TX(")"),  "i",TX("]"),  "o",TX("}"),  "p",TX('"'),
  "a",TX("-"),      "s",TX("^"),  "d",TX("``"), "f",TX("~"),  "g",TX("$"),
  "h",TX("#"),      "j",OS("^"),  "k",OS("+"),  "l",OS("!"),  ";",OS("#"),
  "z",TX("+"),      "x",TX("="),  "c",TX("*"),  "v",TX("/"),  "b",TX("@"),
  "n",TX("|"),      "m",TX("\"),  ",",TX("?"),  ".",TX("!"),  "/",TX(":"),
  "space",TX("_"))

global NUMMAP := Map(
  "q",TX("("),      "w",TX(")"),  "e",NOP,      "r",NOP,      "t",NOP,
  "y",TX("+"),      "u",L("{sc008}"), "i",L("{sc009}"), "o",L("{sc00A}"), "p",TX("*"),
  "a",OS("#"),      "s",OS("!"),  "d",OS("+"),  "f",OS("^"),  "g",L("{Backspace}"),
  "h",L("{sc00C}"), "j",L("{sc005}"), "k",L("{sc006}"), "l",L("{sc007}"), ";",L("{sc035}"),
  "z",NOP,          "x",OS("+"),  "c",NOP,      "v",TX("000"),"b",TX(",00 "),
  "n",L("{sc033}"), "m",L("{sc002}"), ",",L("{sc003}"), ".",L("{sc004}"), "/",L("{sc034}"),
  "space",L("{space}"))
  ; sc002..sc00B = number row 1..0, sc00C = minus, sc033/034/035 = , . /

global FUNMAP := Map(
  "q",L("{sc002}"), "w",L("{sc003}"), "e",L("{sc004}"), "r",L("{sc005}"), "t",L("{sc006}"),
  "y",L("{sc007}"), "u",L("{sc008}"), "i",L("{sc009}"), "o",L("{sc00A}"), "p",L("{sc00B}"),
  "a",OS("#"),      "s",OS("!"),      "d",OS("+"),      "f",OS("^"),      "g",L("{F11}"),
  "h",L("{F12}"),   "j",OS("^"),      "k",OS("+"),      "l",OS("!"),      ";",OS("#"),
  "z",GuardSelf("z", L("{F1}")), "x",L("{F2}"), "c",L("{F3}"), "v",L("{F4}"), "b",L("{F5}"),
  "n",L("{F6}"),    "m",L("{F7}"),    ",",L("{F8}"),    ".",L("{F9}"),    "/",L("{F10}"),
  "space",ToggleRealCaps)

; ===================================================== hotkey registration
; Creation order = priority: FUN > NUM > NAV > SYM > base typing engine.

RegisterLayer(mapObj, condFn) {
  HotIf condFn
  for key, fn in mapObj
    Hotkey "*" SC[key], fn
  HotIf
}

RegisterLayer(FUNMAP, FunActive)
RegisterLayer(NUMMAP, NumActive)
RegisterLayer(NAVMAP, NavActive)
RegisterLayer(SYMMAP, SymActive)

HotIf BaseActive
for key in ["a","s","d","f","g","h","j","k","l",";","z","c"] {
  Hotkey "*" SC[key],         HrmDown.Bind(key)
  Hotkey "*" SC[key] " up",   HrmUp.Bind(key)
}
for key in PLAIN
  Hotkey "*" SC[key], PlainDown.Bind(key)
HotIf

; HRM keys must also release cleanly if a layer was toggled mid-hold
HotIf (*) => !BaseActive()
for key in ["a","s","d","f","g","h","j","k","l",";","z","c"]
  Hotkey "*" SC[key] " up", HrmUp.Bind(key)
HotIf

; ============================================================== thumb keys

*LAlt:: {                                      ; NAV layer
  global navHeld
  if navHeld
    return
  Critical "On"
  FlushAllTaps()
  navHeld := true
}
*LAlt up:: {
  global navHeld, swapping
  navHeld := false
  if swapping {
    SendEvent "{LAlt up}"                      ; commit the Alt-Tab switch
    swapping := false
  }
}

*RAlt:: {                                      ; SYM layer
  global symHeld
  if symHeld
    return
  Critical "On"
  FlushAllTaps()
  symHeld := true
}
*RAlt up:: {
  global symHeld
  symHeld := false
}

*LWin:: {                                      ; tap = Start, hold = NUM
  global winDown, winTick, numCount
  if winDown
    return
  Critical "On"
  FlushAllTaps()
  winDown := true, winTick := A_TickCount
  numCount += 1
}
*LWin up:: {
  global winDown, winTick, numCount
  winDown := false
  numCount := Max(0, numCount - 1)
  if (A_PriorKey = "LWin" && A_TickCount - winTick < TERM_MS)
    Send "{LWin}"
}

*CapsLock:: {                                  ; hold = Ctrl (instant)
  Send "{LCtrl down}"
}
*CapsLock up:: {
  global skipCapsEsc
  Send "{LCtrl up}"
  if skipCapsEsc {
    skipCapsEsc := false
    return
  }
  if (A_PriorKey = "CapsLock")
    Send "{Esc}"
}
+CapsLock:: {                                  ; Shift+Caps = Caps Word
  global skipCapsEsc := true
  CapsWordOn()
}

*LControl:: {                                  ; tap = language, hold = Ctrl
  global ctrlTick := A_TickCount
  Send "{LCtrl down}"
}
*LControl up:: {
  global ctrlTick
  Send "{LCtrl up}"
  if (A_PriorKey = "LControl" && A_TickCount - ctrlTick < TERM_MS)
    Send "#{Space}"                            ; switch input language
}

; timestamp-only hooks: keep the idle clock honest, end Caps Word on Enter
~*Enter:: {
  global lastAct := A_TickCount
  CapsWordOff()
}
~*Tab:: {
  global lastAct := A_TickCount
}
~*Backspace:: {
  global lastAct := A_TickCount
}

; ====================================================== muggle mode (panic)
#SuspendExempt
^!m:: {                                        ; Ctrl+Alt+M = stock keyboard
  Suspend -1
  if A_IsSuspended {
    SafetyReset()
    SetCapsLockState                           ; give Caps Lock back
    TrayTip "MUGGLE MODE — keyboard is stock. Ctrl+Alt+M to return."
  } else {
    SetCapsLockState "AlwaysOff"
    TrayTip "Layout active"
  }
}
#SuspendExempt False
