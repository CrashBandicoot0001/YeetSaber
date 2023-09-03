# The main menu is shown at game start or pause on an OQ_UI2DCanvas
# some logic is in the BeepSaber_Game.gd to set the correct state
#
# This file also contains the logic to load a beatmap in the format that
# normal Beat Saber uses. So you can load here custom beat saber songs too
extends Panel

# emitted when a new map is selected
signal map_changed(map_info);
# emitted when a new map difficulty is selected
signal difficulty_changed(map_info,diff_name,diff_rank);
# emitted when the settings button is pressed
signal settings_requested()

# we need the main game class here to trigger game start/restart/continue
var _beepsaber = null;
var _cover_file_load_sw := StopwatchFactory.create("cover_file_load",10,true)
var _cover_texture_create_sw := StopwatchFactory.create("cover_texture_create",10,true)

@onready var playlist_selector := $PlaylistSelector
@onready var _bg_img_loader := preload("res://game/scripts/BackgroundImgLoader.gd").new()

@onready var cover = $cover
@onready var songs_menu = $SongsMenu

enum PlaylistOptions {
	AllSongs,
	RecentlyAdded,
	MostPlayed
}
const PLAYLIST_ITEMS = {
	PlaylistOptions.AllSongs : "All Songs",
	PlaylistOptions.RecentlyAdded : "Recently Added",
	PlaylistOptions.MostPlayed : "Most Played"
}

func initialize(beepsaber_game):
	_beepsaber = beepsaber_game;



var path = "res://game/data/maps/";
var dlpath = str(OS.get_system_dir(3))+"/";
#var bspath = "/sdcard/BeepSaber/";
#var bspath = "/storage/emulated/0/";
var bspath = "user://BeepSaber/";
@export var keyboard_path: NodePath;
var keyboard;

var _playlists

# [{id:<song_dir_name>, source:<path_to_song?>},...]
var _all_songs = []
var _recently_added_songs = []# newest is first, oldest is last
var _most_played_songs = []# most played is first, least played is last

func refresh_playlist():
	var id = playlist_selector.get_selected_id()
	_on_PlaylistSelector_item_selected(id)

func _load_playlists():
	
	_playlists = [];
	
	#copy sample songs to main playlist folder on first run
	var config_path = "user://config.dat"
	if not FileAccess.file_exists(config_path):
		DirAccess.make_dir_recursive_absolute(bspath+"Songs/")
		var dir = DirAccess.open(path+"Songs/")
		dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				var new_dir = path+"Songs/"+file_name;
				DirAccess.make_dir_recursive_absolute(bspath+"Songs/"+file_name)
				var copy = DirAccess.open(new_dir)
				copy.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
				var copy_file_name = copy.get_next()
				while copy_file_name != "":
					var copy_new_dir = new_dir+"/"+copy_file_name;
					print(copy_new_dir)
					dir.copy(copy_new_dir,bspath+"Songs/"+file_name+"/"+copy_file_name)
					copy_file_name = copy.get_next();
			file_name = dir.get_next();
	
	_all_songs = _discover_all_songs(bspath+"Songs/")
	var songs_with_modify_times = []
	var songs_with_play_count = []
	for song in _all_songs:
		var song_path = _song_path(song)
		var song_info = _load_song_info(song_path)
		var modified_time = FileAccess.get_modified_time(song_path)
		var play_count = PlayCount.get_total_play_count(song_info)
		songs_with_modify_times.append([modified_time,song])
		songs_with_play_count.append([play_count,song])
	
	var tuple_compare = TupleCompare.new(0,false)
	songs_with_modify_times.sort_custom(Callable(tuple_compare, "compare"))
	songs_with_play_count.sort_custom(Callable(tuple_compare, "compare"))
	_recently_added_songs = []
	_most_played_songs = []
	for tuple in songs_with_modify_times:
		_recently_added_songs.append(tuple[1])
	for tuple in songs_with_play_count:
		_most_played_songs.append(tuple[1])
	
	refresh_playlist()

# compare two tuples
# this is used to sort songs by most recently downloaded, most player, etc
class TupleCompare:
	var idx = 0
	var ascending = true
	
	func _init(idx,ascending=true):
		self.idx = idx
		self.ascending = ascending
		
	func compare(a,b):
		if ascending:
			return a[idx] < b[idx]
		else:
			return a[idx] > b[idx]
		
func _discover_all_songs(seek_path):
	var songlist = [];
	var dir = DirAccess.open(seek_path);
	if dir:
		#$Label.text+="\nOpen:"+path;
		dir.list_dir_begin() ;# TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir(): #or file_name.ends_with(".zip"):
				var new_dir = seek_path+file_name+"/";
				var song = _load_song_info(new_dir);
				if song:
					var source = seek_path.substr(bspath.length()+"Songs".length());
					songlist.append({"id":file_name,"source":source.substr(0,source.length()-1)});
				else:
					_autogen_playlists(new_dir,file_name);
			file_name = dir.get_next();
	return songlist
		
func _autogen_playlists(seek_path,name):
	var all_songs = _discover_all_songs(seek_path)
	_playlists.append({"Name":name,"Description":"Autogenerated","Songs":all_songs});

func _set_cur_playlist(songs):
	var current_id = $SongsMenu.get_selected_items()
	
	$SongsMenu.clear()
	
	var song_count = songs.size()
	for dat in songs:
		_wire_song_dat(dat);
			
	# load song covers in background thread to avoid freezing UI
	for b in range(0,$SongsMenu.get_item_count()):
		var song_md = $SongsMenu.get_item_metadata(b)
		var filepath = _song_path(song_md['id']) + song_md["info"]._coverImageFilename
		_bg_img_loader.load_texture(filepath, self, "_on_cover_loaded", [false, b])
	
	if current_id.size() > 0:
		var selected_id = current_id[0]
		if selected_id >= song_count:
			selected_id = song_count - 1
		_select_song(selected_id)

var default_song_icon = preload("res://game/data/beepsaber_logo.png")
func _wire_song_dat(dat):
	var current_song_data = {
		id=dat,
		info=_load_song_info(_song_path(dat))
		}
	$SongsMenu.add_item("%s - %s" % [current_song_data.info._songAuthorName, current_song_data.info._songName],default_song_icon)
	$SongsMenu.set_item_metadata($SongsMenu.get_item_count()-1,current_song_data)
	
func _song_path(dat):
	if dat.has("source"): #if a source is specified then it's either in the applicable downloads folder or a subfolder
		if dat.source:
			return bspath +"Songs/" + dat.source + "/" + dat.id + "/";
		else:
			#windows can handle // in a path but android can't
			return bspath +"Songs/" + dat.id + "/";
	else:
		return path + "Songs/" + dat.id + "/";
	
func _load_song_info(load_path):
	#var dir = DirAccess.new();
	var map_info = vr.load_json_file(load_path + "Info.dat");
	if (!map_info):
		map_info = vr.load_json_file(load_path + "info.dat");
		#because android is case sensitive and some maps have it lowercase, some not
		if (!map_info):
			vr.log_error("Invalid info.dat found in " + load_path);
			return false;
		
	if (map_info._difficultyBeatmapSets.size() == 0):
		vr.log_error("No _difficultyBeatmapSets in info.dat");
		return false;
	map_info._path=load_path
	return map_info;

# callback from ImageUtils when background image loading is complete. if image
# failed to load, tex will be null
func _on_cover_loaded(img_tex, filepath, is_main_cover, list_idx):
	if img_tex != null:
		if is_main_cover:
			cover.texture = img_tex
		else:
			songs_menu.set_item_icon(list_idx,img_tex)

func _load_cover(cover_path, filename):
	# read cover image data from file into a buffer
	_cover_file_load_sw.start()
	var file = FileAccess.open(cover_path+filename, FileAccess.READ)
	var img_data = null
	if file:
		img_data = file.get_buffer(file.get_length())
		file.close()
		_cover_file_load_sw.stop()
	else:
		vr.log_error('Failed to open cover image file "%s"' % cover_path+filename)
		_cover_file_load_sw.stop()
		return
		
	# parse buffer into an ImageTexture
	_cover_texture_create_sw.start()
	var tex = ImageTexture.new();
	tex.create_from_image(ImageUtils.get_img_from_buffer(img_data));
	_cover_texture_create_sw.stop()
	return tex;

func play_preview(filepath_or_buffer, start_time = 0, duration = -1, buffer_data_type_hint = 'ogg'):
	var stream = null
	if filepath_or_buffer is String:
		# get song preview data from file
		stream = AudioStreamOggVorbis.load_from_file(filepath_or_buffer)
	elif filepath_or_buffer is PackedByteArray:
		# take song preview data from buffer as-is. trust passed type hint
		stream = AudioStreamOggVorbis.load_from_buffer(filepath_or_buffer)
	else:
		vr.log_error('_play_preview() - Unsupported song preview data type %s' % typeof(filepath_or_buffer))
		return
	
	if duration == -1:
		# assume preview duration based on parsed audio length
		duration = stream.get_length()
	
	# fade out preview if ones already running
	if song_prev.playing:
		await _on_stop_prev_timeout()
	
	# start the requested preview
	if not _beepsaber.song_player.playing:
		song_prev.stream = stream;
		var song_prev_Tween = song_prev.create_tween()
		song_prev_Tween.set_trans(Tween.TRANS_LINEAR)
		song_prev_Tween.set_ease(Tween.EASE_IN_OUT)
		song_prev_Tween.tween_property(song_prev, "volume_db", 0, song_prev_transition_time)
		song_prev_Tween.play()
		
		song_prev.play(float(start_time))
		$song_prev/stop_prev.start(float(duration))

# a loaded beat map will have an info dictionary; this is a global variable here
# to later extend it to load different maps
var _map_id = null;
var _map_info = null;
var _map_path = null;

@onready var song_prev = $song_prev
var song_prev_lastid = -1
var song_prev_transition_time = 1.0

func _select_song(id):
	if id is int:
		$SongsMenu.select(id)
		$SongsMenu.ensure_current_is_visible()
		id = $SongsMenu.get_item_metadata(id)["id"]
	_map_id = id;
	_map_path = _song_path(id);
	$Delete_Button.disabled = false;
	_map_info = _load_song_info(_map_path);
	
	# notify listeners that map changed
	emit_signal("map_changed",_map_info)
	
	var play_count = PlayCount.get_total_play_count(_map_info)
	$SongInfo_Label.text = """Song Author: %s
	Song Title: %s
	Beatmap Author: %s
	Play Count: %d""" %[_map_info._songAuthorName, _map_info._songName, _map_info._levelAuthorName,play_count]

	# load cover in background to avoid freezing UI
	var filepath = _song_path(id) + _map_info._coverImageFilename
	_bg_img_loader.load_texture(filepath, self, "_on_cover_loaded", [true,-1])
	
	$DifficultyMenu.clear()
	for ii_dif in range(_map_info._difficultyBeatmapSets[0]._difficultyBeatmaps.size()):
		var current_dif_data = {
			id = ii_dif,
			Name = _map_info._difficultyBeatmapSets[0]._difficultyBeatmaps[ii_dif]._difficulty
		}
		var BMPS = _map_info._difficultyBeatmapSets[0]._difficultyBeatmaps
		$DifficultyMenu.add_item(current_dif_data.Name)
		$DifficultyMenu.set_item_metadata($DifficultyMenu.get_item_count()-1,current_dif_data)
	
	_select_difficulty(0)
	
	# preview song
	var song_filepath = _map_info._path + _map_info._songFilename
	play_preview(song_filepath,_map_info._previewStartTime,_map_info._previewDuration)

func _on_stop_prev_timeout():
	var song_prev_Tween = song_prev.create_tween()
	song_prev_Tween.set_trans(Tween.TRANS_LINEAR)
	song_prev_Tween.set_ease(Tween.EASE_IN_OUT)
	song_prev_Tween.tween_property(song_prev, "volume_db", -50, song_prev_transition_time)
	song_prev_Tween.play()
	await get_tree().create_timer(song_prev_transition_time).timeout
	song_prev.stop()


var _map_difficulty = 0
var _map_difficulty_name = ""
var _map_difficulty_noteJumpMovementSpeed = 9.0

func _select_difficulty(id):
	var item_meta = $DifficultyMenu.get_item_metadata(id)
	_map_difficulty = item_meta["id"]
	_map_difficulty_name = item_meta["Name"]
	$DifficultyMenu.select(id)
	
	# notify listeners that difficulty has changed
	var difficulty = _map_info._difficultyBeatmapSets[0]._difficultyBeatmaps[id]
	emit_signal(
		"difficulty_changed",
		_map_info,
		difficulty._difficulty,
		difficulty._difficultyRank)


func _load_map_and_start():
	if (_map_info == null): return;
		
	var set0 = _map_info._difficultyBeatmapSets[0];
	if (set0._difficultyBeatmaps.size() == 0):
		vr.log_error("No _difficultyBeatmaps in set");
		return false;
		
	var map_info = set0._difficultyBeatmaps[_map_difficulty];
	var map_filename = _map_info._path + map_info._beatmapFilename;
	var map_data = vr.load_json_file(map_filename);
	_map_difficulty_noteJumpMovementSpeed = set0._difficultyBeatmaps[_map_difficulty]["_noteJumpMovementSpeed"];
	
	if (map_data == null):
		vr.log_error("Could not read map data from " + map_filename);
	
	#print(info);

	_beepsaber.start_map(_map_info, map_data);
	
	return true;

func _on_Delete_Button_button_up():
	if $Delete_Button.text != "Sure?":
		$Delete_Button.text = "Sure?";
		await get_tree().create_timer(5).timeout;
		$Delete_Button.text = "Delete";
	else:
		$Delete_Button.text = "Delete";
		_delete_map();
	
func _delete_map():
	if _map_info:
		Highscores.remove_map(_map_info)
		PlayCount.remove_map(_map_info)
		
	if _map_path:
		var dir = DirAccess.open(_map_path);
		if dir:
			dir.list_dir_begin() ;# TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
			var current_file = dir.get_next();
			while current_file != "":
				dir.remove(_map_path+current_file);
				current_file = dir.get_next();
			dir.remove(_map_path);
			vr.log_info(_map_path+" Removed");
			_map_path = null;
			$Delete_Button.disabled = true;
		else:
			vr.log_info("Error removing song "+_map_path);
		_on_LoadPlaylists_Button_pressed()

func _ready():
	UI_AudioEngine.attach_children(self)
	if OS.get_name() != "Android":
		bspath = dlpath+"BeepSaber/";
	vr.log_info("BeepSaber search path is " + bspath);
	
	playlist_selector.clear()
	for option in PLAYLIST_ITEMS.keys():
		playlist_selector.add_item(PLAYLIST_ITEMS[option],option)
	
	keyboard = get_node(keyboard_path);
	if keyboard:
		keyboard.connect("text_input_enter", Callable(self, "_text_input_enter"))
		keyboard.connect("text_input_cancel", Callable(self, "_text_input_cancel"))

	_load_playlists();
	
	await get_tree().physics_frame
	if keyboard:
		keyboard._text_edit.connect("text_changed", Callable(self, "_text_input_changed"))
		keyboard._text_edit.connect("focus_exited", Callable(self, "_text_input_enter"))


func _on_Play_Button_pressed():
	$song_prev.stop()
	_load_map_and_start();


func _on_Exit_Button_pressed():
	get_tree().quit()


func _on_Settings_Button_pressed():
	emit_signal("settings_requested")

const READ_PERMISSION = "android.permission.READ_EXTERNAL_STORAGE"

func is_in_array(arr : Array, val):
	for e in arr:
		if (e == val): return true;
	return false;
	
func _check_required_permissions():
	if (!vr.inVR): return true; # desktop is always allowed
	
	var permissions = OS.get_granted_permissions()
	var read_storage_permission = is_in_array(permissions, READ_PERMISSION)
	
	vr.log_info(str(permissions));
	
	if !(read_storage_permission):
		return false;

	return true;

func _check_and_request_permission():
	vr.log_info("Checking permissions")

	if !(_check_required_permissions()):
		vr.log_info("Requesting permissions")
		OS.request_permissions()
		return false;
	else:
		return true;


func _on_LoadPlaylists_Button_pressed():
	# Note: this call is non-blocking; so a user has to click again after
	#       granting the permissions; we need to find a solutio for this
	#       maybe polling after the button press?
	if (_check_and_request_permission()):
		_load_playlists();


func _on_Search_Button_button_up():
	keyboard.visible=true
	keyboard._text_edit.grab_focus();

func _text_input_enter(text):
	keyboard.visible=false
func _text_input_cancel():
	keyboard.visible=false
	_clean_search()
	
func _text_input_changed():
	var text = keyboard._text_edit.text
	$Search_Button/Label.text = text
	if text == "":
		_clean_search()
		return
	var most_similar = 0.0
	for song in range(0,$SongsMenu.get_item_count()):
		var similarity = $SongsMenu.get_item_text(song).similarity(text)
		if similarity > most_similar:
			most_similar = similarity
			$SongsMenu.move_item(song,0)
	
func _clean_search():
	$SongsMenu.sort_items_by_text()
	$Search_Button/Label.text = ""

func _on_PlaylistSelector_item_selected(id):
	match id:
		PlaylistOptions.AllSongs:
			_set_cur_playlist(_all_songs)
		PlaylistOptions.MostPlayed:
			_set_cur_playlist(_most_played_songs)
		PlaylistOptions.RecentlyAdded:
			_set_cur_playlist(_recently_added_songs)
		_:
			vr.log_warning("Unsupported playlist option %s" % id)
			_set_cur_playlist(_all_songs)
