extends SceneTree
const OfficerPanel = preload("res://scripts/game/officer_panel.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
    if not value:
        failures+=1
        printerr("FAIL: ",message)
func settle(panel: Node) -> void:
    var deadline := Time.get_ticks_msec()+10000
    for i in 4: await process_frame
    while panel.icon_stream.pending() and Time.get_ticks_msec()<deadline: await process_frame
    check(not panel.icon_stream.pending(),"portrait loads settle")
func run() -> void:
    var panel := OfficerPanel.new()
    panel.standalone=true
    root.add_child(panel)
    panel.show_browser()
    panel.filter.select(0)
    panel.cohort.select(0)
    panel.rated.set_pressed_no_signal(false)
    panel.refresh_list()
    await settle(panel)
    check(panel.matches.size()==1598,"all officers retained")
    for offset in [0,400,800,1200,1597]:
        panel.items.ensure_current_is_visible()
        panel.items.select(offset)
        panel.items.ensure_current_is_visible()
        panel.icon_range_dirty=true
        await settle(panel)
        check(panel.icon_stream.waiting.size()<=2,"at most two portrait loads")
        check(panel.icon_stream.resident_bytes+panel.icon_stream.reserved_bytes<=panel.icon_stream.budget_bytes,"24 MiB portrait budget")
        check(panel.icon_rows.size()<panel.matches.size(),"only visible rows demand portraits")
        for index in panel.icon_rows:
            check(panel.items.get_item_icon(index)==panel.icon_stream.texture(panel.icon_rows[index]),"visible portrait arrives")
    panel.browser.hide()
    for i in 4: await process_frame
    check(panel.icon_stream.resident.is_empty(),"closing list releases portrait cache")
    check(panel.portrait.texture==null,"closing list releases detail portrait")
    print("PORTRAIT_STREAMING ","PASS" if failures==0 else "FAIL")
    quit(0 if failures==0 else 1)
