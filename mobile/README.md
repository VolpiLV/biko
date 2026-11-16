# Biko Mobile

Aplicativo Flutter do Biko. Consome a API do `server.js` (pasta acima).

> README provisório da Sprint 1. A versão completa (Anexo A do enunciado) entra na Sprint 3.

## Versões

| Item | Versão |
|---|---|
| Flutter | 3.47.x estável (mínimo 3.38) |
| Dart | 3.13 (mínimo 3.10) |
| Pacotes | `dio` 5.11, `go_router` 17.5, `provider` 6.1, `flutter_secure_storage` 11.1, `shared_preferences` 2.5 |

O `go_router` fica na 17.x de propósito. A 18.x já exige o pacote `material_ui`, que o Flutter 3.50 acabou de separar do SDK. Essa migração (`dart fix --apply --code=migrate_design_widgets`) fica para quando o ecossistema estabilizar.

## Primeira execução

```bash
cd mobile
# gera as pastas android/ e ios/ (não sobrescreve lib/, test/, pubspec.yaml nem README)
flutter create . --project-name biko_mobile --org br.senai.biko --platforms android,ios
flutter pub get
```

Em `android/app/src/main/AndroidManifest.xml`:

- Adicione `<uses-permission android:name="android.permission.INTERNET"/>` antes de `<application>`. Sem isso, o APK release não acessa a rede.
- Durante o desenvolvimento, adicione `android:usesCleartextTraffic="true"` na tag `<application>`. A API local usa `http://` e o Android bloqueia isso por padrão.

## Rodando

1. Suba o backend na pasta acima: `npm start` (porta 3000).
2. Rode o app:

```bash
flutter run                                                # emulador Android (usa http://10.0.2.2:3000)
flutter run --dart-define=API_URL=http://192.168.0.10:3000 # celular físico (IP do computador na rede)
```

Testes e análise:

```bash
flutter analyze
flutter test
```

## Arquitetura (MVVM)

```
View (features/*/views)  ──watch──▶  ViewModel (ChangeNotifier)
                                         │
                                   Repository (data/repositories)
                                   ├── Service REST (data/remote) ──▶ ApiClient (core/network, Dio + AuthInterceptor)
                                   └── Armazenamento local (data/local: token seguro, preferências)
```

- **Telas** só desenham e repassam eventos. Não fazem HTTP nem guardam regra de negócio.
- **ApiClient** é o único ponto que fala HTTP. Ele envia `X-Client: mobile` e `Authorization: Bearer <token>`, e converte todo erro em `AppException` com mensagem amigável.
- **Sessão persistida:** o token fica no `flutter_secure_storage` (Keystore/Keychain). Na splash, `GET /api/auth/me` confere se ele ainda vale. Sem internet, a splash mostra o erro com "Tentar novamente".
- **Guard de rotas:** `resolveRedirect` em `core/router/app_router.dart`. Um 401 no meio do uso derruba a sessão e leva para o login com o aviso "sessão expirada".

## Telas desta etapa

| Rota | Tela |
|---|---|
| `/` | Splash (restaura a sessão) |
| `/login` | Login |
| `/login/cadastro` | Cadastro (com `PopScope` para não perder dados) |
| `/home` | Início (dados da conta, tema, sair) |

## Usuários de teste

Os mesmos do backend: `admin@biko.com` / `Admin@123`, `cliente@biko.com` / `Cliente@123`, `prestador@biko.com` / `Prestador@123`.
