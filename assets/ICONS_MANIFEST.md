# MemoChat Icon Manifest

All MemoChat custom icons use a **24×24 SVG master** with a rounded 1.8px stroke. The master assets are color-neutral at render time: `AppIcon` applies the current Flutter theme color for light/dark surfaces.

| Name | Use | Path | Format | States | Integrated locations |
|---|---|---|---|---|---|
| chat | Start a conversation | `assets/icons/chat.svg` | SVG | default/active/disabled via theme color | Home FAB |
| message | Message object | `assets/icons/message.svg` | SVG | default/active/disabled via theme color | Registry |
| send | Send message | `assets/icons/send.svg` | SVG | default/active/disabled via theme color | Chat composer |
| reply | Reply action | `assets/icons/reply.svg` | SVG | default/active/disabled via theme color | Registry |
| forward | Forward action | `assets/icons/forward.svg` | SVG | default/active/disabled via theme color | Registry |
| attachment | Add attachment | `assets/icons/attachment.svg` | SVG | default/active/disabled via theme color | Chat composer |
| image | Image attachment | `assets/icons/image.svg` | SVG | default/active/disabled via theme color | Registry |
| video | Video media | `assets/icons/video.svg` | SVG | default/active/disabled via theme color | Registry |
| audio | Audio media | `assets/icons/audio.svg` | SVG | default/active/disabled via theme color | Registry |
| file | File attachment | `assets/icons/file.svg` | SVG | default/active/disabled via theme color | Registry |
| microphone | Voice recording | `assets/icons/microphone.svg` | SVG | default/active/disabled via theme color | Registry |
| camera | Camera capture | `assets/icons/camera.svg` | SVG | default/active/disabled via theme color | Registry |
| phone_call | Voice call | `assets/icons/phone_call.svg` | SVG | default/active/disabled via theme color | Chat/call actions |
| video_call | Video call | `assets/icons/video_call.svg` | SVG | default/active/disabled via theme color | Chat/call screen |
| contacts | Contacts | `assets/icons/contacts.svg` | SVG | default/active/disabled via theme color | Registry |
| notifications | Notifications | `assets/icons/notifications.svg` | SVG | default/active/disabled via theme color | Home/notification center |
| search | Search | `assets/icons/search.svg` | SVG | default/active/disabled via theme color | Home |
| settings | Settings | `assets/icons/settings.svg` | SVG | default/active/disabled via theme color | Registry |
| profile | Profile | `assets/icons/profile.svg` | SVG | default/active/disabled via theme color | Registry |
| more | More actions | `assets/icons/more.svg` | SVG | default/active/disabled via theme color | Home/add action |

## Central API

Use `AppIcons.<name>` and render with `AppIcon(...)`; do not hard-code SVG filenames in widgets. `AppIcon` provides a semantic label and theme-aware color filtering. Interactive controls should also supply a `tooltip` or visible text and retain their existing hit target.

## Android notifications

`android/app/src/main/res/drawable/memochat_notification.xml` is a dedicated white vector notification icon. It is used by both initialization and message notification details. It is intentionally monochrome for Android status-bar requirements and is separate from the adaptive launcher icon.

## Audit notes

- Exactly 20 custom master SVG assets are present in `assets/icons/`.
- All masters use `viewBox="0 0 24 24"`, no background, and the same stroke settings.
- Material icons remain only where the function is not covered by this set (for example, message delivery ticks and the generic empty-state inbox).
- Active and disabled variants are theme/color states, not duplicate asset files.
