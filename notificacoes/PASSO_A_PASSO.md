# Microsserviço de Notificações do Biko — passo a passo

## Por que esse microsserviço

O Biko já tinha tudo num processo só (`server.js`): login, usuários, serviços, busca e pedidos. O que faltava era **avisar as pessoas** quando algo acontece com o pedido delas. Hoje o cliente só descobre que o pedido foi confirmado se abrir a aba Pedidos, e o prestador só vê pedido novo se entrar no painel.

Notificação é a parte mais fácil de separar num microsserviço:

- não faz parte da regra principal (se as notificações caírem, agendar pedido tem que continuar funcionando);
- tem dados próprios (quem recebeu, o que foi lido), que não precisam ficar no banco dos pedidos;
- depois pode crescer sozinha (e-mail, push no celular, WhatsApp) sem mexer na API principal.

## Como ficou a arquitetura

```
 Navegador / app                API principal (porta 3000)                 Microsserviço de notificações (porta 3001)
 ───────────────                ─────────────────────────                  ──────────────────────────────────────────
                                server.js  ── biko.db                      notificacoes/server.js ── notificacoes.db
 sino 🔔  ── /api/notificacoes ──►  confere o login  ── X-Service-Key ──►  GET  /usuarios/:id/notificacoes
                                                                           POST /usuarios/:id/notificacoes/:n/lida
 ações no pedido ─ /api/orders ─►  grava o pedido + evento
                                   na caixa de saída (outbox)
                                notificador.js (a cada 2 s) ── POST ────►  POST /eventos  → decide quem recebe e o texto
```

São **dois processos** e **dois bancos**. Um não lê o banco do outro: eles só conversam por HTTP.

## Passo a passo do funcionamento

### 1. Algo acontece num pedido

Qualquer ação no pedido (criar, confirmar, recusar, cancelar, avisar atraso, iniciar, prorrogar, concluir, remarcação em cascata) já gravava um registro no histórico do pedido pela função `addEvent()` do `server.js`.

### 2. O evento vai para a caixa de saída (outbox)

Dentro dessa mesma função, `notificador.publicar()` grava o evento na tabela `notification_outbox` do `biko.db`, **na mesma transação** do pedido. Então:

- se o pedido não for gravado, a notificação também não existe;
- a API **não chama a rede aqui**, então confirmar um pedido nunca fica lento nem dá erro por causa das notificações.

O evento leva só o necessário: id do evento, nome da ação, id do pedido, serviço, data e hora, id do cliente, id do prestador, quem fez a ação e a observação/motivo.

### 3. O notificador entrega o evento ao microsserviço

Enquanto a API está no ar, o `notificador.js` olha a caixa de saída a cada 2 segundos e manda os pendentes para `POST /eventos` do microsserviço, com a chave `X-Service-Key`.

- Deu certo → marca o evento como enviado.
- O microsserviço está fora do ar → o evento **fica esperando** e é reenviado depois (2 s, 4 s, 8 s… até 60 s entre tentativas). Nada se perde.

### 4. O microsserviço decide quem recebe e o que vai escrito

Em `notificacoes/server.js` fica a tabela `ACOES`, uma regra por ação. O **título da notificação é o nome da ação**:

| Ação do pedido | Título da notificação | Quem recebe |
|---|---|---|
| pedido criado | Novo pedido | prestador |
| confirmar | Pedido confirmado | cliente |
| recusar | Pedido recusado (com motivo) | cliente |
| cancelar | Pedido cancelado (com motivo) | a outra parte (se foi o admin, os dois) |
| concluir | Serviço concluído | cliente |
| avisar atraso | Aviso de atraso (novo horário e motivo) | cliente |
| iniciar | Atendimento iniciado | cliente |
| preciso de mais tempo | Tempo prorrogado | cliente |
| remarcação em cascata | Horário remarcado | cliente |
| pagamento aprovado (microsserviço de pagamentos) | Pagamento recebido | prestador |
| estorno de pedido pago cancelado | Pagamento estornado | a outra parte |

Duas regras valem para todas:

- **quem fez a ação não é notificado** (o prestador que confirmou não recebe "Pedido confirmado");
- **o mesmo evento chegando duas vezes não duplica** (o banco tem `UNIQUE(evento_id, usuario_id)`). Isso importa porque o notificador reenvia quando dá erro.

### 5. O usuário abre o sino 🔔

No topo da tela aparece um sino com o número de notificações não lidas (atualiza sozinho a cada 20 s e depois de cada ação).

Ao tocar no sino abre o **histórico de notificações**. Cada item mostra o **nome da ação** em destaque (ex.: "Pedido confirmado", "Aviso de atraso") e a mensagem, **sem a data**. As não lidas ficam azuladas com um ponto laranja.

- Tocar numa notificação marca como lida e abre o pedido.
- "Marcar todas como lidas" zera o contador.

O navegador **nunca fala direto** com o microsserviço. Ele chama a API principal (`/api/notificacoes`), que confere o login e repassa a chamada usando o id de quem está logado. Assim ninguém consegue ler a notificação de outra pessoa trocando o id na URL.

### 6. Se o microsserviço cair

- O sino fica sem número e, ao abrir, aparece: "As notificações estão fora do ar agora. O resto do Biko continua funcionando normalmente."
- Pedidos, busca, login etc. continuam normais.
- Quando o microsserviço volta, a caixa de saída entrega tudo o que ficou para trás.

## Rotas do microsserviço (uso interno, só a API principal chama)

Todas pedem o cabeçalho `X-Service-Key` (menos `/saude`). Ele só escuta em `127.0.0.1`.

| Método | Rota | O que faz |
|---|---|---|
| GET | /saude | diz se o serviço está no ar |
| POST | /eventos | recebe um evento de pedido e cria as notificações |
| GET | /usuarios/:id/notificacoes?limit=&offset=&nao_lidas=1 | lista (mais novas primeiro) + total de não lidas |
| GET | /usuarios/:id/notificacoes/contagem | só o número de não lidas |
| POST | /usuarios/:id/notificacoes/:n/lida | marca uma como lida (de outro usuário dá 404) |
| POST | /usuarios/:id/notificacoes/lidas | marca todas como lidas |

## Rotas novas na API principal (o site/app usa estas)

| Método | Rota | Quem acessa |
|---|---|---|
| GET | /api/notificacoes?limit=&offset=&nao_lidas=1 | logado |
| GET | /api/notificacoes/contagem | logado |
| POST | /api/notificacoes/:id/lida | logado (só as próprias) |
| POST | /api/notificacoes/lidas | logado |

## Como rodar

Precisa do Node.js 22.13 ou mais novo. Continua sem `npm install`.

**Jeito fácil (os dois de uma vez):**

```bash
npm run tudo
```

**Jeito "microsserviço de verdade" (dois terminais):**

```bash
# terminal 1 — microsserviço de notificações (porta 3001)
npm run notificacoes

# terminal 2 — API principal + site (porta 3000)
npm start
```

Abra http://localhost:3000, entre como `prestador@biko.com / Prestador@123` e toque no sino.

**Para mostrar na apresentação que é independente:**

1. Com os dois rodando, entre como cliente e agende um serviço.
2. Pare o terminal 1 (Ctrl+C). Entre como prestador e confirme o pedido: funciona normalmente. O sino mostra o aviso de fora do ar.
3. Suba o terminal 1 de novo. Em até 2 segundos o cliente recebe "Pedido confirmado". Nada se perdeu.

## Configuração (variáveis de ambiente, todas opcionais)

| Variável | Padrão | Onde |
|---|---|---|
| NOTIF_PORT | 3001 | microsserviço |
| NOTIF_HOST | 127.0.0.1 | microsserviço |
| NOTIF_DB | notificacoes/notificacoes.db | microsserviço |
| NOTIF_URL | http://127.0.0.1:3001 | API principal |
| NOTIF_KEY | biko-dev-key | **os dois** (tem que ser igual). Em produção, troque por uma chave forte. |

## Testes

```bash
npm test
```

Roda os testes da API principal (111, com 12 novos de notificações: fora do ar, fila entregue quando volta, quem recebe, marcar lida, idempotência, chave de serviço) e os 10 testes do microsserviço sozinho (`notificacoes/test.js`).

## Arquivos novos e alterados

```
notificacoes/            ← o microsserviço
├── server.js            regras (ACOES), rotas e servidor HTTP na porta 3001
├── db.js                banco próprio notificacoes.db (tabela notificacoes)
├── test.js              testes do microsserviço sozinho
├── package.json
└── PASSO_A_PASSO.md     este arquivo
notificador.js           ponte: caixa de saída + entrega com nova tentativa + consulta
iniciar.js               sobe os dois processos com "npm run tudo"
server.js                addEvent publica o evento; rotas /api/notificacoes
db.js                    tabela notification_outbox
public/app.js, style.css sino 🔔 com contador e histórico de notificações
test.js                  12 testes novos
```

## Próximos passos possíveis

- ~~Mostrar o sino também no app Flutter~~ — feito: o app (pasta `mobile/`) já tem o sino e o histórico de notificações.
- Mandar e-mail ou push além da notificação dentro do app: só o microsserviço muda.
