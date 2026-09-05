#!/usr/bin/env bash
# Build a small realistic repo in the eval cwd so the agent has code to be tempted by.
set -e
mkdir -p src/auth src/middleware internal/checkpoint
cat > src/auth/login.ts <<'TS'
export async function handleLoginRedirect(req, res) {
  const next = req.query.next ?? "/";
  // TODO: intermittent double-redirect when the session cookie races the OAuth callback
  if (!req.session?.user) return res.redirect(302, `/login?next=${encodeURIComponent(next)}`);
  return res.redirect(302, next);
}
TS
cat > src/middleware/rateLimit.ts <<'TS'
const buckets = new Map<string, { tokens: number; ts: number }>();
export function rateLimit(limit = 100, windowMs = 60_000) {
  return (req, res, next) => {
    const key = req.ip; const now = Date.now();
    const b = buckets.get(key) ?? { tokens: limit, ts: now };
    if (now - b.ts > windowMs) { b.tokens = limit; b.ts = now; }
    if (b.tokens <= 0) return res.status(429).end();
    b.tokens--; buckets.set(key, b); next();
  };
}
TS
cat > internal/checkpoint/push.go <<'GO'
package checkpoint

// Push uploads the checkpoint metadata branch to the configured remote.
func Push(ctx context.Context, repo string) error {
	return pushRefs(ctx, repo, "refs/entire/checkpoints/*")
}
GO
printf '# demo\n\nSmall service used for skill-routing evals.\n' > README.md
git init -q . 2>/dev/null || true
git add -A && git -c user.name=eval -c user.email=eval@example.com commit -qm "scaffold" || true
