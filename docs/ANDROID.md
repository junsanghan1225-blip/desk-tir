# 안드로이드로 내보내기 (Windows)

이 저장소에는 안드로이드 내보내기 설정(`export_presets.cfg`), 앱 아이콘(`resource/icon.png`), 안드로이드용 텍스처 설정이 이미 들어 있어요.
PC에 아래 도구만 설치하면 돼요. 처음 한 번만 하면 되고, 그다음부터는 8번만 반복하면 돼요.

## 0. 먼저 정할 것: 패키지 이름

지금은 `com.cheesepotato.deskterior`로 넣어 두었어요. **Play에 한 번 올리면 영영 못 바꾸니까** 다른 이름을 쓸 거면 첫 업로드 전에 바꾸세요.
Godot 메뉴 **프로젝트 → 내보내기 → Android → 패키지 → Unique Name**에서 바꿔요.

## 1. JDK 17 설치

[Adoptium Temurin 17](https://adoptium.net/temurin/releases/?version=17&os=windows)에서 Windows x64 **.msi**를 받아 설치해요.
JDK 21이 아니라 **17**이어야 해요.

## 2. Android SDK 설치

1. [Android Studio](https://developer.android.com/studio)를 설치하고 한 번 실행해요. 처음 실행할 때 SDK가 같이 깔려요.
2. Android Studio → **More Actions → SDK Manager**에서 아래를 체크하고 Apply를 눌러요.
   - SDK Platforms: **Android 16 (API 36)**
   - SDK Tools: **Android SDK Build-Tools**, **Android SDK Platform-Tools**, **Android SDK Command-line Tools (latest)**
3. 위쪽에 나오는 **Android SDK Location** 경로를 메모해요. 보통 `C:\Users\<이름>\AppData\Local\Android\Sdk`예요.

## 3. Godot에 경로 알려 주기

Godot 메뉴 **편집기 → 편집기 설정 → 내보내기 → Android**에서 두 칸을 채워요.

- **Java SDK Path**: `C:\Program Files\Eclipse Adoptium\jdk-17...` (1번에서 설치된 폴더)
- **Android SDK Path**: 2번에서 메모한 경로

경로가 틀리면 빨간 글씨가 떠요.

## 4. 내보내기 템플릿 설치

**편집기 → 내보내기 템플릿 관리 → 다운로드 및 설치**를 눌러요. 1GB 정도라 시간이 좀 걸려요.

## 5. Android 빌드 템플릿 설치

**프로젝트 → Android 빌드 템플릿 설치**를 눌러요. 프로젝트 안에 `android/` 폴더가 생겨요.
Play용 파일(.aab)을 만드는 데 필요해요. 이 폴더는 저장소에 안 올라가게 막아 두었어요.

## 6. 내 폰에서 바로 실행해 보기

1. 폰 **설정 → 휴대전화 정보 → 소프트웨어 정보 → 빌드번호**를 7번 눌러서 개발자 옵션을 켜요.
2. **설정 → 개발자 옵션 → USB 디버깅**을 켜요.
3. 폰을 USB로 PC에 꽂고, 폰에 뜨는 "USB 디버깅 허용"을 눌러요.
4. Godot 오른쪽 위에 생긴 **안드로이드 아이콘 버튼**을 눌러요. 빌드가 끝나면 폰에서 게임이 켜져요.

테스트용 서명 키는 Godot가 알아서 만들어요.
**폰에서 확인할 것**: 글씨가 읽히는지, 버튼이 손가락으로 잘 눌리는지, 두 번 누르기로 부품이 빠지는지, 뒤로 버튼이 일시정지를 여는지, 소리가 나는지.

## 7. 출시용 서명 키 만들기 (한 번만)

명령 프롬프트(cmd)에서 아래를 실행해요. `keytool`은 1번에서 설치한 JDK에 들어 있어요.

```
keytool -genkey -v -keystore deskterior-release.keystore -alias deskterior -keyalg RSA -keysize 2048 -validity 10000
```

비밀번호와 이름 등을 물어봐요.

- **이 파일과 비밀번호는 반드시 백업**하세요(USB, 클라우드 두 군데 이상). 잃어버리면 앱 업데이트가 막혀요. Play 앱 서명을 쓰면 Google 지원팀을 통해 키를 다시 등록할 수는 있지만 번거로워요.
- 저장소 폴더 안에 두지 마세요. `.keystore` 파일은 git에 안 올라가게 막아 두었지만, 다른 폴더에 두는 게 안전해요.

## 8. Play용 파일(.aab) 만들기

1. **프로젝트 → 내보내기 → Android**를 열어요.
2. **Keystore → Release**에 7번 파일 경로, 별칭(`deskterior`), 비밀번호를 넣어요. 비밀번호는 저장소가 아니라 `.godot` 폴더에 따로 저장돼요.
3. **Gradle Build → Target SDK**가 비어 있거나 36보다 낮으면 **36**을 넣어요. Play는 2026년 8월 31일부터 새 앱에 API 36 이상을 요구해요.
4. 다시 올릴 때마다 **Version → Code**를 1씩 올리고(2, 3, ...), **Version → Name**도 바꿔요(0.1.1 등).
5. **프로젝트 내보내기**를 누르고 **디버그로 내보내기**를 끈 뒤 `build/desk-tir.aab`로 저장해요.

## 9. Play Console 내부 테스트에 올리기

1. [Play Console](https://play.google.com/console) → **앱 만들기**(게임, 무료)
2. 왼쪽 **테스트 → 내부 테스트 → 새 버전 만들기** → `desk-tir.aab` 업로드
3. **테스터** 탭에서 이메일 목록을 만들고(본인, 친구) 저장 → **검토 후 출시**
4. 테스터 탭의 **참여 링크**를 폰에서 열면 Play 스토어에서 설치할 수 있어요.

**참고**: 2023년 11월 이후에 만든 **개인** 개발자 계정은 정식 출시 전에 **비공개 테스트(테스터 12명 이상, 14일 연속)**를 거쳐야 해요. 조직 계정은 이 조건이 없어요. 내부 테스트는 이 조건과 상관없이 바로 할 수 있어요.

## 막히면

에러 창이나 Godot 아래쪽 **출력** 패널의 빨간 글씨를 캡처해서 보내 주세요.
