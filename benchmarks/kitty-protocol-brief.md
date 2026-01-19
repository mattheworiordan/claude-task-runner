# Kitty Keyboard Protocol Support for Ink

**Reference Issue:** https://github.com/vadimdemedes/ink/issues/824

## Goal

Add support for the Kitty keyboard protocol to the `useInput` hook in Ink, enabling detection of modifier keys that are currently indistinguishable (e.g., Shift+Enter vs Enter, Ctrl+I vs Tab).

## Background

The Kitty keyboard protocol is a modern terminal keyboard handling specification that solves limitations in traditional terminal input:
- Reliable detection of modifier combinations (Shift, Ctrl, Alt, Super)
- Unambiguous escape code mappings
- Support for press/repeat/release events
- Reliable Escape key distinction

The protocol is already supported by: iTerm2, Alacritty, Ghostty, WezTerm, Foot, Rio, Kitty.

**Protocol spec:** https://sw.kovidgoyal.net/kitty/keyboard-protocol/

## Requirements

- [ ] Detect terminal support for Kitty keyboard protocol
- [ ] Implement protocol opt-in at startup (send `CSI > flags u`)
- [ ] Implement protocol opt-out on exit (send `CSI < u`)
- [ ] Parse Kitty escape sequences (`CSI number ; modifiers u`)
- [ ] Decode modifier bitfield (shift=1, alt=2, ctrl=4, super=8)
- [ ] Update `useInput` hook to expose new modifier information
- [ ] Fall back gracefully to legacy parsing in non-supporting terminals
- [ ] Add tests for new functionality
- [ ] Update documentation

## Acceptance Criteria

- [ ] `shift+enter` is distinguishable from `enter` in supporting terminals
- [ ] `ctrl+i` is distinguishable from `tab` in supporting terminals
- [ ] Existing behavior unchanged in non-supporting terminals
- [ ] All existing tests pass
- [ ] New functionality has test coverage
- [ ] No breaking changes to existing `useInput` API

## Technical Notes

**Protocol detection:**
- Send `CSI ? u` to query support
- Terminal responds with `CSI ? flags u` if supported
- No response (timeout) means unsupported

**Escape sequence format:**
```
CSI number ; modifiers u
```
- `number`: Unicode codepoint or functional key code
- `modifiers`: 1 + sum of active modifiers (shift=1, alt=2, ctrl=4, super=8)

**Progressive enhancement levels (bitfield):**
- 0b1: Disambiguate escape codes
- 0b10: Report key event types (press/repeat/release)
- 0b100: Report alternate keys
- 0b1000: Report all keys as escape codes

## Success Signal

Output `<promise>COMPLETE</promise>` when all acceptance criteria are met.
