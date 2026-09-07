/** GitHub is the durable execution store. No KV or process-local lock owns work. */
export const RUNTIME_BRANCH = "runtime/weekly-learning";
export const RUNTIME_PATH = "weekly/state.json";
export const emptyState = () => ({ version: 1, generations: {}, leases: {}, operations: {} });

export function validateState(state) {
  if (state?.version !== 1 || !state.generations || !state.leases || !state.operations ||
      [state.generations, state.leases, state.operations].some((x) => typeof x !== "object" || Array.isArray(x))) {
    throw new Error("Invalid controller runtime state; refusing to reset ownership");
  }
  for (const value of Object.values(state.generations)) if (!Number.isSafeInteger(value) || value < 1) throw new Error("Invalid ownership generation");
  for (const [key, lease] of Object.entries(state.leases)) {
    if (lease?.key !== key || typeof lease.owner !== "string" || !lease.owner || !Number.isSafeInteger(lease.generation) || lease.generation !== state.generations[key] || !Number.isFinite(lease.expiresAt)) throw new Error("Invalid execution lease");
  }
  for (const [id, op] of Object.entries(state.operations)) {
    if (op?.id !== id || !op.sends || typeof op.sends !== "object" || Array.isArray(op.sends) || !Number.isInteger(op.misses) || op.misses < 0 || !Number.isInteger(op.repairs) || op.repairs < 0) throw new Error("Invalid operation receipt");
    for (const send of Object.values(op.sends)) if (!Number.isFinite(send?.startedAt) || typeof send.owner !== "string" || !Number.isSafeInteger(send.generation)) throw new Error("Invalid send receipt");
  }
  return state;
}

export class GitHubRuntime {
  constructor(api, repo, { branch = RUNTIME_BRANCH, write = false } = {}) {
    this.api = api; this.repo = repo; this.branch = branch; this.write = write;
  }
  async read() {
    let ref;
    try { ref = await this.api("GET", `/repos/${this.repo}/git/ref/heads/${this.branch}`); }
    catch (e) { if (e.status === 404) return { sha: null, state: emptyState() }; throw e; }
    if (!ref?.object?.sha) throw new Error("Runtime ref has no SHA");
    const sha = ref.object.sha;
    const data = await this.api("GET", `/repos/${this.repo}/contents/${RUNTIME_PATH}?ref=${sha}`);
    return { sha, state: validateState(JSON.parse(Buffer.from(data.content, "base64").toString("utf8"))) };
  }
  async compareAndSwap(expected, state) {
    if (!this.write) throw new Error("Runtime writes require --write");
    validateState(state);
    let parent = expected;
    if (!parent) {
      const repo = await this.api("GET", `/repos/${this.repo}`);
      parent = (await this.api("GET", `/repos/${this.repo}/commits/${encodeURIComponent(repo.default_branch)}`)).sha;
    }
    const blob = await this.api("POST", `/repos/${this.repo}/git/blobs`, { content: JSON.stringify(state), encoding: "utf-8" });
    const tree = await this.api("POST", `/repos/${this.repo}/git/trees`, { tree: [{ path: RUNTIME_PATH, mode: "100644", type: "blob", sha: blob.sha }] });
    const commit = await this.api("POST", `/repos/${this.repo}/git/commits`, {
      message: "controller: record execution ownership and receipt", tree: tree.sha, parents: [parent],
    });
    try {
      if (!expected) await this.api("POST", `/repos/${this.repo}/git/refs`, { ref: `refs/heads/${this.branch}`, sha: commit.sha });
      else await this.api("PATCH", `/repos/${this.repo}/git/refs/heads/${this.branch}`, { sha: commit.sha, force: false });
      return true;
    } catch (e) {
      // A sibling commit from the same parent is not a fast-forward. Never
      // force the ref: a rejected advance is a lost CAS, not a reason to reset.
      if (![409, 422].includes(e.status)) throw e;
      const current = await this.read();
      if (current.sha === commit.sha) return true;
      if (current.sha !== expected) return false;
      throw e; // policy/validation failure, not contention
    }
  }
}

export async function transact(store, change, maxAttempts = 8) {
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const { sha, state } = await store.read();
    const result = change(state); // pure: no network calls inside a transaction
    if (!result.changed || await store.compareAndSwap(sha, state)) return result.value;
  }
  throw new Error("Controller runtime contention; retry on next firing");
}

export async function claim(store, key, owner, now, ttl = 10 * 60_000) {
  return transact(store, (state) => {
    const current = state.leases[key];
    if (current && current.expiresAt > now) return { changed: false, value: null };
    const generation = (state.generations[key] ?? 0) + 1;
    const lease = { key, owner, generation, expiresAt: now + ttl };
    state.generations[key] = generation; state.leases[key] = lease;
    return { changed: true, value: lease };
  });
}

export function owns(state, lease, now) {
  const current = state.leases[lease.key];
  return current?.owner === lease.owner && current.generation === lease.generation && current.expiresAt > now;
}

export async function owned(store, lease, now, change) {
  return transact(store, (state) => {
    if (!owns(state, lease, now)) throw new Error("Lost execution ownership");
    const value = change(state);
    return { changed: true, value };
  });
}

export async function release(store, lease, now) {
  return transact(store, (state) => {
    if (!owns(state, lease, now)) return { changed: false, value: false };
    delete state.leases[lease.key];
    return { changed: true, value: true };
  });
}
