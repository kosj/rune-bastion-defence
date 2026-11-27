# Rune Bastion: 작업 지침

Godot 4.7.2 (Compatibility 렌더러) 3D 타워 디펜스입니다. 웹(데스크톱·모바일)이 주 배포 대상입니다. `main`에 푸시하면 CI가 빌드해 GitHub Pages에 올립니다. 자세한 구조는 README, 로딩과 성능은 `docs/PERFORMANCE.md`에 있습니다.

## 자주 쓰는 명령
- 임포트(새 파일·새 `class_name` 뒤 필수): `godot --headless --path . --import`
- 웹 빌드 전체: `./tools/build_web.sh`. 빠른 확인은 `godot --headless --path . --export-release "Web" build/web/index.html` → `python3 tools/split_pck.py build/web/index.pck` → `python3 tools/package_web.py build/web build/web_hosted --build-id t1`
- 브라우저 타임라인: `python3 tools/browser_test.py build/web_hosted /tmp/x 1280 720 --play --throttle=20 --nosw` (`--early`, `--revisit`)
- 검사(모두 CI에서도 돎):
  - `python3 tools/i18n_build.py --check`: 모든 한국어 문자열에 영어가 있는지
  - `python3 tools/make_fonts.py --check`: 쓰인 글자가 폰트에 있는지
  - `tools/check_chunks.sh`: 화면이 기다리지 않는 청크의 에셋을 부르는지
  - `tools/check_sheets.sh`: 모든 팝업이 닫기 버튼·바깥 탭·Esc로 닫히는지(가로·세로)
  - `tools/check_spawn.sh`: 레벨마다 영웅 시작 위치가 부지·강·소품과 겹치지 않는지
  - 셀프 테스트: `test_runner.tscn -- selftest=1`
  - AI 플레이: `LEVELS="0 4 8" tools/balance.sh smart 0`
  - 밸런스 곡선: `tools/check_balance.sh`(웨이브가 `docs/BALANCE.md`의 곡선을 따르는지)
  - 엔진 클래스: `python3 tools/engine/check_classes.py <godot 4.7.2 소스>`
  - 브라우저 스모크: `python3 tools/browser_test.py build/web_hosted /tmp/s 1280 720 --play --nosw --smoke`
- 전투 중 셰이더 컴파일 수: `DISPLAY=:77 tools/perf/shader_compiles.sh 2 1`(0이어야 함. 원인 찾기는 `GLSHIM_DUMP=<폴더>`)
- UI 점검: `DISPLAY=:77 tools/ui_shots.sh /tmp/ui 2`(16개 화면 × PC·폰 세로·폰 가로)
- 화면 확인: `DISPLAY=:77 godot --path . --rendering-driver opengl3 --resolution 1600x900 res://scenes/test_runner.tscn -- mode=shots ...`(옵션은 `scripts/tools/test_runner.gd` 머리말)

## 지켜야 할 규칙
- **다운로드 청크**: 에셋이 어느 청크에 들어가는지는 `scripts/data/pack_chunks.gd` 한 곳에서 정합니다. 청크 에셋은 `Content.ensure` / `Content.level_needs` / `Tower.model_ready`로 확인한 뒤에만 불러옵니다. core(타이틀에 필요한 것)는 작게 유지합니다. `budget_mb`를 넘으면 빌드가 멈춥니다.
- **에셋 로더에서 '없음'을 캐시하지 않습니다**. 청크가 나중에 도착합니다.
- **`await` 뒤에는 `is_inside_tree()`와 `Game._busy`를 확인합니다**. 씬이 바뀌는 중일 수 있습니다.
- **품질을 떨어뜨리는 최적화는 하지 않습니다.**
  - 텍스처나 메시를 줄일 때는 가장 가까운 줌, 고해상도에서 전후를 비교합니다(`texab=` + `tools/texab_cmp.py`, 50dB 이상, 8단계 넘게 바뀐 픽셀 0.1% 미만).
  - 노멀·ORM·건물 albedo의 절반 축소는 이미 기준에 못 미쳤습니다.
- **메시 예산은 화면 오차로 정합니다**: `tools/pipeline/rebuild_assets.sh`의 `e1.0`(가장 가까운 줌에서 원본과 1px, 폰 `e1.6`). 숫자를 손으로 낮추지 않습니다(MultiMesh 소품만 `e1.0/상한`). 모델을 다시 생성하면 `ALBEDO_REF`로 이전 색을 유지합니다. GLB를 바꾸면 추출된 `<이름>_albedo/normal/orm.png*`를 지우고 다시 임포트합니다(내용이 같은 GLB는 `.godot/imported/<이름>.glb-*`도 지워야 다시 추출됩니다).
- **영웅·궁수·마법사 캐릭터 GLB를 다시 만들면** 손 모양 단계(`tools/pipeline/hand_pose.py`, `rebuild_assets.sh` 끝)도 거쳐야 합니다. 안 그러면 손가락이 다시 쫙 펴집니다.
- **경량 엔진 템플릿**(`tools/engine/web_template.env`)은 물리·내비게이션·XR·네트워크·RegEx·mp3 등을 뺍니다. 그런 클래스를 쓰려면 env에서 해당 옵션을 지웁니다. 그러면 CI가 템플릿을 다시 빌드합니다. 엔진 소스 수정은 `tools/engine/patches/*.patch`(파일 머리에 이유)로 두고, `build_template.sh`가 적용합니다. 패치를 바꾸면 템플릿 캐시 키가 바뀌어 CI가 다시 빌드합니다(~40분, 실패하면 공식 템플릿으로 배포). `python3 tools/engine/check_classes.py <godot 소스>`가 빠진 클래스 사용을 잡습니다.
- **웹에는 셰이더 바이너리 캐시(PSO 캐시)가 없습니다**. 전투에 처음 나오는 것은 `ShaderWarmup`(`scripts/level/shader_warmup.gd`)이 로딩 화면 뒤에서 한 번씩 그려 컴파일해 둡니다. 새 이펙트·투사체·조명을 넣으면 워밍업에도 넣고, 위 명령으로 전투 중 컴파일이 0인지 확인합니다(`docs/PERFORMANCE.md` 7절).
- **게시 전 브라우저 스모크 테스트**(`browser_test.py --smoke`)가 실패하면 배포되지 않습니다.
- **웨이브·적 체력·현상금을 바꾸면** `docs/BALANCE.md`의 순서를 따릅니다: `tools/balance/shape_waves.py`로 곡선에 맞추고, `tools/balance/sim.py`(expert·casual x 보통·영웅·쉬움)로 확인하고, 튀는 곳은 `calibrate.py`로 `tuning.json`에 반영합니다. 웨이브 줄을 손으로만 고치면 CI(`check_balance.sh`)에서 걸립니다.
- **텍스트를 추가하면** 영어를 `tools/i18n/en_*.txt`에, 일본어를 `tools/i18n/ja_*.txt`에 넣고 `python3 tools/i18n_build.py`를 돌립니다(`lang_en.gd`·`lang_ja.gd`는 생성 파일, 일본어가 빠지면 영어로 나옴). 그다음 `python3 tools/make_fonts.py`로 폰트를 다시 만듭니다. CI가 `i18n_build.py --check`로 빠진 영어를 잡습니다.
- **타이틀 디오라마를 바꾸면** `tools/render_backdrops.sh`(화면 필요, Xvfb)로 타이틀 그림을 다시 렌더링합니다.
- **UI**(`docs/UI.md`):
  - 팝업은 `UI.sheet()`로 만들고, 내용 폭은 `UI.sheet_w()`에서 계산합니다. 고정 폭을 쓰지 않습니다.
  - `on_close`에 넘기는 람다는 시트를 인자로 받습니다(`func(s): UI.dismiss(s)`). GDScript 람다는 지역 변수를 만들어질 때의 값으로 잡아서, 시트를 담을 변수를 미리 잡으면 null이 됩니다(이 때문에 메뉴 팝업이 닫히지 않았음).
  - 버튼은 역할로 고릅니다: 진행은 `primary`(금, 오른쪽), 그 밖은 `secondary`/`ghost`.
  - 리본은 결과 화면에만 씁니다.
  - 전투 화면의 알림 카드는 `hud.add_note()`로 알림 열에 넣고, 맵을 따라다니는 버튼은 `hud.markers`에 넣습니다(패널 아래 층). 카드 위치를 `position`으로 애니메이션하지 않습니다(높이가 offset에 박힘).
  - 새 화면은 `Game.tall`(세로)에서도 배치하고, `tools/ui_shots.sh`로 PC·폰 세로·폰 가로를 찍어 확인합니다.
- **커밋 메시지·문서**: 저장소 문서는 한국어로 씁니다.
