import 'package:asb_client/asb_client.dart';

import 'host_conn.dart';

/// Fixed sample data mirroring the mockup's flaky-auth session, used only when
/// the app is built with `--dart-define=ASB_DEMO=true`. Lets the stream UI be
/// screenshotted deterministically without a live sidecar.
const _authTest = '''describe('auth', () => {
  let token;
  beforeAll(async () => {
    token = await mint(user);        // one token for the whole file
  });

  it('returns the caller', async () => {
    const res = await get('/me', token);
    expect(res.status).toBe(200);
  });
});''';

const _searchHits = '''packages/api/test/auth.test.ts:4      token = await mint(user);
packages/api/test/session.test.ts:11  const t = await mint(owner);
packages/api/src/token.ts:38          export async function mint(u: User) {
packages/api/src/token.ts:52            return sign(u, { expiresIn: '60s' });''';

const _diff = '''@@ -18,7 +18,15 @@ describe('auth', () => {
   const token = await mint(user);
-  expect(res.status).toBe(200);
-  expect(res.body.id).toEqual(user.id);
+  await waitFor(() => {
+    expect(res.status).toBe(200);
+  }, { timeout: 5_000, interval: 50 });
 });''';

const _testOut = '''\$ pnpm test --filter api
 PASS  test/session.test.ts
 FAIL  test/auth.test.ts  (1 of 5 runs)
   exit 1 · 41.2s''';

UpdateDto _u(BigInt seq, PayloadDto p) =>
    UpdateDto(session: 'demo', seq: seq, turn: BigInt.two, payload: p);

Map<String, SessionData> demoSessions() {
  final s = SessionData(title: 'Fix the flaky auth test in packages/api', lastSeq: BigInt.from(810));
  s.updates.addAll([
    _u(BigInt.from(801), const PayloadDto.userMessage(text: 'the auth test fails maybe 1 in 5 runs on CI — find out why')),
    _u(BigInt.from(802), const PayloadDto.thought(text: 'Timing-dependent — the fixture reuses one token across the file')),
    _u(BigInt.from(803), const PayloadDto.toolCall(id: 't1', kind: 'read', title: 'read the test', status: 'done', locations: [], content: [
      ContentDto(kind: 'file_ref', path: 'packages/api/test/auth.test.ts'),
      ContentDto(kind: 'text', text: _authTest),
    ])),
    _u(BigInt.from(804), const PayloadDto.toolCall(id: 't2', kind: 'search', title: 'mint( · 4 files', status: 'done', locations: [], content: [
      ContentDto(kind: 'text', text: _searchHits),
    ])),
    _u(BigInt.from(805), const PayloadDto.plan(entries: [
      'Reproduce the flake locally',
      'Mint a token per test',
      'Guard the assertion with waitFor',
    ])),
    _u(BigInt.from(806), const PayloadDto.toolCall(id: 't3', kind: 'edit', title: 'auth.test.ts', status: 'done', locations: [], content: [
      ContentDto(kind: 'diff', path: 'packages/api/test/auth.test.ts', diff: _diff),
    ])),
    _u(BigInt.from(807), const PayloadDto.toolCall(id: 't4', kind: 'command', title: 'tests', command: 'pnpm test --filter api', status: 'failed', locations: [], content: [
      ContentDto(kind: 'text', text: _testOut),
    ])),
    _u(BigInt.from(808), const PayloadDto.toolCall(id: 't5', kind: 'command', title: 'tests again', command: 'pnpm test --filter api  ×5', status: 'done', locations: [], content: [
      ContentDto(kind: 'text', text: '5 runs, 5 passes · 3m02s'),
    ])),
    _u(BigInt.from(809), PayloadDto.usage(input: BigInt.from(8213), output: BigInt.from(1402))),
    _u(BigInt.from(810), const PayloadDto.agentMessage(text: 'Added a retry guard around the token assertion and rewrote the fixture to mint a token per test. Five consecutive runs pass.')),
  ]);
  return {'demo': s};
}
