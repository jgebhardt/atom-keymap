KeyBinding = require './key-binding'
{keystrokeForKeyboardEvent} = require './helpers'

Modifiers = ['Control', 'Alt', 'Shift', 'Meta']

module.exports =
class Keymap
  constructor: (options) ->
    @defaultTarget = options?.defaultTarget
    @keyBindings = []
    @keystrokes = []

  destroy: ->

  # Public: Add sets of key bindings grouped by CSS selector.
  #
  # source - A {String} (usually a path) uniquely identifying the given bindings
  #   so they can be removed later.
  # bindings - An {Object} whose top-level keys point at sub-objects mapping
  #   keystroke patterns to commands.
  addKeyBindings: (source, keyBindingsBySelector) ->
    for selector, keyBindings of keyBindingsBySelector
      @addKeyBindingsForSelector(source, selector, keyBindings)

  addKeyBindingsForSelector: (source, selector, keyBindings) ->
    # Verify selector is valid before registering any bindings
    try
      document.body.webkitMatchesSelector(selector.replace(/!important/g, ''))
    catch
      console.warn("Encountered an invalid selector adding keybindings from '#{source}': '#{selector}'")
      return

    for keystroke, command of keyBindings
      keyBinding = new KeyBinding(source, command, keystroke, selector)
      @keyBindings.push(keyBinding)

  handleKeyboardEvent: (event) ->
    @keystrokes.push(@keystrokeForKeyboardEvent(event))
    keystrokes = @keystrokes.join(' ')

    target = event.target
    target = @defaultTarget if event.target is document.body and @defaultTarget?
    while target? and target isnt document
      candidateBindings = @keyBindingsForKeystrokesAndTarget(keystrokes, target)
      if candidateBindings.length > 0
        @keystrokes = []
        return if @dispatchCommandEvent(event, target, candidateBindings[0].command)
      target = target.parentElement

  dispatchCommandEvent: (keyboardEvent, target, command) ->
    return true if command is 'native!'
    keyboardEvent.preventDefault()
    commandEvent = document.createEvent("CustomEvent")
    commandEvent.initCustomEvent(command, bubbles = true, cancelable = true)
    commandEvent.originalEvent = keyboardEvent
    commandEvent.keyBindingAborted = false
    commandEvent.abortKeyBinding = ->
      @stopImmediatePropagation()
      @keyBindingAborted = true
    target.dispatchEvent(commandEvent)
    not commandEvent.keyBindingAborted

  keyBindingsForKeystrokesAndTarget: (keystrokes, target) ->
    @keyBindings
      .filter (binding) ->
        binding.keystrokes.indexOf(keystrokes) is 0 \
          and target.webkitMatchesSelector(binding.selector)
      .sort (a, b) -> a.compare(b)

  # Public: Get the keybindings for a given command and optional target.
  #
  # params - An {Object} whose keys constrain the binding search:
  #   :command - A {String} representing the name of a command, such as
  #     'editor:backspace'
  #   :target - An optional DOM element constraining the search. If this
  #     parameter is supplied, the call will only return bindings that can be
  #     invoked by a KeyboardEvent originating from the target element.
  findKeyBindings: (params={}) ->
    {command, target} = params

    bindings = @keyBindings.filter (binding) -> binding.command is command
    if target?
      candidateBindings = bindings
      bindings = []
      element = target
      while element? and element isnt document
        matchingBindings = candidateBindings
          .filter (binding) -> element.webkitMatchesSelector(binding.selector)
          .sort (a, b) -> a.compare(b)
        bindings.push(matchingBindings...)
        element = element.parentElement
    bindings

  keyBindingsForKeystrokes: (keystrokes) ->
    @keyBindings.filter (binding) -> binding.keystrokes.indexOf(keystrokes) is 0

  # Public: Translate a keydown event to a keystroke string.
  #
  # event - A {KeyboardEvent} of type 'keydown'
  #
  # Returns a {String} describing the keystroke.
  keystrokeForKeyboardEvent: (event) ->
    keystrokeForKeyboardEvent(event)

  # Deprecated: Use {::addKeyBindings} instead.
  add: (source, bindings) ->
    @addKeyBindings(source, bindings)

  # Deprecated: Handle a jQuery keyboard event. Use {::handleKeyboardEvent} with
  # a raw keyboard event instead.
  handleKeyEvent: (event) ->
    event = event.originalEvent ? event
    @handleKeyboardEvent(event)
    not event.defaultPrevented

  # Deprecated: Translate a jQuery keyboard event to a keystroke string. Use
  # {::keystrokeForKeyboardEvent} with a raw KeyboardEvent instead.
  keystrokeStringForEvent: (event) ->
    @keystrokeForKeyboardEvent(event.originalEvent ? event)

  # Deprecated: Use {::addKeyBindings} with a map from selectors to keybindings.
  bindKeys: (source, selector, keyBindings) ->
    @addKeyBindingsForSelector(source, selector, keyBindings)

  # Deprecated: Use {::keyBindingsForCommand} with the second element argument.
  keyBindingsForCommandMatchingElement: (command, target) ->
    @findKeyBindings({command, target: target[0] ? target})
