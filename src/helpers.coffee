{calculateSpecificity} = require 'clear-cut'

AtomModifiers = new Set
AtomModifiers.add(modifier) for modifier in ['ctrl', 'alt', 'shift', 'cmd']

AtomModifierRegex = /(ctrl|alt|shift|cmd)$/
WhitespaceRegex = /\s+/
LowerCaseLetterRegex = /^[a-z]$/
UpperCaseLetterRegex = /^[A-Z]$/
ExactMatch = 'exact'
KeydownExactMatch = 'keydownExact'
PartialMatch = 'partial'

KeyboardEventModifiers = new Set
KeyboardEventModifiers.add(modifier) for modifier in ['Control', 'Alt', 'Shift', 'Meta']

WindowsAndLinuxKeyIdentifierTranslations =
  'U+00A0': 'Shift'
  'U+00A1': 'Shift'
  'U+00A2': 'Control'
  'U+00A3': 'Control'
  'U+00A4': 'Alt'
  'U+00A5': 'Alt'
  'Win': 'Meta'

WindowsAndLinuxCharCodeTranslations =
  48:
    shifted: 41    # ")"
    unshifted: 48  # "0"
  49:
    shifted: 33    # "!"
    unshifted: 49  # "1"
  50:
    shifted: 64    # "@"
    unshifted: 50  # "2"
  51:
    shifted: 35    # "#"
    unshifted: 51  # "3"
  52:
    shifted: 36    # "$"
    unshifted: 52  # "4"
  53:
    shifted: 37    # "%"
    unshifted: 53  # "5"
  54:
    shifted: 94    # "^"
    unshifted: 54  # "6"
  55:
    shifted: 38    # "&"
    unshifted: 55  # "7"
  56:
    shifted: 42    # "*"
    unshifted: 56  # "8"
  57:
    shifted: 40    # "("
    unshifted: 57  # "9"
  186:
    shifted: 58    # ":"
    unshifted: 59  # ";"
  187:
    shifted: 43    # "+"
    unshifted: 61  # "="
  188:
    shifted: 60    # "<"
    unshifted: 44  # ","
  189:
    shifted: 95    # "_"
    unshifted: 45  # "-"
  190:
    shifted: 62    # ">"
    unshifted: 46  # "."
  191:
    shifted: 63    # "?"
    unshifted: 47  # "/"
  192:
    shifted: 126   # "~"
    unshifted: 96  # "`"
  219:
    shifted: 123   # "{"
    unshifted: 91  # "["
  220:
    shifted: 124   # "|"
    unshifted: 92  # "\"
  221:
    shifted: 125   # "}"
    unshifted: 93  # "]"
  222:
    shifted: 34    # '"'
    unshifted: 39  # "'"

NumPadToASCII =
  79: 47 # "/"
  74: 42 # "*"
  77: 45 # "-"
  75: 43 # "+"
  78: 46 # "."
  96: 48 # "0"
  65: 49 # "1"
  66: 50 # "2"
  67: 51 # "3"
  68: 52 # "4"
  69: 53 # "5"
  70: 54 # "6"
  71: 55 # "7"
  72: 56 # "8"
  73: 57 # "9"

exports.normalizeKeystrokes = (keystrokes) ->
  normalizedKeystrokes = []
  for keystroke in keystrokes.split(WhitespaceRegex)
    if normalizedKeystroke = normalizeKeystroke(keystroke)
      normalizedKeystrokes.push(normalizedKeystroke)
    else
      return false
  normalizedKeystrokes.join(' ')

exports.keystrokeForKeyboardEvent = (event, dvorakQwertyWorkaroundEnabled) ->
  key = keyForKeyboardEvent(event, dvorakQwertyWorkaroundEnabled)

  keystroke = ''
  if event.ctrlKey or key is 'Control'
    keystroke += 'ctrl'
  if event.altKey or key is 'Alt'
    keystroke += '-' if keystroke
    keystroke += 'alt'
  if event.shiftKey or key is 'Shift'
    # Don't push 'shift' when modifying symbolic characters like '{'
    unless /^[^A-Za-z]$/.test(key)
      keystroke += '-' if keystroke
      keystroke += 'shift'
  if event.metaKey or key is 'Meta'
    keystroke += '-' if keystroke
    keystroke += 'cmd'
  if key? and not KeyboardEventModifiers.has(key)
    keystroke += '-' if keystroke
    keystroke += key

  keystroke = normalizeKeystroke("^#{keystroke}") if event.type is 'keyup'
  keystroke

exports.characterForKeyboardEvent = (event, dvorakQwertyWorkaroundEnabled) ->
  unless event.ctrlKey or event.altKey or event.metaKey
    if key = keyForKeyboardEvent(event, dvorakQwertyWorkaroundEnabled)
      if key.length is 1
        return key
      if key == 'space'
        return ' '

exports.calculateSpecificity = calculateSpecificity

exports.isAtomModifier = (keystroke) ->
  AtomModifiers.has(keystroke) or AtomModifierRegex.test(keystroke)

exports.keydownEvent = (key, options) ->
  return keyboardEvent(key, 'keydown', options)

exports.keyupEvent = (key, options) ->
  return keyboardEvent(key, 'keyup', options)

keyboardEvent = (key, eventType, {ctrl, shift, alt, cmd, keyCode, target, location}={}) ->
  event = document.createEvent('KeyboardEvent')
  bubbles = true
  cancelable = true
  view = null

  key = key.toUpperCase() if LowerCaseLetterRegex.test(key)
  if key.length is 1
    keyIdentifier = "U+#{key.charCodeAt(0).toString(16)}"
  else
    switch key
      when 'ctrl'
        keyIdentifier = 'Control'
        ctrl = true if eventType isnt 'keyup'
      when 'alt'
        keyIdentifier = 'Alt'
        alt = true if eventType isnt 'keyup'
      when 'shift'
        keyIdentifier = 'Shift'
        shift = true if eventType isnt 'keyup'
      when 'cmd'
        keyIdentifier = 'Meta'
        cmd = true if eventType isnt 'keyup'
      else
        keyIdentifier = key[0].toUpperCase() + key[1..]

  location ?= KeyboardEvent.DOM_KEY_LOCATION_STANDARD
  event.initKeyboardEvent(eventType, bubbles, cancelable, view,  keyIdentifier, location, ctrl, alt, shift, cmd)
  if target?
    Object.defineProperty(event, 'target', get: -> target)
    Object.defineProperty(event, 'path', get: -> [target])
  Object.defineProperty(event, 'keyCode', get: -> keyCode)
  Object.defineProperty(event, 'which', get: -> keyCode)
  event

# bindingKeystrokes and userKeystrokes are arrays of keystrokes
# e.g. ['ctrl-y', 'ctrl-x', '^x']
exports.keystrokesMatch = (bindingKeystrokes, userKeystrokes) ->
  userKeystrokeIndex = -1
  userKeystrokesHasKeydownEvent = false
  matchesNextUserKeystroke = (bindingKeystroke) ->
    while userKeystrokeIndex < userKeystrokes.length - 1
      userKeystrokeIndex += 1
      userKeystroke = userKeystrokes[userKeystrokeIndex]
      isKeydownEvent = not userKeystroke.startsWith('^')
      userKeystrokesHasKeydownEvent = true if isKeydownEvent
      if bindingKeystroke is userKeystroke
        return true
      else if isKeydownEvent
        return false
    null

  isPartialMatch = false
  bindingRemainderContainsOnlyKeyups = true
  bindingKeystrokeIndex = 0
  for bindingKeystroke in bindingKeystrokes
    unless isPartialMatch
      doesMatch = matchesNextUserKeystroke(bindingKeystroke)
      if doesMatch is false
        return false
      else if doesMatch is null
        # Make sure userKeystrokes with only keyup events doesn't match everything
        if userKeystrokesHasKeydownEvent
          isPartialMatch = true
        else
          return false

    if isPartialMatch
      bindingRemainderContainsOnlyKeyups = false unless bindingKeystroke.startsWith('^')

  # Bindings that match the beginning of the user's keystrokes are not a match.
  # e.g. This is not a match. It would have been a match on the previous keystroke:
  # bindingKeystrokes = ['ctrl-tab', '^tab']
  # userKeystrokes    = ['ctrl-tab', '^tab', '^ctrl']
  return false if userKeystrokeIndex < userKeystrokes.length - 1

  if isPartialMatch and bindingRemainderContainsOnlyKeyups
    KeydownExactMatch
  else if isPartialMatch
    PartialMatch
  else
    ExactMatch

normalizeKeystroke = (keystroke) ->
  if isKeyup = keystroke.startsWith('^')
    keystroke = keystroke.slice(1)
  keys = parseKeystroke(keystroke)
  return false unless keys

  primaryKey = null
  modifiers = new Set

  for key, i in keys
    if AtomModifiers.has(key)
      modifiers.add(key)
    else
      # only the last key can be a non-modifier
      if i is keys.length - 1
        primaryKey = key
      else
        return false

  if isKeyup
    primaryKey = primaryKey.toLowerCase() if primaryKey?
  else
    modifiers.add('shift') if UpperCaseLetterRegex.test(primaryKey)
    if modifiers.has('shift') and LowerCaseLetterRegex.test(primaryKey)
      primaryKey = primaryKey.toUpperCase()

  keystroke = []
  if not isKeyup or (isKeyup and not primaryKey?)
    keystroke.push('ctrl') if modifiers.has('ctrl')
    keystroke.push('alt') if modifiers.has('alt')
    keystroke.push('shift') if modifiers.has('shift')
    keystroke.push('cmd') if modifiers.has('cmd')
  keystroke.push(primaryKey) if primaryKey?
  keystroke = keystroke.join('-')
  keystroke = "^#{keystroke}" if isKeyup
  keystroke

parseKeystroke = (keystroke) ->
  keys = []
  keyStart = 0
  for character, index in keystroke when character is '-'
    if index > keyStart
      keys.push(keystroke.substring(keyStart, index))
      keyStart = index + 1

      # The keystroke has a trailing - and is invalid
      return false if keyStart is keystroke.length
  keys.push(keystroke.substring(keyStart)) if keyStart < keystroke.length
  keys

keyForKeyboardEvent = (event, dvorakQwertyWorkaroundEnabled) ->
  keyIdentifier = event.keyIdentifier
  if process.platform in ['linux', 'win32']
    keyIdentifier = translateKeyIdentifierForWindowsAndLinuxChromiumBug(keyIdentifier)

  return keyIdentifier if KeyboardEventModifiers.has(keyIdentifier)

  charCode = charCodeFromKeyIdentifier(keyIdentifier)

  if dvorakQwertyWorkaroundEnabled and typeof charCode is 'number'
    if event.keyCode is 46 # key code for 'delete'
      charCode = 127 # ASCII character code for 'delete'
    else
      charCode = event.keyCode

  if charCode?
    if process.platform in ['linux', 'win32']
      charCode = translateCharCodeForWindowsAndLinuxChromiumBug(charCode, event.shiftKey)

    if event.location is KeyboardEvent.DOM_KEY_LOCATION_NUMPAD
      # This is a numpad number
      charCode = numpadToASCII(charCode)

    charCode = event.which if not isASCII(charCode) and isASCII(event.keyCode)
    key = keyFromCharCode(charCode)
  else
    key = keyIdentifier.toLowerCase()

  # Only upper case alphabetic characters like 'a'
  if event.shiftKey
    key = key.toUpperCase() if LowerCaseLetterRegex.test(key)
  else
    key = key.toLowerCase() if UpperCaseLetterRegex.test(key)

  key

charCodeFromKeyIdentifier = (keyIdentifier) ->
  parseInt(keyIdentifier[2..], 16) if keyIdentifier.indexOf('U+') is 0

# Chromium includes incorrect keyIdentifier values on keypress events for
# certain symbols keys on Window and Linux.
#
# See https://code.google.com/p/chromium/issues/detail?id=51024
# See https://bugs.webkit.org/show_bug.cgi?id=19906
translateKeyIdentifierForWindowsAndLinuxChromiumBug = (keyIdentifier) ->
  WindowsAndLinuxKeyIdentifierTranslations[keyIdentifier] ? keyIdentifier

translateCharCodeForWindowsAndLinuxChromiumBug = (charCode, shift) ->
  if translation = WindowsAndLinuxCharCodeTranslations[charCode]
    if shift then translation.shifted else translation.unshifted
  else
    charCode

keyFromCharCode = (charCode) ->
  switch charCode
    when 8 then 'backspace'
    when 9 then 'tab'
    when 13 then 'enter'
    when 27 then 'escape'
    when 32 then 'space'
    when 127 then 'delete'
    else String.fromCharCode(charCode)

isASCII = (charCode) ->
  0 <= charCode <= 127

numpadToASCII = (charCode) ->
  NumPadToASCII[charCode] ? charCode
