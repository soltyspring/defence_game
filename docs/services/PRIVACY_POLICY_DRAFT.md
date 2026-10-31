# Privacy policy draft — 개인정보처리방침 / Privacy Policy (owner: 06-services)
Version: 1 (2026-10-31). Status: **TEMPLATE, not legal advice, not published.** Basis: the current build in `disabled` mode collects and sends no personal data (docs/services/ANALYTICS_EVENTS.md §4 inventory; `test_services_integration.gd` D1–D6: nothing live, Android INTERNET permission off). Machine-checked by `tests/services/test_services_listing.gd`.

How to read the markers:
- `{{…}}` = value the user must supply (developer name, contact, URL, dates).
- `[광고 활성화 시]` / `[IF ADS ENABLED]` = block to add or rewrite when ads are approved.
- `[결제 활성화 시]` / `[IF PURCHASES ENABLED]` = block to add or rewrite when in-app purchases are approved.
- `[분석 활성화 시]` / `[IF ANALYTICS ENABLED]` = block for remote analytics (not planned).
- `[법률 확인 필요]` / `[LEGAL REVIEW]` = wording or item list that a qualified person must confirm (Korean PIPA text was not verified by tool, see RELEASE_READINESS_SERVICES.md V5).

Google Play requirements this template follows (User Data policy, checked 2026-10-31, https://support.google.com/googleplay/android-developer/answer/10144311?hl=en): link in Play Console and inside the app; titled as a privacy policy; names the developer/app; gives a privacy contact; lists data accessed, collected, used and shared and with whom; describes secure handling; states retention and deletion; public, non-geofenced, non-PDF URL; required even when no personal data is accessed. Content was rephrased for compliance with licensing restrictions.

---

## 한국어

<!-- BEGIN policy.ko -->
# 개인정보처리방침

{{DEVELOPER_NAME}}(이하 "개발자")은 게임 「{{APP_NAME}}」(이하 "게임")을 제공하며, 이용자의 개인정보를 소중히 다룹니다. 이 방침은 게임이 어떤 정보를 처리하는지 설명합니다. [법률 확인 필요: 「개인정보 보호법」상 필수 기재 항목과 표현]

## 1. 처리하는 개인정보
현재 게임은 이용자의 개인정보를 수집하거나 외부로 전송하지 않습니다. 회원 가입, 로그인, 위치 정보, 연락처, 광고 식별자를 사용하지 않습니다.
게임 진행 정보(해금한 라운드, 별, 골드, 설정)는 이용자 기기 안에만 저장되며 개발자에게 전송되지 않습니다.

[광고 활성화 시] 광고 제공을 위해 광고 사업자 {{AD_NETWORK}}가 기기의 IP 주소, 광고 식별자, 앱 사용 정보(광고 노출·시청 등), 진단 정보를 수집할 수 있습니다. 수집 항목과 목적은 해당 사업자의 개인정보처리방침({{AD_NETWORK_POLICY_URL}})을 따릅니다. 유럽경제지역·영국·스위스 이용자에게는 광고 표시 전에 동의를 받습니다. [법률 확인 필요]

[결제 활성화 시] 인앱 결제는 Google Play가 처리하며 개발자는 카드 번호 등 결제 정보를 받지 않습니다. 구매 확인을 위해 구매 토큰과 상품 정보를 {{VERIFICATION_SERVER}}에서 처리할 수 있습니다. [법률 확인 필요]

[분석 활성화 시] (현재 계획 없음) 게임 개선을 위한 통계를 수집하는 경우 항목, 목적, 보관 기간을 여기에 적고 사전에 동의를 받습니다.

## 2. 처리 목적
현재는 기기 안에서 게임 진행을 저장하는 목적 외에는 개인정보를 처리하지 않습니다.
[광고 활성화 시] 광고 표시, 광고 성과 측정, 부정 사용 방지.
[결제 활성화 시] 구매 확인, 구매 복원, 환불 처리.

## 3. 제3자 제공 및 처리 위탁
현재 개인정보를 제3자에게 제공하거나 처리를 위탁하지 않습니다.
[광고 활성화 시] {{AD_NETWORK}}에 위 1항의 정보가 제공됩니다(국외 이전 여부, 이전 국가, 보유 기간 기재). [법률 확인 필요]
[결제 활성화 시] Google Play 결제 및 {{VERIFICATION_SERVER}}. [법률 확인 필요]

## 4. 보유 기간 및 파기
기기에 저장된 게임 진행 정보는 이용자가 게임을 삭제하거나 앱 데이터를 지우면 함께 삭제됩니다. 개발자는 이 정보를 따로 보관하지 않습니다.
[결제 활성화 시] 구매 기록의 보관 기간: {{RETENTION_PERIOD}} [법률 확인 필요: 전자상거래 관련 법령의 보관 의무]

## 5. 이용자의 권리
현재 개발자가 보관하는 이용자 개인정보는 없습니다. 기기 안의 정보는 앱 삭제 또는 앱 데이터 삭제로 지울 수 있습니다.
[광고 활성화 시] 게임 설정의 "개인정보 설정"에서 광고 동의를 언제든지 바꾸거나 철회할 수 있습니다. 광고 식별자는 기기 설정에서 재설정하거나 삭제할 수 있습니다.

## 6. 안전성 확보 조치
게임 진행 정보는 기기의 앱 전용 저장 공간에 저장되며 손상 확인값(체크섬)으로 무결성을 검사합니다.
[광고 활성화 시][결제 활성화 시] 외부로 전송되는 정보는 암호화된 연결(HTTPS/TLS)로만 전송합니다.

## 7. 아동의 개인정보
{{CHILD_AUDIENCE_STATEMENT}} [법률 확인 필요: 대상 연령 결정(OPEN_DECISIONS.md U4) 후 작성, 만 14세 미만 아동 관련 조항]

## 8. 개인정보 보호책임자 및 문의
- 개발자: {{DEVELOPER_NAME}}
- 이메일: {{CONTACT_EMAIL}}
- 개인정보 보호책임자: {{PRIVACY_OFFICER}} [법률 확인 필요]

## 9. 방침의 변경
이 방침을 바꾸면 게임 안과 이 페이지에 알립니다. 시행일: {{EFFECTIVE_DATE}}
<!-- END policy.ko -->

---

## English

<!-- BEGIN policy.en -->
# Privacy Policy

{{DEVELOPER_NAME}} ("we") provides the game "{{APP_NAME}}" (the "Game"). This policy explains what information the Game handles. [LEGAL REVIEW: required items and wording for each market]

## 1. Information we process
The Game currently does not collect personal information and does not send any data off your device. It has no accounts or login and does not use location, contacts or advertising identifiers.
Game progress (unlocked rounds, stars, gold, settings) is stored only on your device and is never sent to us.

[IF ADS ENABLED] To show ads, our ad provider {{AD_NETWORK}} may collect your device's IP address, advertising ID, app interactions (such as ad views) and diagnostic information. See its policy at {{AD_NETWORK_POLICY_URL}}. Users in the EEA, the UK and Switzerland are asked for consent before ads are shown. [LEGAL REVIEW]

[IF PURCHASES ENABLED] In-app purchases are processed by Google Play; we never receive card numbers or other payment details. To confirm a purchase, the purchase token and product ID may be processed by {{VERIFICATION_SERVER}}. [LEGAL REVIEW]

[IF ANALYTICS ENABLED] (not planned) If we collect usage statistics to improve the Game, the data, purpose and retention period will be listed here and your consent will be asked first.

## 2. Why we process it
Today, only to save your game progress on your device.
[IF ADS ENABLED] Showing ads, measuring ad performance, preventing fraud.
[IF PURCHASES ENABLED] Verifying, restoring and refunding purchases.

## 3. Sharing
We do not share personal information with anyone today.
[IF ADS ENABLED] The information in section 1 is shared with {{AD_NETWORK}} (state international transfers, countries and retention). [LEGAL REVIEW]
[IF PURCHASES ENABLED] Google Play Billing and {{VERIFICATION_SERVER}}. [LEGAL REVIEW]

## 4. Retention and deletion
Game progress on your device is deleted when you uninstall the Game or clear its app data. We keep no copy.
[IF PURCHASES ENABLED] Purchase records are kept for {{RETENTION_PERIOD}}. [LEGAL REVIEW]

## 5. Your choices
We hold no personal information about you today. You can delete on-device data by uninstalling the Game or clearing its app data.
[IF ADS ENABLED] You can change or withdraw ad consent at any time in the Game's "Privacy settings". You can reset or delete your advertising ID in your device settings.

## 6. Security
Game progress is stored in the app's private storage and checked for corruption with a checksum.
[IF ADS ENABLED][IF PURCHASES ENABLED] Any data sent off the device is sent only over encrypted connections (HTTPS/TLS).

## 7. Children
{{CHILD_AUDIENCE_STATEMENT}} [LEGAL REVIEW: write after the target audience decision (OPEN_DECISIONS.md U4)]

## 8. Contact
- Developer: {{DEVELOPER_NAME}}
- Email: {{CONTACT_EMAIL}}
- Privacy contact: {{PRIVACY_OFFICER}} [LEGAL REVIEW]

## 9. Changes
We will announce changes to this policy in the Game and on this page. Effective date: {{EFFECTIVE_DATE}}
<!-- END policy.en -->

---

## Placeholders the user must fill (through 01, see OPEN_DECISIONS.md U2/U3)
`{{DEVELOPER_NAME}}`, `{{APP_NAME}}`, `{{CONTACT_EMAIL}}`, `{{PRIVACY_OFFICER}}`, `{{EFFECTIVE_DATE}}`, `{{CHILD_AUDIENCE_STATEMENT}}`; only if monetized: `{{AD_NETWORK}}`, `{{AD_NETWORK_POLICY_URL}}`, `{{VERIFICATION_SERVER}}`, `{{RETENTION_PERIOD}}`. Hosting: public, non-geofenced, non-PDF URL (user). In-app link: 04 (settings/menu).

## What changes when monetization is turned on (summary)
| Switch | Sections affected | Also update |
|---|---|---|
| Ads | 1, 2, 3, 5, 6 (+ 7 if children may see ads) | Data safety form (A6), consent UI (A2), AD_ID permission (A3) |
| Purchases | 1, 2, 3, 4, 6 | Data safety (financial info is handled by Google Play), refund notice text |
| Remote analytics | 1, 2, 3, 4 | Data safety, consent (analytics purpose) |
