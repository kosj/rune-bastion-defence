# Rune Bastion: 작업 지침

Godot 4.7.2 (Compatibility 렌더러) 3D 타워 디펜스입니다. 웹(데스크톱·모바일)이 주 배포 대상입니다. `main`에 푸시하면 CI가 빌드해 GitHub Pages에 올립니다. 자세한 구조는 README, 로딩과 성능은 `docs/PERFORMANCE.md`에 있습니다.

## 자주 쓰는 명령
- 임포트(새 파일·새 `class_name` 뒤 필수): `godot --headless --path . --import`
- 웹 빌드 전체: `./tools/build_web.sh`. 빠른 확인은 `godot --headless --path . --export-release "Web" build/web/index.html` → `python3 tools/split_pck.py build/web/index.pck` → `python3 tools/package_web.py build/web build/web_hosted --build-id t1`
- 브라우저 타임라인: `python3 tools/browser_test.py build/web_hosted /tmp/x 1280 720 --play --throttle=20 --nosw` (`--early`, `--revisit`)
- 검사(모두 CI에서도 돎):
  - `python3 tools/make_fonts.py --check`: 쓰인 글자가 폰트에 있는지
  - `tools/check_chunks.sh`: 화면이 기다리지 않는 청크의 에셋을 부르는지
  - 셀프 테스트: `test_runner.tscn -- selftest=1`
  - AI 플레이: `LEVELS="0 4 8" tools/balance.sh smart 0`
  - 엔진 클래스: `python3 tools/engine/check_classes.py <godot 4.7.2 소스>`
  - 브라우저 스모크: `python3 tools/browser_test.py build/web_hosted /tmp/s 1280 720 --play --nosw --smoke`
- 화면 확인: `DISPLAY=:77 godot --path . --rendering-driver opengl3 --resolution 1600x900 res://scenes/test_runner.tscn -- mode=shots ...`(옵션은 `scripts/tools/test_runner.gd` 머리말)

## 지켜야 할 규칙
- **다운로드 청크**: 에셋이 어느 청크에 들어가는지는 `scripts/data/pack_chunks.gd` 한 곳에서 정합니다. 청크 에셋은 `Content.ensure` / `Content.level_needs` / `Tower.model_ready`로 확인한 뒤에만 불러옵니다. core(타이틀에 필요한 것)는 작게 유지합니다. `budget_mb`를 넘으면 빌드가 멈춥니다.
- **에셋 로더에서 '없음'을 캐시하지 않습니다**. 청크가 나중에 도착합니다.
- **`await` 뒤에는 `is_inside_tree()`와 `Game._busy`를 확인합니다**. 씬이 바뀌는 중일 수 있습니다.
- **품질을 떨어뜨리는 최적화는 하지 않습니다.**
  - 텍스처나 메시를 줄일 때는 가장 가까운 줌, 고해상도에서 전후를 비교합니다(`texab=` + `tools/texab_cmp.py`, 50dB 이상, 8단계 넘게 바뀐 픽셀 0.1% 미만).
  - 노멀·ORM·건물 albedo의 절반 축소는 이미 기준에 못 미쳤습니다.
- **경량 엔진 템플릿**(`tools/engine/web_template.env`)은 물리·내비게이션·XR·네트워크·RegEx·mp3 등을 뺍니다. 그런 클래스를 쓰려면 env에서 해당 옵션을 지웁니다. 그러면 CI가 템플릿을 다시 빌드합니다. `python3 tools/engine/check_classes.py <godot 소스>`가 빠진 클래스 사용을 잡습니다.
- **게시 전 브라우저 스모크 테스트**(`browser_test.py --smoke`)가 실패하면 배포되지 않습니다.
- **텍스트를 추가하면** `python3 tools/make_fonts.py`로 폰트를 다시 만듭니다.
- **타이틀 디오라마를 바꾸면** `tools/render_backdrops.sh`(화면 필요, Xvfb)로 타이틀 그림을 다시 렌더링합니다.
- **커밋 메시지·문서**: 저장소 문서는 한국어로 씁니다.
