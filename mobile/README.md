# Biko Mobile

Aplicativo Flutter do Biko. Consome a API do `server.js` (pasta acima).

> README provisório da Sprint 1. A versão completa (Anexo A do enunciado) entra na Sprint 3.

## Versões

| Item | Versão |
|---|---|
| Flutter | 3.50.x estável (mínimo 3.38) |
| Dart | 3.14 (mínimo 3.10) |
| Pacotes | `dio` 5.11, `go_router` 17.5, `provider` 6.1, `flutter_secure_storage` 11.1, `shared_preferences` 2.5, `image_picker` 1.2, `url_launcher` 6.3 |
| Fonte | Poppins (a do Figma), dentro do app em `assets/fonts` (licença OFL) |

O `go_router` fica na 17.x de propósito. A 18.x já exige o pacote `material_ui`, que o Flutter 3.50 acabou de separar do SDK. Essa migração (`dart fix --apply --code=migrate_design_widgets`) fica para quando o ecossistema estabilizar. Por isso o `flutter analyze` mostra avisos informativos de "deprecated" no `material.dart`: não são erros.

## Primeira execução

```bash
cd mobile
flutter pub get
```

O `AndroidManifest.xml` já vem pronto: permissão de `INTERNET` (sem ela o APK release não acessa a rede), `usesCleartextTraffic` (a API local usa `http://`) e as consultas do `url_launcher` ("Ver rota" no Google Maps e "Ligar").

Se o `flutter` não for reconhecido no terminal, o SDK não está no PATH. Use o caminho completo (ex.: `C:\Users\<você>\...\flutter\bin\flutter.bat`) ou adicione a pasta `flutter\bin` ao PATH do Windows e abra o terminal de novo.

## Rodando

1. Suba o backend na pasta acima: `npm run tudo` (API na porta 3000 + microsserviços de notificações e pagamentos). Só `npm start` também funciona, mas aí o sino e o botão Pagar ficam fora do ar.
2. Rode o app:

```bash
flutter run -d chrome                                      # navegador (usa http://localhost:3000)
flutter run                                                # emulador Android (usa http://10.0.2.2:3000)
flutter run --dart-define=API_URL=http://192.168.0.10:3000 # celular físico (IP do computador na rede)
```

APK para mandar para outras pessoas (API hospedada no Render, veja `render.yaml` na raiz):

```bash
flutter build apk --release --dart-define=API_URL=https://ENDERECO-DO-RENDER.onrender.com
```

O arquivo sai em `build/app/outputs/flutter-apk/app-release.apk`.

Notificações em pop-up: com o app aberto funcionam sempre. Com o app fechado precisam do push do Firebase.
Gere o APK com as chaves do app Android do console do Firebase (as mesmas do `google-services.json`):

```bash
flutter build apk --release --dart-define=API_URL=https://ENDERECO.onrender.com \
  --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_SENDER_ID=... --dart-define=FIREBASE_PROJECT_ID=...
```

O servidor também precisa da chave do Firebase (`serviceAccountKey.json`), que é a mesma usada pelo banco.

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
- **Fotos protegidas:** `/api/photo/:id` e `/api/portfolio/:id/foto` exigem o token, então o `AuthImage` baixa a imagem pelo `ApiClient` e mostra com `Image.memory`.
- **Visual do Figma:** as cores ficam em `core/theme` (`AppColors` e `BikoColors`, com versão clara e escura) e as peças repetidas (cartão, botões, selos, avatar, faixa de dias) em `shared/widgets/biko_ui.dart`. As telas não definem cor solta.
- **Telas empilhadas:** `features/home/app_navigator.dart` abre pedido, chat e perfil por cima da Home (`pushScreen`) levando junto o sino e o contador de conversas.

## Telas

O app segue as 15 telas do Figma (7 de usuário e 8 de prestador), igual ao site: fonte Poppins, azul `#0A84FF` e laranja `#FF9500`.

| Rota | Tela |
|---|---|
| `/` | Splash (restaura a sessão) |
| `/login` | Login com e-mail **ou telefone**; modo cliente e "Área do Prestador". Google/Apple só visuais |
| `/login/cadastro` | Cadastro do cliente (com `PopScope` para não perder dados) |
| `/login/cadastro-profissional` | Cadastro do prestador: **Verificação do Profissional** (CPF válido + maior de 18 + termos) e depois os dados de acesso |
| `/login/recuperar-senha` | Esqueci a senha (em desenvolvimento o código aparece na tela) |
| `/home` | Área logada com abas conforme o perfil |

Abas da `/home`, as mesmas do site:

| Perfil | Abas |
|---|---|
| Cliente | **Início** (busca, "Serviço rápido", avisos de atraso, categorias) · **Buscar** (nota ⭐, Conversar / Agendar, filtros, menor preço, melhor nota) · **Conversas** · **Agenda** (próximos, histórico, pagamentos) |
| Prestador | **Início** (Online/Offline, ganhos da semana, solicitações com Aceitar/Recusar) · **Agenda** (dias, compromissos, horários livres) · **Conversas** · **Ganhos** (saldo, pendente, saque via Pix simulado) · **Perfil** (especialidade, categorias, valor da visita, serviços, portfólio, avaliações) |
| Admin | Início (resumo) · Usuários · Pedidos · Vendas · Conta |

Telas que abrem por cima das abas:

| Cliente | Prestador |
|---|---|
| Perfil público do profissional (serviços, portfólio, avaliações) | Detalhes da Solicitação (cliente desde, serviço, local, pagamento) |
| Escolha Data e Horário (faixa de 14 dias e horários livres) | Serviço em Andamento (linha do tempo, mapa ilustrativo, Ver rota, Iniciar/Antecipar, Avisar atraso, Mais tempo, Concluir) |
| Pagamento Seguro: resumo + Taxa de Proteção Biko (R$ 5,00), Pix ou cartão | Meus Pedidos (todos, com filtro) |
| Pedido Confirmado | Meus Serviços (criar, editar, ativar/desativar, tempo real típico) |
| Detalhe do pedido com **avaliação** (estrelas) depois do serviço | Minha Conta (pela engrenagem do Perfil) |
| Chat com o profissional (atualiza a cada 4 s) | Chat com o cliente |

O sino 🔔 mostra o número de notificações não lidas (atualiza a cada 20 s) e a aba Conversas mostra as mensagens não lidas. Tocar numa notificação abre o pedido.

### Microsserviços no app

| Arquivo | O que faz |
|---|---|
| `data/remote/notification_service.dart` | `/api/notificacoes` (lista, contagem, marcar lida) |
| `features/notifications/` | `NotificationsViewModel` (contador + histórico), sino e folha de notificações |
| `data/remote/payment_service.dart` | `/api/orders/:id/pagamento` e `/api/pagamentos` |
| `features/payments/` | comprovante, "Meus Pagamentos" e aba Vendas (a tela Pagamento Seguro fica em `features/client/views/payment_screen.dart`) |
| `data/remote/chat_service.dart` | `/api/conversas` (lista, conversa, enviar) |
| `data/remote/provider_service.dart` | `/api/prestadores/:id`, `/api/me/profissional`, `/api/me/portfolio` e `/api/carteira` |

O pagamento é **simulado** (apresentação do TCC): nada é cobrado. No cartão, `4242 4242 4242 4242` aprova e um final `0002` é recusado. Só os 4 últimos dígitos saem do aparelho; o número inteiro e o CVV não são enviados nem guardados. Se um microsserviço estiver fora do ar, a API responde 503 e o app mostra a mensagem dela (ex.: "O pagamento está fora do ar agora…"); o resto continua funcionando.

## Usuários de teste

Os mesmos do backend: `admin@biko.com` / `Admin@123`, `cliente@biko.com` / `Cliente@123`, `prestador@biko.com` / `Prestador@123`, `joana@biko.com` / `Joana@123`. Para testar o cadastro do profissional, use o CPF `529.982.247-25`.
