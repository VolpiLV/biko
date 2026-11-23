// Firestore em memória: imita a parte da API do firebase-admin que o Biko usa
// (collection/doc get/set/update/delete, where, get e runTransaction).
// Serve para os testes automáticos e para rodar sem a chave do Firebase.
const clone = (v) => (v === undefined ? undefined : structuredClone(v));

function criar() {
  const data = new Map(); // nome da coleção -> Map(id -> objeto)
  const col = (name) => { if (!data.has(name)) data.set(name, new Map()); return data.get(name); };
  const snap = (id, obj) => ({ id, exists: obj !== undefined, data: () => clone(obj) });

  function docRef(colName, id) {
    id = String(id);
    return {
      id,
      async get() { return snap(id, col(colName).get(id)); },
      async set(obj, opts = {}) {
        const clean = stripUndef(obj);
        col(colName).set(id, opts.merge ? { ...(col(colName).get(id) || {}), ...clean } : clean);
      },
      async update(patch) {
        const cur = col(colName).get(id);
        if (!cur) throw new Error(`Documento ${colName}/${id} não existe`);
        col(colName).set(id, { ...cur, ...stripUndef(patch) });
      },
      async delete() { col(colName).delete(id); },
    };
  }

  const ops = {
    '==': (a, b) => (a ?? null) === b,
    '!=': (a, b) => (a ?? null) !== b,
    '<': (a, b) => a !== null && a !== undefined && a < b,
    '<=': (a, b) => a !== null && a !== undefined && a <= b,
    '>': (a, b) => a !== null && a !== undefined && a > b,
    '>=': (a, b) => a !== null && a !== undefined && a >= b,
    in: (a, b) => b.includes(a),
  };
  function query(colName, filters) {
    return {
      where(field, op, value) { return query(colName, [...filters, [field, op, value]]); },
      async get() {
        const docs = [];
        for (const [id, obj] of col(colName)) {
          if (filters.every(([f, op, v]) => ops[op](obj[f], v))) docs.push(snap(id, obj));
        }
        return { docs, size: docs.length, empty: !docs.length };
      },
    };
  }

  const db = {
    collection(name) {
      return { ...query(name, []), doc: (id) => docRef(name, id) };
    },
    // Sem concorrência real aqui: a transação só executa a função.
    async runTransaction(fn) {
      const tx = {
        get: (ref) => ref.get(),
        set: (ref, obj, opts) => { ref.set(obj, opts); return tx; },
        update: (ref, patch) => { ref.update(patch); return tx; },
        delete: (ref) => { ref.delete(); return tx; },
      };
      return fn(tx);
    },
    settings() {},
  };
  return db;
}

function stripUndef(obj) {
  const out = {};
  for (const [k, v] of Object.entries(obj)) if (v !== undefined) out[k] = clone(v);
  return out;
}

module.exports = { criar };
