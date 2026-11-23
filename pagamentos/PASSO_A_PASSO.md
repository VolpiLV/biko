# Microsserviço de Pagamentos / Vendas do Biko — passo a passo

> **É uma simulação, feita para a apresentação do TCC.** Nenhum dinheiro é cobrado, nenhum banco é chamado e o código Pix não funciona em app de banco nenhum. O fluxo, as telas e os registros de venda funcionam de verdade, então dá para apresentar o app como se estivesse pagando.

## Por que esse microsserviço

Era o item que faltava no Biko (pagamentos estava "fora do escopo"). Pagamento é um exemplo clássico de microsserviço:

- tem regras próprias (Pix que expira, cartão aprovado ou recusado, estorno, taxa da plataforma);
- tem dados que ninguém mais precisa ver (cobranças, autorizações);
- no mundo real ele seria trocado por um gateway (Mercado Pago, Stripe, Pagar.me…) **sem mexer no resto do app**, porque o resto só conversa com ele por HTTP.

## Como ficou a arquitetura

```
 Navegador / app              API principal (porta 3000)                   Microsserviço de pagamentos (porta 3002)
 ───────────────              ─────────────────────────                    ────────────────────────────────────────
                              server.js ── Firestore (orders...)           pagamentos/server.js ── Firestore (cobrancas)
 "Pagar R$ 120" ─ POST ─────► confere: é o cliente? pedido confirmado? ──► POST /cobrancas      (cria Pix ou cobra cartão)
 "Simular pagamento" ───────► ─────────────────────────────────────────► POST /cobrancas/:id/confirmar
                              grava "pago" no pedido + histórico
                                 └─► caixa de saída ─► microsserviço de notificações ─► "Pagamento recebido" 🔔
 cancelar pedido pago ──────► ─────────────────────────────────────────► POST /cobrancas/:id/estornar
 aba Vendas / Pagamentos ───► ─────────────────────────────────────────► GET  /cobrancas?recebedor_id=…  (lista + resumo)
```

Agora o Biko tem **três processos**: a API principal e dois microsserviços. Cada um com o seu banco.

## Passo a passo do funcionamento

### 1. Quando o cliente pode pagar

O botão laranja **"💳 Pagar R$ …"** aparece no detalhe do pedido só quando:

- quem está olhando é o **cliente** daquele pedido;
- o pedido está **confirmado** ou **concluído** (o prestador precisa aceitar antes);
- ele ainda não foi pago.

A API confere tudo isso de novo no servidor. Prestador tentando pagar recebe `403`, pedido pendente dá `409` e pagar duas vezes também dá `409`.

### 2. Escolher a forma de pagamento

Em todas as telas de pagamento aparece o aviso roxo **"Ambiente de demonstração (TCC): nenhum valor é cobrado"**.

**Pix**

1. Toca em "Gerar Pix". O microsserviço cria a cobrança com status **aguardando**, um código "copia e cola" e validade de 30 minutos.
2. A tela mostra um QR Code (é um desenho gerado a partir do código, não é um QR de verdade), o código com botão **Copiar** e a contagem regressiva.
3. Toca em **"✅ Simular pagamento recebido (demo)"**. No mundo real quem avisaria seria o banco; aqui é o botão. O microsserviço muda para **aprovado** e gera um número de autorização.
4. Se fechar a tela antes de pagar, o pedido fica com o selo "Aguardando Pix" e o botão vira "Continuar pagamento".
5. Gerar outro Pix para o mesmo pedido cancela o anterior. Pix vencido vira "expirado".

**Cartão de crédito**

1. Um cartão desenhado vai se preenchendo enquanto a pessoa digita (número, nome e bandeira detectada: Visa, Mastercard ou Elo).
2. Escolhe **1x, 2x ou 3x sem juros**.
3. Para a apresentação:
   - `4242 4242 4242 4242` → **aprovado** na hora;
   - qualquer cartão terminado em **0002** → **recusado** ("Cartão recusado pelo banco emissor"), para mostrar o caso de erro.
4. **Só os 4 últimos dígitos, a bandeira e as parcelas saem do navegador.** O número inteiro e o CVV nunca vão para o servidor e nada disso é guardado.

### 3. Pagamento aprovado

A API principal, numa transação só:

- marca o pedido como **pago** (aparece o selo verde "✓ Pago" na lista de pedidos);
- grava no **histórico do pedido**: "Pagamento aprovado — R$ 120,00 via Pix — comprovante BKP-…";
- esse registro entra na caixa de saída e o **microsserviço de notificações** avisa o prestador com **"Pagamento recebido"** 💰.

Aí o cliente vê o **comprovante**: ✓ verde, valor, serviço, quem pagou, quem recebeu, forma de pagamento, data, código da transação e autorização.

### 4. Taxa da plataforma (a "venda" do Biko)

Cada pagamento é dividido assim:

| | Exemplo (R$ 120,00) |
|---|---|
| Valor pago pelo cliente | R$ 120,00 |
| Taxa Biko (10%) | R$ 12,00 |
| Líquido do prestador | R$ 108,00 |

### 5. Abas Vendas e Pagamentos

Tem uma aba nova na barra de baixo:

- **Cliente → "Pagamentos"**: quantos pagou, total pago, estornos e a lista de comprovantes.
- **Prestador → "Vendas"**: total vendido, taxa Biko e **quanto ele recebe**. Na lista aparece o valor líquido de cada venda.
- **Admin → "Vendas"**: tudo o que foi vendido na plataforma, quanto ficou de taxa e quanto foi repassado.

Tocar em qualquer item abre o comprovante. Prestador e admin também veem a taxa e o líquido.

### 6. Cancelou um pedido pago? Estorno automático

Se um pedido **pago** for cancelado (pelo prestador ou pelo admin):

1. o pedido fica como "Estorno em andamento";
2. a API pede `POST /cobrancas/:id/estornar` ao microsserviço;
3. deu certo: o pedido fica **"Estornado"**, entra no histórico ("R$ 120,00 devolvido ao cliente") e o cliente recebe a notificação **"Pagamento estornado"**;
4. se o microsserviço estiver fora do ar, a API tenta de novo a cada 10 segundos até conseguir.

### 7. Se o microsserviço de pagamentos cair

O botão Pagar responde: "O pagamento está fora do ar agora. Tente de novo em instantes; o pedido continua valendo." Pedidos, busca, agenda e notificações continuam funcionando.

## No app Flutter

O app (pasta `mobile/`) tem o mesmo fluxo: botão laranja **Pagar** no detalhe do pedido, folha de pagamento com Pix (QR de demonstração, copiar código, contagem e "Simular pagamento recebido") ou cartão (cartão desenhado, parcelas 1x–3x), comprovante, selo **✓ Pago** na lista e aba **Pagamentos** (cliente) / **Vendas** (prestador e admin). Também só manda os 4 últimos dígitos do cartão.

## Rotas do microsserviço (uso interno, só a API principal chama)

Todas pedem `X-Service-Key` (menos `/saude`). Ele só escuta em `127.0.0.1`.

| Método | Rota | O que faz |
|---|---|---|
| GET | /saude | diz se está no ar (e que é simulado) |
| POST | /cobrancas | cria uma cobrança Pix (aguardando) ou cartão (aprovado/recusado na hora) |
| POST | /cobrancas/:id/confirmar | simula o banco avisando que o Pix foi pago |
| POST | /cobrancas/:id/estornar | devolve um pagamento aprovado |
| GET | /cobrancas/:id | uma cobrança (comprovante) |
| GET | /cobrancas?pedido_id=&pagador_id=&recebedor_id=&limit=&offset= | lista + resumo (vendas, bruto, taxa, líquido, Pix, cartão, estornos) |

## Rotas novas na API principal

| Método | Rota | Quem acessa |
|---|---|---|
| POST | /api/orders/:id/pagamento `{metodo: "pix"}` ou `{metodo: "cartao", cartao: {final, bandeira, parcelas}}` | cliente do pedido |
| POST | /api/orders/:id/pagamento/confirmar | cliente do pedido (simular Pix) |
| GET | /api/orders/:id/pagamento | cliente, prestador do pedido e admin |
| GET | /api/pagamentos?limit=&offset= | logado (cliente: o que pagou; prestador: o que vendeu; admin: tudo) |

O pedido (`GET /api/orders/...`) ganhou dois campos: `payment` (`{status, code}`) e `can_pay`.

## Como rodar

```bash
npm run tudo        # API (3000) + notificações (3001) + pagamentos (3002)
```

Ou em três terminais: `npm run notificacoes`, `npm run pagamentos` e `npm start`.

## Roteiro para a apresentação

1. Entre como **cliente** (`cliente@biko.com / Cliente@123`) → aba Pedidos → abra o pedido **Confirmado** → **Pagar R$ 120,00**.
2. Escolha **Cartão**, digite um cartão terminado em **0002** → aparece a **recusa**.
3. Troque para **Pix** → Gerar Pix → mostre o QR e o código → **Simular pagamento** → **comprovante**.
4. Mostre o selo **✓ Pago** na lista e a aba **Pagamentos**.
5. Entre como **prestador** (`prestador@biko.com / Prestador@123`) → o sino 🔔 tem **"Pagamento recebido"** → aba **Vendas** com a taxa de 10% e o líquido.
6. (Opcional) Pare só o terminal dos pagamentos e tente pagar outro pedido: aparece o aviso de fora do ar e o resto do app continua funcionando.

## Configuração (opcional)

| Variável | Padrão | Onde |
|---|---|---|
| PAG_PORT | 3002 | microsserviço |
| PAG_HOST | 127.0.0.1 | microsserviço |
| PAG_URL | http://127.0.0.1:3002 | API principal |
| PAG_KEY | biko-dev-key | os dois (tem que ser igual) |

## Testes

`npm test` roda tudo: 120 testes da API (9 novos de pagamento), 10 do microsserviço de notificações e 10 deste microsserviço (`pagamentos/test.js`).

## Arquivos novos e alterados

```
pagamentos/              ← o microsserviço (simulado)
├── server.js            regras: Pix, cartão, recusa 0002, taxa 10%, estorno, resumo de vendas
├── db.js                banco próprio pagamentos.db (tabela cobrancas)
├── test.js
├── package.json
└── PASSO_A_PASSO.md     este arquivo
servicos.js              chamada HTTP comum aos dois microsserviços (chave + tempo limite)
server.js                rotas de pagamento, estorno automático, campos payment/can_pay no pedido
db.js                    colunas payment_status, payment_id, payment_code em orders
notificacoes/server.js   duas ações novas: "Pagamento recebido" e "Pagamento estornado"
public/app.js, style.css botão Pagar, telas de Pix e cartão, comprovante, abas Vendas/Pagamentos
iniciar.js               agora sobe os três processos
```
