//
//  HSBTVOSConnectionConstants.m
//  HSBWatchCompanion
//

#import "HSBTVOSConnectionConstants.h"

// -- Notifications --------------------------------------------------------
NSString * const HSBTVOSConnectionStateNotification = @"HSBTVOSConnectionStateNotification";
NSString * const HSBTVOSStateUpdatedNotification = @"HSBTVOSStateUpdatedNotification";
NSString * const HSBIPTVFavoritesUpdatedNotification = @"HSBIPTVFavoritesUpdatedNotification";
NSString * const HSBIPTVCatalogUpdatedNotification = @"HSBIPTVCatalogUpdatedNotification";
NSString * const HSBIPTVStateUpdatedNotification = @"HSBIPTVStateUpdatedNotification";
NSString * const HSBIPTVImportResultUpdatedNotification = @"HSBIPTVImportResultUpdatedNotification";
NSString * const HSBIPTVSourcesUpdatedNotification = @"HSBIPTVSourcesUpdatedNotification";
NSString * const HSBIPTVEPGBindingsUpdatedNotification = @"HSBIPTVEPGBindingsUpdatedNotification";
NSString * const HSBIPTVEPGCandidatesUpdatedNotification = @"HSBIPTVEPGCandidatesUpdatedNotification";

// -- Action Constants -----------------------------------------------------
HSBRemoteSimulateAction const HSBRemoteSimulateActionUnknown = @"unknown";
HSBRemoteSimulateAction const HSBRemoteSimulateActionUp = @"up";
HSBRemoteSimulateAction const HSBRemoteSimulateActionDown = @"down";
HSBRemoteSimulateAction const HSBRemoteSimulateActionLeft = @"left";
HSBRemoteSimulateAction const HSBRemoteSimulateActionRight = @"right";
HSBRemoteSimulateAction const HSBRemoteSimulateActionSelect = @"select";
HSBRemoteSimulateAction const HSBRemoteSimulateActionMenu = @"menu";
HSBRemoteSimulateAction const HSBRemoteSimulateActionPlay = @"play";
HSBRemoteSimulateAction const HSBRemoteSimulateActionPause = @"pause";
HSBRemoteSimulateAction const HSBRemoteSimulateActionStop = @"stop";

HSBRemoteSimulateAction const HSBRemoteSimulateActionOpenPlayer = @"open_player";
HSBRemoteSimulateAction const HSBRemoteSimulateActionClosePlayer = @"close_player";
HSBRemoteSimulateAction const HSBRemoteSimulateActionSeekRelative = @"seek_relative";
HSBRemoteSimulateAction const HSBRemoteSimulateActionSeekPercent = @"seek_percent";
HSBRemoteSimulateAction const HSBRemoteSimulateActionSetRate = @"set_rate";
HSBRemoteSimulateAction const HSBRemoteSimulateActionSeekForward = @"seek_forward";
HSBRemoteSimulateAction const HSBRemoteSimulateActionSeekBackward = @"seek_backward";
HSBRemoteSimulateAction const HSBRemoteSimulateActionSeekAbsolute = @"player_seek";
HSBRemoteSimulateAction const HSBRemoteSimulateActionToggleSubtitle = @"player_toggle_subtitle";
HSBRemoteSimulateAction const HSBRemoteSimulateActionVolumeUp = @"volume_up";
HSBRemoteSimulateAction const HSBRemoteSimulateActionVolumeDown = @"volume_down";
HSBRemoteSimulateAction const HSBRemoteSimulateActionSetVolume = @"set_volume";
HSBRemoteSimulateAction const HSBRemoteSimulateActionToggleMute = @"toggle_mute";
HSBRemoteSimulateAction const HSBRemoteSimulateActionSwitchAudioTrack = @"switch_audio_track";

HSBRemoteSimulateAction const HSBRemoteSimulateActionOpenUrl = @"open_url";
HSBRemoteSimulateAction const HSBRemoteSimulateActionPageBack = @"page_back";
HSBRemoteSimulateAction const HSBRemoteSimulateActionPageForward = @"page_forward";
HSBRemoteSimulateAction const HSBRemoteSimulateActionPageReload = @"page_reload";
HSBRemoteSimulateAction const HSBRemoteSimulateActionPageHome = @"page_home";

HSBRemoteSimulateAction const HSBRemoteSimulateActionUpdateHomeJson = @"update_home_json";
HSBRemoteSimulateAction const HSBRemoteSimulateActionExecuteJS = @"execute_js";
HSBRemoteSimulateAction const HSBRemoteSimulateActionPdfDraw = @"pdf_draw";

HSBRemoteSimulateAction const HSBRemoteSimulateActionMacTap = @"mac_tap";
HSBRemoteSimulateAction const HSBRemoteSimulateActionMacPan = @"mac_pan";
HSBRemoteSimulateAction const HSBRemoteSimulateActionMacScroll = @"mac_scroll";
HSBRemoteSimulateAction const HSBRemoteSimulateActionMacDrag = @"mac_drag";

HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVGetFavorites = @"get_favorites";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVPlayChannel = @"play_channel";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVAddFavorite = @"add_favorite";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVDeleteFavorite = @"delete_favorite";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVEpg = @"iptv_epg";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVChannels = @"iptv_channels";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVRefresh = @"iptv_refresh";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVImportSource = @"iptv_import_source";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVImportEPG = @"iptv_import_epg";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVFileChunk = @"iptv_file_chunk";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVGetSources = @"iptv_get_sources";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVDeleteSource = @"iptv_delete_source";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVRefreshSource = @"iptv_refresh_source";
HSBRemoteSimulateAction const HSBRemoteSimulateActionChannelUp = @"channel_up";
HSBRemoteSimulateAction const HSBRemoteSimulateActionChannelDown = @"channel_down";
HSBRemoteSimulateAction const HSBRemoteSimulateActionDigit = @"digit";

HSBRemoteSimulateAction const HSBRemoteSimulateActionTranslate = @"translate";
HSBRemoteSimulateAction const HSBRemoteSimulateActionTranslateBlocks = @"translate_blocks";
HSBRemoteSimulateAction const HSBRemoteSimulateActionTranslationResult = @"translation_result";
HSBRemoteSimulateAction const HSBRemoteSimulateActionTranslationBlocksResult = @"translation_blocks_result";

HSBRemoteSimulateAction const HSBRemoteSimulateActionSyncProgress = @"sync_progress";
HSBRemoteSimulateAction const HSBRemoteSimulateActionSyncFavorites = @"sync_favorites";

// -- Payload Keys ---------------------------------------------------------
NSString * const HSBRemotePayloadKeyAction = @"action";
NSString * const HSBRemotePayloadKeyValue = @"value";
NSString * const HSBRemotePayloadKeySeconds = @"seconds";
NSString * const HSBRemotePayloadKeyVolume = @"volume";
NSString * const HSBRemotePayloadKeyMuted = @"muted";
NSString * const HSBRemotePayloadKeyDigit = @"digit";
NSString * const HSBRemotePayloadKeyTrackIndex = @"trackIndex";
NSString * const HSBRemotePayloadKeyDx = @"dx";
NSString * const HSBRemotePayloadKeyDy = @"dy";
NSString * const HSBRemotePayloadKeyMode = @"mode";
NSString * const HSBRemotePayloadKeyState = @"state";
NSString * const HSBRemotePayloadKeyUrl = @"url";
NSString * const HSBRemotePayloadKeyScript = @"script";
NSString * const HSBRemotePayloadKeyType = @"type";
NSString * const HSBRemotePayloadKeyX = @"x";
NSString * const HSBRemotePayloadKeyY = @"y";
NSString * const HSBRemotePayloadKeyColor = @"color";
NSString * const HSBRemotePayloadKeyWidth = @"width";
NSString * const HSBRemotePayloadKeyPayload = @"payload";
NSString * const HSBRemotePayloadKeyChannel = @"channel";
NSString * const HSBRemotePayloadKeyId = @"id";
NSString * const HSBRemotePayloadKeyIndex = @"index";
NSString * const HSBRemotePayloadKeyTimestamp = @"timestamp";
NSString * const HSBRemotePayloadKeyRequestId = @"requestId";
NSString * const HSBRemotePayloadKeyResult = @"result";
NSString * const HSBRemotePayloadKeyBlocks = @"blocks";
NSString * const HSBRemotePayloadKeyTranslationMap = @"translationMap";
NSString * const HSBRemotePayloadKeyChannels = @"channels";
NSString * const HSBRemotePayloadKeyCurrentTime = @"currentTime";
NSString * const HSBRemotePayloadKeyDuration = @"duration";
NSString * const HSBRemotePayloadKeyHidden = @"hidden";
NSString * const HSBRemotePayloadKeyPlaybackState = @"playbackState";
NSString * const HSBRemotePayloadKeyTitle = @"title";
NSString * const HSBRemotePayloadKeyContent = @"content";
NSString * const HSBRemotePayloadKeyCode = @"code";
NSString * const HSBRemotePayloadKeyMessage = @"message";
NSString * const HSBRemotePayloadKeyError = @"error";
NSString * const HSBRemotePayloadKeyText = @"text";
NSString * const HSBRemotePayloadKeySourceLanguage = @"sourceLanguage";
NSString * const HSBRemotePayloadKeyTargetLanguage = @"targetLanguage";
NSString * const HSBRemotePayloadKeyRemoteAction = @"remoteAction";
NSString * const HSBRemotePayloadKeyPressType = @"pressType";
NSString * const HSBRemotePayloadKeyName = @"name";
NSString * const HSBRemotePayloadKeyStream = @"stream";
NSString * const HSBRemotePayloadKeyLogo = @"logo";
NSString * const HSBRemotePayloadKeyGroup = @"group";

// -- PDF & Drawing Constants ---------------------------------------------
NSString * const HSBRemoteDrawTypeClear = @"clear";
NSString * const HSBRemoteDrawTypeUndo = @"undo";
NSString * const HSBRemoteDrawTypeEraser = @"eraser";
NSString * const HSBRemoteDrawTypeBegan = @"began";
NSString * const HSBRemoteDrawTypeMoved = @"moved";
NSString * const HSBRemoteDrawTypeChanged = @"changed";
NSString * const HSBRemoteDrawTypeEnded = @"ended";
NSString * const HSBRemoteDrawColorRed = @"#FF0000";
NSString * const HSBRemoteDrawColorBlue = @"blue";
NSString * const HSBRemoteDrawColorGreen = @"green";
NSString * const HSBRemoteDrawColorYellow = @"yellow";
NSString * const HSBRemoteDrawColorWhite = @"white";
NSString * const HSBRemoteDrawColorBlack = @"black";

// -- Notification UserInfo Keys ------------------------------------------
NSString * const HSBConnectionStateKeyMessage = @"message";
NSString * const HSBConnectionStateKeyState = @"state";
