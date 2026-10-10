extends Control

const TERMINAL_TAB = preload("res://Scenes/terminal_tab.tscn")
const TERMINAL_ICON = preload("res://Assets/UI/terminal.svg")

@onready var tabs: TabContainer = %TabContainer
@onready var add_button: Button = %AddTabButton
@onready var tab_bar: TabBar = %TabBar
@onready var rename_dialog: ConfirmationDialog = %RenameDialog
@onready var rename_input: LineEdit = %RenameInput

var renaming_tab: Control

func _ready() -> void:
	add_button.pressed.connect(_add_tab)
	tab_bar.tab_close_pressed.connect(_close_tab)
	tab_bar.tab_selected.connect(_select_tab)
	tab_bar.gui_input.connect(_on_tab_bar_input)
	tabs.tab_changed.connect(_on_tab_changed)
	rename_dialog.confirmed.connect(_commit_rename)
	rename_dialog.canceled.connect(_cancel_rename)
	rename_dialog.close_requested.connect(_cancel_rename)
	rename_input.text_submitted.connect(_on_rename_submitted)
	_refresh_tabs()
	call_deferred("_focus_current_input")

func _add_tab() -> void:
	var newtab: Control = TERMINAL_TAB.instantiate()
	tabs.add_child(newtab, true)
	_refresh_tabs()
	tabs.current_tab = tabs.get_tab_count() - 1
	call_deferred("_focus_current_input")

func _close_tab(tab_index: int) -> void:
	# The last terminal stays open, including when close is pressed repeatedly.
	if tabs.get_tab_count() <= 1:
		return
	# Ignore an old close request if its index no longer exists.
	if tab_index < 0 or tab_index >= tabs.get_tab_count():
		return
	var tab_to_close: Control = tabs.get_tab_control(tab_index)
	var active_tab: Control = tabs.get_current_tab_control()
	if tab_to_close == renaming_tab:
		_cancel_rename()
	# Remove it from the container now so the tab count updates immediately.
	tabs.remove_child(tab_to_close)
	# Delete its nodes safely after Godot finishes the current processing.
	tab_to_close.queue_free()
	_refresh_tabs()
	# Keep the same terminal selected if we closed a different tab.
	if active_tab != tab_to_close:
		tabs.current_tab = tabs.get_tab_idx_from_control(active_tab)
	else:
		# Select the next neighbor, or the previous one if we closed the last tab.
		tabs.current_tab = mini(tab_index, tabs.get_tab_count() - 1)
	call_deferred("_focus_current_input")

func _refresh_tabs() -> void:
	# Keep the visible tab strip in sync without triggering selection callbacks.
	tab_bar.set_block_signals(true)
	tab_bar.tab_count = tabs.get_tab_count()
	for tab_index in range(tabs.get_tab_count()):
		var terminal: Control = tabs.get_tab_control(tab_index)
		var title: String = terminal.get_meta("terminal_custom_name", "")
		if title.is_empty():
			title = "Terminal " + str(tab_index + 1)
		tabs.set_tab_title(tab_index, title)
		tab_bar.set_tab_title(tab_index, title)
		tab_bar.set_tab_icon(tab_index, TERMINAL_ICON)
		tab_bar.set_tab_tooltip(tab_index, title + "\nDouble-click to rename")
	if tabs.current_tab >= 0 and tabs.current_tab < tab_bar.tab_count:
		tab_bar.current_tab = tabs.current_tab
	# Hide X when only one terminal remains; the close guard also blocks middle-click.
	if tabs.get_tab_count() <= 1:
		tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_NEVER
	else:
		tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ALWAYS
	tab_bar.set_block_signals(false)
	call_deferred("_scroll_to_current_tab")

func _select_tab(tab_index: int) -> void:
	if tab_index < 0 or tab_index >= tabs.get_tab_count():
		return
	if tabs.current_tab != tab_index:
		tabs.current_tab = tab_index
	call_deferred("_focus_current_input")

func _on_tab_changed(tab_index: int) -> void:
	if tab_index >= 0 and tab_index < tab_bar.tab_count:
		tab_bar.current_tab = tab_index
	call_deferred("_scroll_to_current_tab")
	call_deferred("_focus_current_input")

func _scroll_to_current_tab() -> void:
	# Scroll after the strip has finished updating its tab widths.
	if tabs.current_tab >= 0 and tabs.current_tab < tab_bar.tab_count:
		tab_bar.ensure_tab_visible(tabs.current_tab)

func _on_tab_bar_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed or not event.double_click:
		return
	var tab_index: int = tab_bar.get_tab_idx_at_point(event.position)
	if tab_index < 0:
		return
	# Double-click the label, not the close button.
	var tab_rect: Rect2 = tab_bar.get_tab_rect(tab_index)
	if tab_bar.tab_close_display_policy != TabBar.CLOSE_BUTTON_SHOW_NEVER:
		if event.position.x >= tab_rect.end.x - 32:
			return
	_start_rename(tab_index)
	tab_bar.accept_event()

func _start_rename(tab_index: int) -> void:
	if tab_index < 0 or tab_index >= tabs.get_tab_count():
		return
	# Remember the terminal itself so its name survives changes to tab positions.
	renaming_tab = tabs.get_tab_control(tab_index)
	rename_input.text = tabs.get_tab_title(tab_index)
	rename_dialog.popup_centered(Vector2i(380, 160))
	rename_input.call_deferred("grab_focus")
	rename_input.call_deferred("select_all")

func _commit_rename() -> void:
	if is_instance_valid(renaming_tab) and renaming_tab.get_parent() == tabs:
		# A blank name restores the automatic Terminal 1, Terminal 2, etc. title.
		renaming_tab.set_meta("terminal_custom_name", rename_input.text.strip_edges())
		_refresh_tabs()
	_cancel_rename()

func _on_rename_submitted(_text: String) -> void:
	_commit_rename()

func _cancel_rename() -> void:
	rename_dialog.hide()
	renaming_tab = null
	call_deferred("_focus_current_input")

func _focus_current_input() -> void:
	# Leave keyboard focus in the rename dialog while it is open.
	if rename_dialog.visible:
		return
	var active_tab: Control = tabs.get_current_tab_control()
	if active_tab == null:
		return
	var input: LineEdit = active_tab.get_node("%CommandInput")
	input.grab_focus()
