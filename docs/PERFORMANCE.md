# 로딩·성능 지침

웹 첫 로딩과 실행 성능을 다루며 측정하고 확인한 것을 정리했습니다. 가능한 것은 코드(검사 스크립트·예산·CI 단계)로 옮겼고, 이 문서는 그 규칙의 이유와 코드로 못 옮긴 판단 기준을 적습니다.

## 1. 첫 로딩 구조

```
index.html ─┬─ index.wasm (엔진, gzip 10.1MB / Brotli 6.9MB)  ┐ 둘 다 오면 엔진 시작 → 타이틀
            └─ index.pck  (core, 2.4MB)                      ┘
               이어서 차례로: index_menu.pck → index_stage1.pck → index_towers.pck → index_world.pck
```

- **청크 정의는 한 곳**: `scripts/data/pack_chunks.gd`. 어느 에셋이 어느 청크인지(경로 glob), 받는 순서, 첫 전투와 3D 타이틀에 필요한 청크, 청크별 용량 상한(`budget_mb`)이 모두 여기 있습니다. `tools/split_pck.py`(빌드), `tools/package_web.py`(페이지에 순서 전달), `scripts/autoload/content.gd`(게임)가 모두 이 파일을 읽습니다.

| 청크 | 내용 | 크기(데스크톱) | 필요한 곳 |
|---|---|---|---|
| core | 스크립트·씬·폰트·UI 키트·카엘 타이틀 그림·메뉴 효과음 5개 | 2.7MB | 타이틀 화면 |
| menu | 월드맵·레벨/타워/초상화 그림·음성·효과음·메뉴 음악·다른 영웅 타이틀 그림 | 5.5MB | 메뉴 화면들 |
| stage1 | 지형·이펙트·소품·성·포털·1레벨 타워와 병력·1지역 적·전투/보스 음악 | 36.5MB | 첫 전투(1레벨, 카엘) |
| towers | 타워 2·3레벨, 트롤 | 15.4MB | 업그레이드, 3D 타이틀 |
| world | 이후 지역의 적·보스·세라·렌·어둠 전투 음악 | 9.6MB | 나머지 전투 |

모바일 팩(ETC2 텍스처)은 같은 경로 규칙으로 core 2.7 / menu 5.5 / stage1 23.3 / towers 7.6 / world 8.5MB입니다.

- **게임 쪽 규칙**: 청크 에셋을 불러오기 전에 `Content`에 묻습니다.
  - 화면 진입: `await Content.ensure(["menu"])`(없으면 진행 막대 카드).
  - 전투 시작: `Game.goto_scene`이 `Content.level_needs(level)`를 기다립니다. 처음 하는 사람의 첫 전투(1레벨·카엘)는 `menu`+`stage1`만, 나머지는 전부 필요합니다.
  - 전투 중 업그레이드: `Tower.model_ready()`가 거짓이면 "업그레이드 준비 중" 토스트를 띄우고 막습니다.
  - 3D 타이틀: `title_3d_needs`와 고른 영웅의 청크가 모두 오면 짓습니다. 그 전에는 미리 렌더링한 그림(`assets/ui/backdrop`)을 보여 줍니다.
- **에셋 로더는 '없음'을 캐시하지 않습니다**(`Assets.scene/tex`, `Audio._get_stream`). 청크가 나중에 오기 때문입니다. 메뉴 음악처럼 아직 없는 음악은 `Audio`가 기억해 두었다가 청크가 오면 틉니다.

### 새 에셋을 넣을 때
1. 어느 화면이 처음 쓰는지 정하고 `pack_chunks.gd`의 glob에 맞는지 확인합니다. 맞는 glob이 없으면 core에 들어갑니다. core는 타이틀을 늦추므로 큰 파일을 두지 않습니다.
2. 그 화면이 그 청크를 기다리는지 확인합니다(`ensure` / `level_needs` / `model_ready`).
3. `tools/check_chunks.sh`를 돌립니다. 게임을 헤드리스로 실행하면서 일부 청크만 온 것처럼 흉내 내고(`chunks=menu:1,stage1:4`), 없는 청크의 에셋을 부르면 `CHUNK MISS`로 실패합니다. CI에서도 돕니다.
4. 빌드에서 `split_pck.py`가 늦은 청크를 경로로 참조하는 파일(예: core 씬이 stage1 모델을 직접 참조)이나 예산 초과를 발견하면 빌드를 멈춥니다.

## 2. 측정 방법과 함정

- **브라우저 타임라인**: `python3 tools/browser_test.py build/web_hosted /tmp/x 1280 720 --play --throttle=20 --nosw`
  - 게임이 찍는 `RB_MARK` 표시(`menu_first_frame`, `chunk_<이름>`, `menu_world_built`, `level_first_frame`)를 시각과 함께 출력합니다.
  - `--early`: 청크가 오기 전에 출전을 누릅니다(대기 카드 확인).
  - `--revisit`: 같은 브라우저로 다시 엽니다(서비스 워커 캐시).
- **`--nosw`를 꼭 붙이세요**: 서비스 워커가 보내는 요청은 CDP 회선 제한을 받지 않습니다. 그러면 청크가 비현실적으로 빨리 옵니다.
- **헤드리스 크롬(SwiftShader)은 ETC2를 노출하지 않습니다**: `?pack=mobile`로 모바일 팩을 강제해도 셸이 데스크톱 팩으로 되돌립니다. 검사를 빼고 강제하면 3D가 검게 나옵니다. 모바일 텍스처는 실제 기기에서 봐야 합니다.
- **크롬은 `DecompressionStream('brotli')`가 없습니다**(2026-11 기준. Safari 18.4+, Firefox 147+는 있음). 그래서 브라우저 테스트는 gzip 경로만 탑니다. Brotli 파트는 `node -e "zlib.brotliDecompressSync(...)"`로 원본과 같은지 확인합니다.
- **llvmpipe(네이티브 소프트웨어 GL)로는 끊김(hitch)을 잴 수 없습니다**: 320×180에서도 프레임당 70~150ms입니다. 첫 타워 건설처럼 '처음 불러오기' 비용(+80~240ms)은 보이지만, 셰이더 컴파일 비용은 잡음에 묻힙니다. `test_runner -- hitch=<ms>`가 느린 프레임을 기록합니다.

### 측정값 (20Mbps, 헤드리스 크롬, 데스크톱 팩)

| 시점 | 한 덩어리(초기) | core/content 2분할 | 청크 5분할(현재) |
|---|---|---|---|
| 타이틀 화면 | 41.6초 | 9.6초 | 7.3초 |
| 메뉴 화면 사용 가능 | 41.6초 | 9.6초 | 8.8초 |
| 첫 전투 시작 가능 | 41.6초 | 34.6초 | 24.9초 |
| 3D 타이틀 | 41.6초 | 36.7초 | 33.9초 |
| 전부 도착 | 41.6초 | 34.6초 | 40.6초 |

타이틀까지의 시간은 이제 엔진(wasm 10.1MB gzip)이 대부분입니다. Safari·Firefox는 Brotli(6.9MB)로 약 1.3초 더 빠릅니다.

## 3. 품질을 지키는 판단 기준

- **텍스처 해상도 A/B**: `test_runner -- texab=normal:0.5,orm:0.5|c_albedo:0.5`는 화면을 멈추고 텍스처를 줄여 다시 찍습니다. `tools/texab_cmp.py`가 PSNR과 8단계 넘게 바뀐 픽셀 비율을 냅니다. 가장 가까운 줌, 2880×1620에서 잰 결과입니다.
  - 노멀·ORM 절반: 38~46dB. 금장식 하이라이트가 뭉개져 보입니다 → **하지 않습니다**.
  - 건물 albedo 절반: 44~47dB → **하지 않습니다**.
  - 캐릭터 albedo 절반: 53~60dB. 거의 안 보이지만 큰 트롤에서는 미세하게 흐려집니다 → 보류.
  - 기준은 "고해상도 화면, 가장 가까운 줌에서 맞대 보아도 모르는 수준"입니다. 50dB 이상이고 8단계 넘게 바뀐 픽셀이 0.1% 미만이면 통과입니다.
- **WebP 압축 노력도 올리기**: method 6, 무손실 계수 100은 같은 픽셀로 약 3%만 줄어들고 임포트 시간이 크게 늘어 쓰지 않습니다.
- **텍스처를 VRAM 압축(S3TC)으로 바꾸기**: 디코딩 비용은 사라지지만 albedo 화질이 떨어지고 다운로드가 2~3배 커집니다. 데스크톱은 WebP를 유지합니다(모바일 팩은 ETC2).
- **폰트**: 게임에 쓰인 글자만 남깁니다(`tools/make_fonts.py`). 제목용 라틴 폰트도 348KB에서 23KB로 줄였습니다. 텍스트를 추가했으면 다시 실행하세요. 빠진 글자는 네모로 나옵니다. CI의 `make_fonts.py --check`가 막습니다(실제로 "끊겼"이 빠져 있던 것을 잡았습니다).

## 4. 코드 함정 (실제로 겪은 것)

- **비동기로 짓는 중에 씬이 바뀌면**, `await get_tree().process_frame` 뒤의 `get_tree()`/`get_viewport()`가 null이 됩니다. 루프 안이라면 에러를 수십만 번 찍으며 멈춥니다. `await` 뒤에는 `is_inside_tree()`와 `Game._busy`를 확인하고 그만두세요(`main_menu._step()`).
- **새 `class_name`을 추가하면** 헤드리스 실행 전에 `godot --headless --import`로 클래스 캐시를 갱신해야 합니다. 안 하면 "Identifier not declared"가 납니다.
- **GDScript `const`에 다른 클래스 상수를 인덱싱한 값은 넣을 수 없습니다.** `var`를 쓰세요.
- **Godot 4.7 PCK(형식 4)**: 헤더 112바이트이고, 디렉터리 오프셋은 절대값, 파일 오프셋은 데이터 시작 기준이며 16바이트 정렬입니다. 경로에 `res://` 접두사가 없습니다. 내보낸 팩에는 원본 대신 `.import` 리맵과 `.godot/imported/*` 파일이 들어갑니다.
- **임포트된 텍스처의 밉맵은 레벨마다 따로 WebP로 저장됩니다.** 노멀맵은 밉이 전체 용량의 약 36%입니다.

## 5. 다음 단계 (조사했지만 아직 하지 않은 것)

- **크기 최적화 엔진 템플릿** (Godot 문서 "Optimizing a build for size"): 타이틀까지의 시간에서 가장 큰 남은 몫입니다.
  - 빌드 옵션: `scons platform=web target=template_release threads=no optimize=size_extra build_profile=<프로젝트에서 감지한 .gdbuild>`
  - 끌 수 있는 것: 이 게임은 물리·내비게이션·RichTextLabel을 쓰지 않습니다. 물리(Jolt/GodotPhysics), navigation_2d/3d, openxr/webxr, multiplayer/enet/webrtc/websocket, theora, mp3, gltf(런타임), camera 같은 모듈을 끌 수 있습니다.
  - 고급 텍스트 서버(ICU 포함)를 대체(fallback) 텍스트 서버로 바꾸면 크게 줄지만, 문서상 라틴·그리스·키릴만 완전 지원입니다. 한글 표시를 화면 비교로 확인해야 합니다.
  - 필요한 것: Emscripten 4.0 이상. CI에서 30~60분 빌드하고 결과를 캐시합니다. `export_presets.cfg`의 custom_template에 지정합니다.
  - 예상: wasm gzip 10.1MB → 약 7MB, Brotli 약 5MB.
- **wasm 코드 캐시**: V8은 `instantiateStreaming`으로 URL이 있는 응답을 컴파일할 때만 컴파일 결과를 캐시합니다. 지금처럼 압축 파트를 풀어 만든 응답에는 URL이 없어 재방문 때도 다시 컴파일합니다. 서비스 워커가 풀린 wasm을 Cache Storage에 URL로 넣어 두면 재방문 시작이 빨라질 수 있습니다(데스크톱에서는 컴파일이 다운로드와 겹쳐 효과가 작았습니다).
- **전투 중 처음 쓰는 에셋 예열**: 첫 타워 건설·첫 적 등장 때 모델과 텍스처를 처음 불러오는 비용(네이티브에서 +80~240ms)이 있습니다. 1레벨 타워와 첫 웨이브 적을 전투 시작 페이드 뒤에서 미리 불러오면 클릭할 때의 끊김이 줄지만, 그만큼 전투 시작이 늦어집니다.
