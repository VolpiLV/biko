// Conexão com o Firebase (Cloud Firestore), usada pela API e pelos dois microsserviços.
//
// Onde ele procura a chave da conta de serviço (nesta ordem):
//   1. variável FIREBASE_SERVICE_ACCOUNT com o caminho do arquivo .json
//   2. variável GOOGLE_APPLICATION_CREDENTIALS (padrão do Google)
//   3. arquivo serviceAccountKey.json na raiz do projeto
// Sem chave nenhuma (ou com BIKO_FIRESTORE=memoria), usa um Firestore EM MEMÓRIA com a mesma
// API: o projeto roda igual, só que os dados somem ao desligar. É o que os testes usam.
const fs = require('fs');
const path = require('path');

let instance = null;
let modo = null;

function keyFile() {
  const candidates = [process.env.FIREBASE_SERVICE_ACCOUNT, process.env.GOOGLE_APPLICATION_CREDENTIALS, path.join(__dirname, 'serviceAccountKey.json')];
  return candidates.find((f) => f && fs.existsSync(f)) || null;
}

function firestore() {
  if (instance) return instance;
  const key = process.env.BIKO_FIRESTORE === 'memoria' ? null : keyFile();
  if (key || process.env.FIRESTORE_EMULATOR_HOST) {
    const admin = require('firebase-admin');
    if (!admin.apps.length) {
      admin.initializeApp(key
        ? { credential: admin.credential.cert(JSON.parse(fs.readFileSync(key, 'utf8'))) }
        : { projectId: process.env.GCLOUD_PROJECT || 'biko-local' });
    }
    instance = admin.firestore();
    instance.settings({ ignoreUndefinedProperties: true });
    modo = key ? `Firebase (Cloud Firestore) — chave ${path.basename(key)}` : `emulador do Firestore em ${process.env.FIRESTORE_EMULATOR_HOST}`;
  } else {
    instance = require('./firestore-memoria').criar();
    modo = 'Firestore EM MEMÓRIA (sem chave do Firebase: os dados somem ao desligar)';
  }
  return instance;
}

const modoFirestore = () => { firestore(); return modo; };

// O firebase-admin já iniciado com a chave (usado pelo push do microsserviço de notificações).
// null quando não há chave: Firestore em memória ou emulador não enviam push de verdade.
function firebaseAdmin() {
  firestore();
  const admin = require('firebase-admin');
  return admin.apps.length && admin.app().options.credential ? admin : null;
}

module.exports = { firestore, modoFirestore, firebaseAdmin };
