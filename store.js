// Camada de acesso ao Firestore usada pela API e pelos microsserviços.
// Cada antiga TABELA do SQLite virou uma COLEÇÃO do Firestore, com um documento por registro.
// Os ids continuam numéricos (1, 2, 3...) porque o site e o app usam número: um documento
// _contadores/<coleção> guarda o último id e é incrementado numa transação.
const { firestore } = require('./firebase');

const fsdb = () => firestore();

// Documento do Firestore -> objeto com o id numérico (ou texto, para tokens)
const fromDoc = (d) => {
  const o = d.data();
  // Bytes do Firestore (fotos) voltam como Buffer/Uint8Array: normaliza para Buffer
  for (const [k, v] of Object.entries(o)) if (v instanceof Uint8Array && !Buffer.isBuffer(v)) o[k] = Buffer.from(v);
  return o;
};

function colecao(name) {
  const ref = () => fsdb().collection(name);
  return {
    name,
    /** Todos os documentos da coleção. */
    async all() { return (await ref().get()).docs.map(fromDoc); },
    /** Filtro simples do Firestore: where('status', '==', 'pendente'). Pode encadear vários [campo, op, valor]. */
    async where(...filters) {
      let q = ref();
      for (let i = 0; i < filters.length; i += 3) q = q.where(filters[i], filters[i + 1], filters[i + 2]);
      return (await q.get()).docs.map(fromDoc);
    },
    async first(...filters) { return (await this.where(...filters))[0]; },
    async get(id) { const d = await ref().doc(String(id)).get(); return d.exists ? fromDoc(d) : undefined; },
    /** Insere com id numérico automático. Devolve o id. */
    async insert(obj) {
      const id = await nextId(name);
      await ref().doc(String(id)).set({ ...obj, id });
      return id;
    },
    /** Grava com um id escolhido (ex.: token da sessão). */
    async set(id, obj) { await ref().doc(String(id)).set(obj); },
    async update(id, patch) { await ref().doc(String(id)).update(patch); },
    async remove(id) { await ref().doc(String(id)).delete(); },
    async removeWhere(...filters) {
      const docs = await this.where(...filters);
      await Promise.all(docs.map((d) => ref().doc(String(d.id ?? d.token)).delete()));
      return docs.length;
    },
  };
}

async function nextId(name) {
  const ref = fsdb().collection('_contadores').doc(name);
  return fsdb().runTransaction(async (tx) => {
    const d = await tx.get(ref);
    const n = (d.exists ? d.data().ultimo : 0) + 1;
    tx.set(ref, { ultimo: n });
    return n;
  });
}

// Trava simples (uma operação por vez) para as regras que no SQLite eram uma transação:
// ex.: dois clientes pedindo o mesmo horário ao mesmo tempo -> só um passa.
let fila = Promise.resolve();
function exclusivo(fn) {
  const run = fila.then(fn, fn);
  fila = run.catch(() => {});
  return run;
}

module.exports = { colecao, exclusivo, nextId };
