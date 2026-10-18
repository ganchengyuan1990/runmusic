extends Node
## 听歌打点：谱面草稿、导出、ChartLoader、试玩路径，以及默认开局仍是 song_01。
## 作为场景运行（不要 --script），自动加载才在。

const DraftLib = preload("res://scripts/tools/ChartDraft.gd")
const WavLib = preload("res://scripts/audio/WavStream.gd")
const SHOT_DIR := "/opt/cursor/artifacts/screenshots"
const TEST_WAV := "res://assets/audio/bgm/song_01_test.wav"
const KISS_WAV := "res://assets/audio/sfx/kiss.wav"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := false
	var shots := "--shots" in OS.get_cmdline_user_args()
	if not await _logic():
		failed = true
	if not failed and shots:
		if not await _shots():
			failed = true
	if failed:
		print("CHART_TAP_FAIL")
		get_tree().quit(1)
		return
	print("CHART_TAP_OK")
	get_tree().quit(0)


func _logic() -> bool:
	if not _draft_cases():
		return false
	if not _audio_cases():
		return false
	if not await _tool_cases():
		return false
	if not _title_button():
		return false
	if not await _game_preview():
		return false
	print("chart tap logic ok")
	return true


func _draft_cases() -> bool:
	var draft = DraftLib.new()
	draft.song_id = "draft_probe"
	draft.title = "草稿"
	draft.audio = TEST_WAV
	draft.bpm = 120.0
	draft.duration_sec = 60.0
	if draft.place(1.2, "low", 0.5) != "":
		return _fail("snap place")
	if absf(float(draft.notes[0]["t"]) - 1.0) > 0.0001:
		return _fail("snap t %s" % draft.notes[0]["t"])
	if draft.place(1.24, "low", 0.5) == "":
		return _fail("duplicate snap should fail")
	if draft.place(1.0, "jump", 0.0) == "":
		return _fail("jump alias at same t should fail")
	if draft.place(3.0, "high", 0.0) != "":
		return _fail("high")
	if draft.place(6.0, "pit", 0.0) != "":
		return _fail("pit")
	if int(draft.notes[draft.last_index]["width"]) != DraftLib.DEFAULT_PIT_WIDTH:
		return _fail("pit width")
	if draft.place(9.0, "platform", 0.0) != "":
		return _fail("platform")
	if int(draft.notes[draft.last_index]["height"]) != DraftLib.DEFAULT_PLATFORM_HEIGHT:
		return _fail("platform height")
	var platform_index: int = draft.last_index
	if draft.cycle_type(platform_index) != "":
		return _fail("cycle")
	if str(draft.notes[platform_index]["type"]) != "buddy":
		return _fail("cycle type %s" % draft.notes[platform_index]["type"])
	if not draft.undo():
		return _fail("undo cycle")
	if str(draft.notes[platform_index]["type"]) != "platform":
		return _fail("undo cycle type")
	if draft.place(12.0, "buddy", 0.0) != "":
		return _fail("buddy")
	if not draft.undo():
		return _fail("undo")
	if draft.notes.size() != 4:
		return _fail("undo size %s" % draft.notes.size())
	if draft.place(12.0, "buddy", 0.0) != "":
		return _fail("buddy again")
	if draft.delete_near(6.05, 0.12) != "":
		return _fail("delete near")
	if draft.nearest_index(6.0, 0.05) >= 0:
		return _fail("pit still there")
	if draft.place(6.0, "pit", 0.0) != "":
		return _fail("pit restore")
	if draft.nudge(0, 1000.0) != "":
		return _fail("nudge")
	if absf(float(draft.notes[draft.last_index]["t"]) - draft.duration_sec) > 0.001:
		return _fail("nudge left the song %s" % draft.notes[draft.last_index]["t"])
	var path := "user://charts/draft_probe.json"
	var err: String = draft.save_to(path)
	if err != "":
		return _fail("save %s" % err)
	if not ChartLoader.load_chart(path):
		return _fail("load saved %s" % str(ChartLoader.get_last_errors()))
	if str(ChartLoader.chart.get("schemaVersion", 0)) != "1" and int(ChartLoader.chart.get("schemaVersion", 0)) != 1:
		return _fail("schema")
	if str(ChartLoader.chart.get("songId", "")) != "draft_probe":
		return _fail("song id")
	var kinds := {}
	for n in ChartLoader.notes:
		kinds[str(n.get("type", ""))] = true
	if not kinds.has("low") or not kinds.has("high") or not kinds.has("pit") or not kinds.has("buddy"):
		return _fail("kinds %s" % kinds)
	var roundtrip = DraftLib.load_path("res://charts/song_01.json")
	if not bool(roundtrip.get("ok", false)):
		return _fail("song_01 %s" % roundtrip.get("error", ""))
	var original_count: int = roundtrip["draft"].notes.size()
	if original_count < 5:
		return _fail("song_01 empty")
	var copy_path := "user://charts/song_01_roundtrip.json"
	var copy_err: String = roundtrip["draft"].save_to(copy_path)
	if copy_err != "":
		return _fail("roundtrip %s" % copy_err)
	if not ChartLoader.load_chart(copy_path):
		return _fail("roundtrip load %s" % str(ChartLoader.get_last_errors()))
	if ChartLoader.notes.size() != original_count:
		return _fail("roundtrip count %s vs %s" % [ChartLoader.notes.size(), original_count])
	var alias = DraftLib.from_dictionary({
		"schemaVersion": 1,
		"songId": "alias",
		"title": "alias",
		"audio": TEST_WAV,
		"bpm": 120,
		"durationSec": 10,
		"notes": [
			{"t": 1.0, "type": "jump"},
			{"t": 1.0, "type": "low"},
			{"t": 2.0, "type": "hold", "duration": 0.5},
		],
	})
	if alias.notes.size() != 2:
		return _fail("alias collapsed %s" % alias.notes.size())
	if str(alias.notes[0]["type"]) != "low":
		return _fail("jump not canonical")
	if not alias.notes[1].has("duration"):
		return _fail("hold duration dropped")
	print("draft ok")
	return true


func _audio_cases() -> bool:
	var wav := WavLib.load_file(TEST_WAV)
	if wav == null or wav.get_length() < 30.0:
		return _fail("test wav")
	if WavLib.load_file("res://missing.wav") != null:
		return _fail("missing wav")
	var fake := "user://not_audio.ogg"
	var file := FileAccess.open(fake, FileAccess.WRITE)
	if file == null:
		return _fail("cannot write fake ogg")
	file.store_string("NOPE")
	file.close()
	if WavLib.load_file(fake) != null:
		return _fail("fake ogg decoded")
	var fake_mp3 := "user://not_audio.mp3"
	file = FileAccess.open(fake_mp3, FileAccess.WRITE)
	file.store_string("NOPE")
	file.close()
	if WavLib.load_file(fake_mp3) != null:
		return _fail("fake mp3 decoded")
	if not _decoded_compressed():
		return false
	print("audio ok")
	return true


func _decoded_compressed() -> bool:
	if not FileAccess.file_exists("/usr/bin/ffmpeg"):
		print("ffmpeg missing, skip ogg/mp3 decode")
		return true
	var src := ProjectSettings.globalize_path(TEST_WAV)
	var ogg := "/tmp/tap_tone.ogg"
	var mp3 := "/tmp/tap_tone.mp3"
	for pair in [[ogg, "libvorbis"], [mp3, "libmp3lame"]]:
		var log: Array = []
		var code := OS.execute("ffmpeg", ["-y", "-t", "1", "-i", src, "-c:a", str(pair[1]), str(pair[0])], log, true, false)
		if code != 0:
			print("ffmpeg skip %s (%s)" % [pair[0], code])
			continue
		var stream := WavLib.load_file(str(pair[0]))
		if stream == null or stream.get_length() < 0.4:
			return _fail("decode %s length %s" % [pair[0], stream.get_length() if stream else -1])
	return true


func _tool_cases() -> bool:
	var tap: Control = load("res://scenes/tools/ChartTap.tscn").instantiate()
	get_tree().root.add_child(tap)
	await get_tree().process_frame
	if not tap.load_audio_path(TEST_WAV):
		return _fail("tool audio %s" % tap._status.text)
	if tap.peak_count() < 32:
		return _fail("waveform %s" % tap.peak_count())
	if tap.draft.duration_sec < 30.0:
		return _fail("tool duration")
	tap._snap.button_pressed = true
	tap._div.selected = 0
	tap.seek_seconds(4.2)
	if tap.place_type("low") != "":
		return _fail("tool low")
	if absf(float(tap.draft.notes[tap.draft.last_index]["t"]) - 4.0) > 0.001:
		return _fail("tool snap %s" % tap.draft.notes[tap.draft.last_index]["t"])
	tap._snap.button_pressed = false
	tap.seek_seconds(7.0)
	if tap.place_type("high") != "":
		return _fail("tool high")
	tap.seek_seconds(10.0)
	if tap.place_type("pit") != "":
		return _fail("tool pit")
	tap._bump_width(16)
	if int(tap.draft.notes[tap._selected]["width"]) != DraftLib.DEFAULT_PIT_WIDTH + 16:
		return _fail("width bump")
	tap.seek_seconds(13.0)
	if tap.place_type("buddy") != "":
		return _fail("tool buddy")
	tap.seek_seconds(16.5)
	if tap.place_type("platform") != "":
		return _fail("tool platform")
	if not tap.undo_last():
		return _fail("tool undo")
	tap.seek_seconds(16.5)
	if tap.place_type("platform") != "":
		return _fail("platform redo")
	tap.seek_seconds(10.0)
	if not tap.delete_near_playhead():
		return _fail("tool delete")
	tap.seek_seconds(10.0)
	if tap.place_type("pit") != "":
		return _fail("pit redo")
	if tap.assign_key("low", KEY_SPACE) == "":
		return _fail("space should stay reserved")
	if tap.assign_key("buddy", KEY_B) != "":
		return _fail("remap buddy")
	tap.seek_seconds(20.0)
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_B
	key.keycode = KEY_B
	tap._handle_key(key)
	if tap.draft.nearest_index(20.0, 0.02) < 0:
		return _fail("remapped key did not place")
	tap.toggle_playback()
	await get_tree().process_frame
	tap.toggle_playback()
	var out := "user://charts/tool_probe.json"
	tap._title_edit.text = "打点探针"
	tap._id_edit.text = "tool_probe"
	if not tap.export_path(out):
		return _fail("export %s" % tap.last_error)
	if not ChartLoader.load_chart(out):
		return _fail("export load %s" % str(ChartLoader.get_last_errors()))
	var need := {"low": false, "high": false, "pit": false, "platform": false, "buddy": false}
	for n in ChartLoader.notes:
		var kind := str(n.get("type", ""))
		if need.has(kind):
			need[kind] = true
		if kind == "pit" and int(n.get("width", 0)) <= 0:
			return _fail("exported pit width")
		if kind == "platform" and (int(n.get("width", 0)) <= 0 or int(n.get("height", 0)) <= 0):
			return _fail("exported platform size")
	for kind in need.keys():
		if not need[kind]:
			return _fail("export missing %s" % kind)
	if int(ChartLoader.chart.get("schemaVersion", 0)) != 1:
		return _fail("export schema")
	if str(ChartLoader.chart.get("audio", "")) != TEST_WAV:
		return _fail("export audio %s" % ChartLoader.chart.get("audio", ""))
	var song = DraftLib.load_path("res://charts/song_01.json")
	if not bool(song.get("ok", false)):
		return _fail("song open %s" % song.get("error", ""))
	var expect: int = song["draft"].notes.size()
	if not tap.load_chart_path("res://charts/song_01.json"):
		return _fail("reload song %s" % tap.last_error)
	if tap.draft.notes.size() != expect:
		return _fail("editor notes %s vs %s" % [tap.draft.notes.size(), expect])
	if str(tap.draft.song_id) != "song_01":
		return _fail("editor song id %s" % tap.draft.song_id)
	tap.queue_free()
	await get_tree().process_frame
	print("tool ok")
	return true


func _title_button() -> bool:
	var title: Control = load("res://scenes/title/Title.tscn").instantiate()
	get_tree().root.add_child(title)
	var button := title.get_node_or_null("VBox/ChartTapButton") as Button
	if button == null or button.text != "听歌打点":
		return _fail("title button")
	ChartLoader.arm_preview(TEST_WAV)
	get_tree().set_meta(ChartLoader.OVERRIDE_META, TEST_WAV)
	ChartLoader.clear_run_override(get_tree())
	if ChartLoader.pending_preview != "":
		return _fail("preview not cleared")
	if get_tree().has_meta(ChartLoader.OVERRIDE_META):
		return _fail("override meta remains")
	title.queue_free()
	print("title ok")
	return true


func _game_preview() -> bool:
	var kiss := WavLib.load_file(KISS_WAV)
	if kiss == null:
		return _fail("kiss wav")
	var draft = DraftLib.new()
	draft.song_id = "tap_kiss"
	draft.title = "试玩探针"
	draft.audio = KISS_WAV
	draft.duration_sec = maxf(kiss.get_length(), 0.2)
	draft.bpm = 120.0
	if draft.place(minf(0.1, draft.duration_sec * 0.5), "low", 0.0) != "":
		return _fail("kiss note")
	var path := "user://charts/kiss_probe.json"
	var err: String = draft.save_to(path)
	if err != "":
		return _fail("kiss chart %s" % err)
	ChartLoader.arm_preview(path)
	var first := await _spin_game()
	if not bool(first.get("ok", false)):
		return _fail("preview game")
	if str(ChartLoader.chart.get("songId", "")) != "tap_kiss":
		return _fail("preview song %s" % ChartLoader.chart.get("songId", ""))
	if ChartLoader.pending_preview != "":
		return _fail("preview flag stuck")
	if first["length"] > 5.0:
		return _fail("custom audio fell back to the long test tone (%s)" % first["length"])
	var retry := await _spin_game()
	if not bool(retry.get("ok", false)):
		return _fail("retry game")
	if str(ChartLoader.chart.get("songId", "")) != "tap_kiss":
		return _fail("retry lost preview %s" % ChartLoader.chart.get("songId", ""))
	ChartLoader.clear_run_override(get_tree())
	var normal := await _spin_game()
	if not bool(normal.get("ok", false)):
		return _fail("default game")
	if str(ChartLoader.chart.get("songId", "")) != "song_01":
		return _fail("default song %s" % ChartLoader.chart.get("songId", ""))
	if float(normal["length"]) < 30.0:
		return _fail("default audio %s" % normal["length"])
	print("preview ok")
	return true


func _spin_game() -> Dictionary:
	var game: Node = load("res://scenes/game/Game.tscn").instantiate()
	get_tree().root.add_child(game)
	var player := game.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	var length := 0.0
	if player != null and player.stream != null:
		length = player.stream.get_length()
	var song := str(ChartLoader.chart.get("songId", ""))
	GameClock.stop()
	game.queue_free()
	await get_tree().process_frame
	return {"ok": not song.is_empty(), "song": song, "length": length}


func _shots() -> bool:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var tap: Control = load("res://scenes/tools/ChartTap.tscn").instantiate()
	get_tree().root.add_child(tap)
	await get_tree().process_frame
	if not tap.load_audio_path(TEST_WAV):
		return _fail("shot audio")
	tap._snap.button_pressed = true
	tap._div.selected = 2
	for pair in [[4.0, "low"], [7.0, "high"], [10.0, "pit"], [13.0, "buddy"], [16.5, "platform"]]:
		tap.seek_seconds(float(pair[0]))
		if tap.place_type(str(pair[1])) != "":
			return _fail("shot place")
	tap.seek_seconds(8.0)
	await get_tree().process_frame
	if not await _grab(SHOT_DIR + "/chart_tap.png"):
		return false
	tap.queue_free()
	print("shots ok")
	return true


func _grab(path: String) -> bool:
	for _i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.get_width() < 32 or img.get_height() < 32:
		return _fail("empty screenshot %s" % path)
	var sample := img.get_pixel(img.get_width() / 2, img.get_height() / 2)
	if sample.r < 0.02 and sample.g < 0.02 and sample.b < 0.02:
		return _fail("black screenshot %s" % path)
	img.save_png(path)
	print("shot %s %sx%s" % [path, img.get_width(), img.get_height()])
	return true


func _fail(msg: String) -> bool:
	push_error(msg)
	print("FAIL: ", msg)
	return false
