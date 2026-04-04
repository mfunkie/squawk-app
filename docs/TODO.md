# TODO

Open issues to address. Pick these up as time allows.

## Bugs

- [ ] **Clear conversation list locks up** — Opening the modal and clicking "Clear All" closes the popover and puts the app in a locked state. Likely a race between popover dismiss and the clear action.
- [ ] **Push-to-talk mode not working** — Changing from toggle to push-to-talk doesn't switch behavior; it stays in toggle mode. The hotkey mode setting isn't being applied to the actual hotkey handler.
