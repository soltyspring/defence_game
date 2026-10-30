# Verified live follow-up dispatch — mandatory procedure
User explicitly authorizes existing terminal bottom-prompt input. Native Windows Console WriteConsoleInputW route is implemented in coordination/console_send.py and VERIFIED in current ten worker windows: 03 PID27284, 01 PID39308, 06 PID37248 and 04 PID36128 accepted actual next-task prompts and resumed working without any host/window restart. Do not use request-file-only delivery for a completed idle role now that this route works.

Each heartbeat:
1. Read quota usage/trigger first. >=97 or trigger => no new work dispatch.
2. Read owner handoff, actual commit and validation/failure artifacts. Critically identify an actionable next task or precise verification/correction (not vague continue or endless docs).
3. Observe real current terminal screenshot: target role title matches; prompt says ask a question/describe a task; input is EMPTY; no user draft. A process or session-list idle flag is not proof. If Kiro is working, do not interrupt; existing request file can be queued/read at boundary. Theme question stays sole open question, no invented user answer.
4. Resolve live worker PID with Get-CimInstance Win32_Process: executable chat-cli-2.35.1.exe and full initial prompt/--resume-id matching that role; verify no second role process. PID registry below is only a hint and must be revalidated.
5. Write one single-line concrete task into coordination/prompts/<role>-live-next.txt, then run:
python coordination/console_send.py --pid <verified PID> --text-file coordination/prompts/<role>-live-next.txt --result coordination/.runtime/<role>-delivery.json
This writes stdin key records to that exact console and Enter; never clears input/activates unrelated windows/sends Ctrl+C/restarts processes. It is direct process-console I/O, necessary because sky's window inventory omits terminals.
6. The tool result INPUT_WRITTEN_REQUIRES_READBACK is NOT proof of model execution. Observe same live window and verify Kiro is working plus prompt-specific read/tool actions or new role artifacts. Record START_CONFIRMED with role/PID/window/session/task/time. On partial/unknown send, reobserve input and output; NEVER blindly resend and duplicate the task.
7. Model rate limit is not exhausted credits: record error/cooldown, wait until cooldown or at least 2 minutes, then at most one retry in existing empty prompt. Exponential backoff on repeated rate errors (2,4,8 minutes); no loops or account-switch request for mere rate errors. Batch new task starts conservatively; do not dispatch all ten simultaneously.
8. On completion verify actual tests and pushed SHA; fix/retest defects before next implementation task. No new user approval needed for existing authorized game scope.

Current PID hints (verify):01=39308;02=9364;03=27284;04=36128;05=26668;06=37248;07=36032;08=6304.
Readback verified from real full8 screenshot: 01 balance diagnosis working29s;03 typography/import review working1m28s;06 service M2 working28s;04 left rate-limit error and actively editing UI scripts. 02/05/07/08 unchanged active. All8 windows retained at same positions.

