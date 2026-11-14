extends RefCounted
## UI string lookup. Owner: 04-client.
## Order: data/text/<locale>.json "strings" (01-owned, read-only) -> UI fallback table below -> key.
## UI keys use the `ui.` prefix; 01 is asked to copy them into data/text (coordination/requests/04-client-to-01-director.md).

const FALLBACK_KO := {
	"ui.title": "빵집 기사단: 곰팡이 디펜스",   # Q3 working title (same as data/text since 01 a262640)
	"ui.subtitle": "빵집 마을을 지키고 곰팡이 둥지를 부숴라",
	"ui.play": "시작",
	"ui.map_hint": "전장 · 눌러서 둘러보기",
	"ui.map_scouting": "정찰 중 · 영웅 버튼으로 복귀",
	"ui.follow_hero": "영웅",
	"world.flour_mill": "제분소",
	"world.flour_store": "밀가루 창고",
	"ui.continue": "이어하기",
	"ui.settings": "설정",
	"ui.back": "뒤로",
	"ui.close": "닫기",
	"ui.select_round": "라운드 선택",
	"ui.locked": "잠김",
	"ui.round_n": "%d",
	"ui.pause": "일시정지",
	"ui.paused": "일시정지됨",
	"ui.resume": "계속하기",
	"ui.retry": "다시하기",
	"ui.next": "다음 라운드",
	"ui.menu": "메뉴",
	"ui.victory": "승리!",
	"ui.defeat": "패배",
	"ui.time": "시간",
	"ui.kills": "처치",
	"ui.reward": "보상",
	"ui.first_clear": "첫 클리어 보너스!",
	"ui.worker": "견습생",
	"ui.wave": "웨이브 %d/%d",
	"ui.wave_next": "다음 %d초",
	"ui.boss": "보스",
	"ui.respawn": "부활 %d초",
	"ui.full": "가득",
	"ui.max": "최대",
	"ui.fps_cap": "프레임 제한",
	"ui.sfx": "효과음",
	"ui.music": "음악",
	"ui.show_damage": "피해 숫자",
	"ui.screen_shake": "화면 흔들림",
	"ui.on": "켜기",
	"ui.off": "끄기",
	"ui.quit_confirm": "게임을 종료할까요?",
	"ui.quit": "종료",
	"ui.cancel": "취소",
	"ui.save_recovered": "저장 파일이 손상되어 백업에서 복구했습니다.",
	"notice.content_migrated": "업데이트로 강화 상한이 바뀌어 {levels}개 레벨이 조정되었고 {coins} 골드를 돌려드렸습니다.",   # 01 D32 (data wins)
	"ui.coins": "골드",
	"ui.star_win": "승리",
	"ui.star_base_hp": "기지 체력 %d%% 이상",
	"ui.star_base_hp_any": "기지 체력 지키기",
	"ui.star_time": "%d초 안에 클리어",
	"ui.star_time_any": "빠르게 클리어",
	"ui.credits": "크레딧",
	"ui.font_credit": "글꼴: 갈무리 © 이민서, SIL Open Font License 1.1",
	"toast.not_enough_gold": "밀가루가 부족합니다",
	"toast.army_full": "병력이 가득 찼습니다",
	"toast.on_cooldown": "아직 준비 중입니다",
	"toast.not_enough_mana": "기력이 부족합니다",
	"toast.hero_dead": "영웅이 부활 중입니다",
	"toast.wave_incoming": "적 웨이브가 몰려옵니다!",
	"toast.boss_incoming": "강력한 보스가 다가옵니다!",
	"toast.worker_max": "견습생이 최대입니다",
	"toast.counterattack": "적이 반격합니다!",
	"banner.first_wave_cleared": "첫 웨이브 격파!",
	"ui.upgrades": "강화",
	"ui.upgrade_buy": "강화",
	"ui.upgrade_ok": "%s Lv %d 완료!",
	"ui.upgrade_not_enough": "골드가 %d 부족합니다",
	"ui.upgrade_max": "이미 최대 레벨입니다",
	"ui.upgrade_save_failed": "저장하지 못했습니다. 골드와 레벨은 그대로입니다",
	"ui.upgrade_save_uncertain": "저장 결과를 확인하지 못했습니다. 다시 실행해 확인하세요",
	"ui.upgrade_unavailable": "강화 기능 준비 중입니다",
	"ui.upgrade_locked": "아직 열리지 않은 강화입니다",
	"ui.upgrade_error": "강화하지 못했습니다. 다시 시도해 주세요.",
	"ui.upgrade_none": "강화할 항목이 없습니다",
}

## English UI fallbacks for keys not yet in data/text/en.json (01 asked to add them; data wins).
const FALLBACK_EN := {
	"ui.map_hint": "Battlefield · tap or drag to scout",
	"ui.map_scouting": "Scouting · Hero returns to the action",
	"ui.follow_hero": "Hero",
	"world.flour_mill": "Flour Mill",
	"world.flour_store": "Flour Store",
	"notice.content_migrated": "An update changed upgrade limits: {levels} levels were adjusted and {coins} gold was refunded.",
	"ui.title": "Bakery Knights: Mold Defense",
	"toast.counterattack": "Enemy counterattack!",
	"banner.first_wave_cleared": "First wave broken!",
	"ui.upgrades": "Upgrades",
	"ui.upgrade_buy": "Upgrade",
	"ui.upgrade_ok": "%s Lv %d done!",
	"ui.upgrade_not_enough": "Need %d more gold",
	"ui.upgrade_max": "Already at max level",
	"ui.upgrade_save_failed": "Could not save. Gold and level unchanged",
	"ui.upgrade_save_uncertain": "Save result unknown. Restart to check",
	"ui.upgrade_unavailable": "Upgrades are coming soon",
	"ui.upgrade_locked": "This upgrade is not unlocked yet",
	"ui.upgrade_error": "Upgrade failed. Please try again.",
	"ui.upgrade_none": "Nothing to upgrade yet",
	"ui.star_win": "Win",
	"ui.star_base_hp": "Base HP %d%%+",
	"ui.star_base_hp_any": "Protect your base",
	"ui.star_time": "Clear within %ds",
	"ui.star_time_any": "Clear quickly",
	"ui.credits": "Credits",
	"ui.font_credit": "Font: Galmuri © Lee Minseo, SIL Open Font License 1.1",
}

static var _strings: Dictionary = {}
static var _loaded_locale := ""

## "" = auto: Korean device locale → ko, anything else → en (if en.json exists), else ko.
static func load_locale(locale := "") -> void:
	if locale == "":
		locale = "ko" if OS.get_locale_language() == "ko" or not FileAccess.file_exists("res://data/text/en.json") else "en"
	_strings = {}
	_loaded_locale = locale
	var path := "res://data/text/%s.json" % locale
	if not FileAccess.file_exists(path):
		return
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		push_warning("[UiText] parse error in " + path)
		return
	if j.data is Dictionary and j.data.get("strings") is Dictionary:
		_strings = j.data.strings

static func t(key: String, fallback := "") -> String:
	if _loaded_locale == "":
		load_locale()
	if _strings.has(key):
		return str(_strings[key])
	if _loaded_locale == "en" and FALLBACK_EN.has(key):
		return FALLBACK_EN[key]
	if FALLBACK_KO.has(key):
		return FALLBACK_KO[key]
	return fallback if fallback != "" else key

static func has(key: String) -> bool:
	if _loaded_locale == "":
		load_locale()
	return _strings.has(key) or FALLBACK_KO.has(key) or (_loaded_locale == "en" and FALLBACK_EN.has(key))

## Display name for a content id: tries `<kind>.<id>.name`, then the engine-supplied name.
static func name_of(kind: String, id: String, engine_name := "") -> String:
	var k := "%s.%s.name" % [kind, id]
	if has(k):
		return t(k)
	return engine_name if engine_name != "" else id
