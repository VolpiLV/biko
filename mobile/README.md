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
flutter create . --project-name biko_mobile --org br.senai.biko --platforms android,ios,web
flutter pub get
```

Em `android/app/src/main/AndroidManifest.xml`:

- Adicione `<uses-permission android:name="android.permission.INTERNET"/>` antes de `<application>`. Sem isso, o APK release não acessa a rede.
- Durante o desenvolvimento, adicione `android:usesCleartextTraffic="true"` na tag `<application>`. A API local usa `http://` e o Android bloqueia isso por padrão.

## Rodando

1. Suba o backend na pasta acima: `npm run tudo` (API na porta 3000 + microsserviços de notificações e pagamentos). Só `npm start` também funciona, mas aí o sino e o botão Pagar ficam fora do ar.
2. Rode o app:

```bash
flutter run -d chrome                                      # navegador (usa http://localhost:3000)
flutter run                                                # emulador Android (usa http://10.0.2.2:3000)
flutter run --dart-define=API_URL=http://192.168.0.10:3000 # celular físico (IP do computador na rede)
```

No Chrome, o app roda em outra porta do `localhost`. O `server.js` libera essa origem por CORS (qualquer porta de `localhost`/`127.0.0.1`, e só fora de produção). Em produção, a lista de origens vem da variável `CORS_ORIGINS`, separada por vírgulas. O Chrome serve para testar rápido, mas a entrega final é o APK Android.

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
- **Serviços sem estado local** (`catalog_service`, `order_service`, `admin_service`, `profile_service`) são usados direto pelos ViewModels; só a autenticação passa por um Repository, porque também guarda o token.
- **ViewModels base:** `FormViewModel` (carregando + erro geral + erros por campo da API) e `PagedListViewModel` ("Carregar mais", ignora respostas atrasadas quando o filtro muda).
- **Fotos de perfil:** `/api/photo/:id` exige o token, então o `UserAvatar` baixa a imagem pelo `ApiClient` e mostra com `Image.memory`.

## Telas

| Rota | Tela |
|---|---|
| `/` | Splash (restaura a sessão) |
| `/login` | Login |
| `/login/cadastro` | Cadastro (com `PopScope` para não perder dados) |
| `/login/recuperar-senha` | Esqueci a senha: pede o código e define a nova senha (em desenvolvimento o código aparece na tela) |
| `/home` | Área logada com abas conforme o perfil (barra inferior no celular, lateral em tela larga) |

Abas da `/home`, as mesmas do sistema web:

| Aba | Cliente | Prestador | Admin |
|---|---|---|---|
| Início | Categorias (toque abre a busca filtrada) | Pedidos novos, ganhos do mês, próximos atendimentos | Resumo de usuários e pedidos |
| Buscar | Texto, categoria, preço máximo, ordenação e agendamento com horários livres | — | — |
| Serviços | — | Criar, editar e ativar/desativar serviços | — |
| Usuários | — | — | Busca, filtros, criar, editar e desativar contas |
| Pedidos | Detalhe, histórico, cancelar e **Pagar** (Pix ou cartão, simulado) com comprovante | Confirmar, recusar (com motivo), concluir e cancelar | Todos os pedidos, cancelar |
| Pagamentos / Vendas | **Pagamentos**: total pago e comprovantes | **Vendas**: total vendido, taxa Biko (10%) e quanto recebe | **Vendas**: tudo da plataforma |
| Conta | Foto, meus dados, alterar senha, tema e sair | igual | igual |

Na barra de cima tem o **sino 🔔** com o número de notificações não lidas (atualiza a cada 20 s). O histórico mostra o **nome da ação** (ex.: "Pedido confirmado", "Pagamento recebido") e a mensagem, sem data; tocar abre o pedido.

### Microsserviços no app

| Arquivo | O que faz |
|---|---|
| `data/remote/notification_service.dart` | `/api/notificacoes` (lista, contagem, marcar lida) |
| `features/notifications/` | `NotificationsViewModel` (contador + histórico), sino e folha de notificações |
| `data/remote/payment_service.dart` | `/api/orders/:id/pagamento` e `/api/pagamentos` |
| `features/payments/` | folha de pagamento (Pix com QR de demonstração e cartão), comprovante e aba Vendas/Pagamentos |

O pagamento é **simulado** (apresentação do TCC): nada é cobrado. No cartão, `4242 4242 4242 4242` aprova e um final `0002` é recusado. Só os 4 últimos dígitos saem do aparelho; o número inteiro e o CVV não são enviados nem guardados. Se um microsserviço estiver fora do ar, a API responde 503 e o app mostra a mensagem dela (ex.: "O pagamento está fora do ar agora…"); o resto continua funcionando.

## Usuários de teste

Os mesmos do backend: `admin@biko.com` / `Admin@123`, `cliente@biko.com` / `Cliente@123`, `prestador@biko.com` / `Prestador@123`.
