/// Presentation metadata on DTO fields. Drives the generated UIs (Fiori forms and tables,
/// GtkD dialogs, CLI field listing) via `describeModel`.
module neko.eam.application.dtos.annotations;

/// Human readable field label.
struct Label { string text; }
/// Form section / field group.
struct Group { string name; }
/// Derived or technical value - not editable by users.
struct ReadOnly {}
/// Shown as column in list views.
struct ListColumn {}
/// Long free text (rendered as text area).
struct Multiline {}
