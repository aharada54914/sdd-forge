# UI Patterns: タスクボード

## Actions
One primary teal 追加 action. Checkbox reversibly changes completion. Separate labeled 削除 action opens a confirmation with 削除/キャンセル text, to avoid accidental loss.
## Dialogs
Only deletion confirmation uses a dialog; status and errors remain inline. Cancel restores focus to the initiating row.
## Icons
Use native checkbox; no unexplained icon-only actions.
## Flow
Read heading, enter task, add, operate task rows. After addition focus input; after deletion focus next row or input.
## States
Empty: タスクはまだありません. Loading: 読み込み中. Saving: 保存中. Error: 保存できませんでした。再読み込みして状態を確認してください. Do not retry writes automatically.
## Cognitive Load
One purpose per screen, no unrelated navigation. Completed text has a strike-through plus checked state.
