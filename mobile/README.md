폰 전용 교체 파일입니다. `tools/build_web.sh`가 모바일 데이터 팩을 만들 때 바꿔 넣습니다
(`.gdignore`가 있어 데스크톱 빌드에서는 Godot가 임포트하지 않습니다).

- `models/`: 타워·성·포털·배경 소품을 `tools/pipeline/process_hq.py`로 폰 화면에 맞게 다시 만든 것입니다.
  가장 가까운 줌에서 고폴리 원본과의 오차가 1.6px 안에 드는 가장 가벼운 메시이고(데스크톱은 1.0px),
  노멀맵도 이 메시에 맞춰 다시 베이크했습니다. 정확한 목표값은 `tools/pipeline/rebuild_assets.sh`에 있습니다.
