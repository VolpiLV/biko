# Biko — Marketplace de serviços

Atividade avaliativa. Esta versão cobre tudo da tabela de requisitos, menos pagamentos e chat:

1. Login
2. Perfis diferentes (admin, cliente, prestador)
3. Gestão de usuários
4. **Perfil do usuário** (dados, senha, foto)
5. **Agendamento / pedidos / reservas** (com regras de negócio)
6. **Busca** funcional sobre os dados reais
7. **Microsserviço de notificações** (processo e banco próprios) — passo a passo em [`notificacoes/PASSO_A_PASSO.md`](notificacoes/PASSO_A_PASSO.md)
8. **Microsserviço de pagamentos / vendas** (**simulado**, para a apresentação do TCC) — passo a passo em [`pagamentos/PASSO_A_PASSO.md`](pagamentos/PASSO_A_PASSO.md)

O visual segue o protótipo (azul Biko, laranja de destaque, layout de celular).

## Como rodar

Precisa do **Node.js 22.13 ou mais novo** (https://nodejs.org). O banco é o **Firebase (Cloud Firestore)**, então agora tem uma biblioteca: o `firebase-admin`.

```bash
npm install           # só na primeira vez (instala o firebase-admin)
npm run tudo          # sobe a API (3000), as notificações (3001) e os pagamentos (3002)
```

**Ligar no Firebase (uma vez só):**

1. No [console do Firebase](https://console.firebase.google.com), crie um projeto e ative o **Firestore Database** (modo de produção ou teste, tanto faz para a apresentação).
2. ⚙️ Configurações do projeto → **Contas de serviço** → **Gerar nova chave privada**. Baixa um `.json`.
3. Renomeie para `serviceAccountKey.json` e coloque na **raiz do projeto** (do lado do `server.js`). Ele já está no `.gitignore`: não suba para o GitHub.
4. `npm run tudo`. No terminal aparece `Banco: Firebase (Cloud Firestore) — chave serviceAccountKey.json`. Na primeira vez a API grava sozinha os usuários, serviços e pedidos de exemplo.

**Sem a chave**, o projeto roda igual, mas com um Firestore **em memória** (o terminal mostra `Banco: Firestore EM MEMÓRIA`): serve para testar, só que os dados somem ao desligar. Outra opção de chave: variável `FIREBASE_SERVICE_ACCOUNT=caminho/da/chave.json`.

Ou em três terminais: `npm run notificacoes`, `npm run pagamentos` e `npm start`. A API funciona mesmo sem os microsserviços; só o sino ou o botão Pagar ficam fora do ar.

Abra http://localhost:3000.

Para zerar tudo no Firebase, apague as coleções no console do Firestore (users, services, orders, order_events, sessions, password_resets, user_photos, notification_outbox, notificacoes, cobrancas e _contadores). Na próxima vez que subir, os dados de exemplo voltam.

Testes automatizados (128 da API + 10 de cada microsserviço; usam o Firestore em memória e não mexem no seu Firebase):

```bash
npm test
```

## Usuários de demonstração

| Perfil    | E-mail               | Senha          |
|-----------|----------------------|----------------|
| Admin     | admin@biko.com       | Admin@123      |
| Cliente   | cliente@biko.com     | Cliente@123    |
| Prestador | prestador@biko.com   | Prestador@123  |
| Prestador | joana@biko.com       | Joana@123      |

Dados de exemplo: 5 serviços (Carlos e Joana), um pedido da Maria já confirmado e com horário no passado (dá para o Carlos marcar como concluído) e um pedido pendente daqui a 3 dias.

## 1 a 3 — Login, perfis e gestão de usuários

Continuam como na entrega anterior:

- Cadastro com validação, senha com hash `scrypt` + salt, mensagem de erro genérica no login, bloqueio depois de 5 falhas em 10 min, recuperação de senha com código de uso único (30 min) e sessão em cookie `HttpOnly` de 7 dias.
- Cada rota da API declara quais perfis podem acessar (sem login → `401`, perfil errado → `403`). A interface só esconde o que não é do perfil; a proteção de verdade está no backend.
- O admin lista (busca, filtro por perfil e status), cria, edita, ativa/desativa e muda o perfil dos usuários. Não pode desativar nem rebaixar a própria conta.

## 4 — Perfil do usuário (aba *Conta*)

- **Editar dados**: nome, telefone e e-mail. Trocar o e-mail (que é o login) pede a **senha atual**. O perfil (admin/cliente/prestador) e o status não mudam por aqui, nem se alguém mandar `role` na requisição.
- **Trocar senha**: pede a senha atual, a nova precisa seguir a regra (8+ caracteres, letras e números) e ser diferente da atual. Depois da troca as **outras sessões** (outros aparelhos) são encerradas e a atual continua. Tem limite de tentativas na senha atual (429).
- **Foto**: o navegador recorta no centro e reduz para 256×256 antes de enviar. O servidor aceita PNG, JPG ou WEBP, confere os bytes do arquivo (não confia só no tipo declarado) e limita a 200 KB. A foto fica no banco e aparece no cabeçalho, nos resultados de busca e nos pedidos. Dá para trocar e remover.
- **Persistência**: tudo é gravado no Firebase (Cloud Firestore); ao sair e entrar de novo os dados e a foto continuam lá.

## 5 — Agendamento / pedidos

O prestador cadastra seus **serviços** (aba *Serviços*: título, categoria, descrição, preço e duração). O cliente escolhe um serviço na busca e agenda data, horário e endereço.

**Regras na criação do pedido**

- Só cliente cria pedido. O serviço e o prestador precisam estar ativos.
- Atendimento das **07:00 às 20:00**; o horário final vem da duração do serviço e não pode passar das 20:00. Horários em múltiplos de 15 min.
- Antecedência mínima de **1 hora** e máxima de **60 dias**. Datas inexistentes (ex.: 31/02) são recusadas.
- **Conflito de horário**: o prestador não pode ter dois pedidos (pendentes ou confirmados) se sobrepondo, e o cliente também não. Horário "colado" (um termina às 11:00 e outro começa às 11:00) é permitido. Se duas pessoas pedirem o mesmo horário ao mesmo tempo, só uma passa (a checagem e a gravação são uma transação). Pedido recusado ou cancelado libera o horário.
- Na tela, os horários já ocupados aparecem desabilitados (vem de `GET /api/providers/:id/agenda`, que não expõe quem agendou).
- O título e o preço são copiados para o pedido, então mudar o preço do serviço depois não altera pedidos antigos.

**Status e quem pode mudar**

| De            | Ação       | Quem faz                     | Para        | Regras |
|---------------|------------|------------------------------|-------------|--------|
| pendente      | confirmar  | prestador do pedido          | confirmado  | |
| pendente      | recusar    | prestador do pedido          | recusado    | motivo obrigatório |
| confirmado    | concluir   | prestador do pedido          | concluído   | só depois do horário agendado |
| pendente / confirmado | cancelar | cliente, prestador ou admin | cancelado | prestador/admin: motivo obrigatório; cliente: opcional, e pedido **confirmado** só até 2 h antes |

**Agenda elástica (imprevistos no atendimento)**

A duração cadastrada no serviço é o tempo **normal**, sem "gordura". Os imprevistos são tratados durante o atendimento:

| Ação | Quem | Regras |
|------|------|--------|
| avisar atraso ("Avisar atraso / imprevisto") | prestador | **antes** de iniciar (pedido pendente ou confirmado); +15, 30, 45 ou 60 min; motivo obrigatório (ex.: falta de luz, equipamento quebrado). Ex.: 11:00 vira 11:30. No máximo 4 h de atraso somado e nunca terminando depois das 22:00 |
| iniciar | prestador | pedido confirmado, a qualquer momento; só um atendimento em andamento por vez. Até 30 min antes conta como "no horário". **Mais cedo que isso é antecipar**: pede confirmação, o pedido passa a começar na hora, o horário antigo fica livre e o cliente é avisado (recusado se bater com outro pedido do prestador ou do cliente). Se começar atrasado, o tempo do serviço conta a partir do início real |
| estender ("Preciso de mais tempo") | prestador | só com o atendimento iniciado; +15, 30, 45 ou 60 min; motivo obrigatório; no máximo 4 h a mais e nunca depois das 22:00 |
| concluir | prestador | pode concluir antes do fim previsto se já iniciou; o restante do horário é liberado na agenda na hora |

- Quando o atendimento passa do horário, os próximos pedidos do prestador que se sobrepõem são **remarcados em cascata** (arredondado para 5 min). Um intervalo livre entre pedidos absorve o atraso e a cascata para ali.
- O cliente remarcado vê o horário antigo, o novo e o **motivo**, na tela do pedido e num quadro **Avisos** na tela inicial, e pode **cancelar sem a regra das 2 h**.
- Na aba *Serviços* aparece o **tempo real típico** (mediana dos últimos 20 atendimentos) e, a partir de 3 atendimentos, a sugestão de duração.
- Os eventos `atrasado`, `iniciado`, `prorrogado` e `remarcado` aparecem no histórico do pedido.

- Pedido recusado, concluído ou cancelado é final: qualquer nova ação dá `409`.
- Quem não participa do pedido recebe `404` (como se não existisse); o admin vê todos.
- O telefone da outra parte só aparece depois que o pedido é confirmado.
- **Histórico**: cada mudança grava o novo status, quem fez, quando e o motivo (aparece no detalhe do pedido).
- O painel do prestador mostra pedidos novos, ganhos do mês (soma dos concluídos) e os próximos atendimentos.

## 6 — Busca

Aba *Buscar* do cliente. Procura nos serviços ativos de prestadores ativos:

- Texto livre em título, categoria, descrição e nome do prestador, **sem diferenciar maiúscula nem acento** ("encanadór" acha "Encanador"). Várias palavras funcionam como "E": todas precisam aparecer.
- Filtros por categoria e preço máximo; ordenação por relevância, menor preço, maior preço ou nome; paginação (`limit`/`offset`).
- A busca é feita no código (não com `LIKE`), então `%`, `_` e aspas não viram curinga nem quebram nada.
- Sem resultado, a tela mostra "Nenhum resultado encontrado" com o botão **Limpar filtros**, e o contador mostra 0.
- Serviço de prestador desativado (ou que virou cliente) some da busca na hora.

## 7 — Microsserviço de notificações

Cada ação num pedido (novo pedido, confirmar, recusar, cancelar, aviso de atraso, iniciar, prorrogar, concluir, remarcação) vira uma notificação para a outra parte. O título é o **nome da ação**. No topo da tela tem um sino 🔔 com o número de não lidas; o histórico de notificações mostra o nome da ação e a mensagem (sem data), e tocar abre o pedido.

- Roda num **processo separado** (`notificacoes/`, porta 3001) com **banco próprio** (`notificacoes.db`).
- A API grava o evento numa caixa de saída (`notification_outbox`) na mesma transação do pedido, e o `notificador.js` entrega ao microsserviço. Se ele cair, nada se perde: é reenviado quando voltar.
- O navegador só fala com a API principal (`/api/notificacoes`), que confere o login. Entre a API e o microsserviço vai a chave `X-Service-Key`.

Detalhes, diagrama e roteiro de apresentação: [`notificacoes/PASSO_A_PASSO.md`](notificacoes/PASSO_A_PASSO.md).

## 8 — Microsserviço de pagamentos / vendas (simulado)

> Simulação para a apresentação do TCC: nada é cobrado e nenhum banco é chamado.

- Depois que o prestador confirma, o cliente vê o botão **Pagar** no pedido: **Pix** (QR e copia e cola de demonstração, botão "Simular pagamento") ou **cartão** (1x a 3x; `4242 4242 4242 4242` aprova, final `0002` recusa). Só o final do cartão sai do navegador.
- Pagamento aprovado: selo **Pago** no pedido, registro no histórico, **comprovante** e notificação "Pagamento recebido" para o prestador.
- Taxa da plataforma de 10%. Abas **Pagamentos** (cliente) e **Vendas** (prestador/admin) com total, taxa e líquido.
- Pedido pago e cancelado é **estornado** automaticamente.
- Processo separado (`pagamentos/`, porta 3002) com banco próprio (`pagamentos.db`).

Detalhes e roteiro de apresentação: [`pagamentos/PASSO_A_PASSO.md`](pagamentos/PASSO_A_PASSO.md).

## 9 — Telas do protótipo (Figma)

O site segue as 15 telas do Figma (7 de usuário e 8 de prestador), com fonte Poppins, azul `#0A84FF` e laranja `#FF9500`.

| Usuário (cliente) | Prestador |
|---|---|
| Login (e-mail **ou telefone**), Google/Apple só visuais | Login "Área do Prestador" |
| Início com busca, card "Serviço rápido" e categorias | Cadastro com **Verificação do Profissional**: CPF válido + maior de 18 anos + termos |
| Busca com profissionais, nota ⭐, Conversar / Agendar | Início: Online/Offline, ganhos da semana, solicitações (Aceitar/Recusar) |
| Escolha de data (faixa de dias) e horários | Detalhes da Solicitação |
| Pagamento Seguro: resumo + **Taxa de Proteção Biko (R$ 5,00)**, Pix ou cartão | Serviço em Andamento: linha do tempo, mapa ilustrativo, Iniciar/Concluir |
| Pedido Confirmado | Sua Agenda: dias, compromissos, horários livres |
| **Conversas** (chat com o profissional) | Ganhos e Carteira: saldo, pendente, saque via Pix (simulado) |
| Agenda do cliente + **avaliação** depois do serviço | Perfil Profissional: categorias, valor da visita, serviços, portfólio de fotos |

Mudanças de regra que vieram das telas:
- O cliente **paga ao agendar** (antes só depois da confirmação). Se o prestador recusar ou cancelar, o valor é **estornado**.
- Prestador **offline** ou com a categoria desligada não aparece na busca.
- Busca pode ordenar por **melhor nota**.

Rotas novas: `/api/conversas` (GET, `/:id` GET/POST), `/api/orders/:id/avaliacao` (POST), `/api/prestadores/:id` (GET), `/api/me/profissional` (GET/PATCH), `/api/me/portfolio` (POST, `/:id` DELETE), `/api/portfolio/:id/foto` (GET), `/api/carteira` (GET), `/api/carteira/saque` (POST), `/api/auth/verificar-profissional` (POST).
Coleções novas no Firestore: `messages`, `reviews`, `portfolio`, `withdrawals`.

O app Flutter (pasta `mobile/`) ainda está no visual antigo.

## Estrutura

```
biko/
├── server.js        # servidor HTTP + rotas da API + regras de acesso e de negócio
├── firebase.js      # conexão com o Firebase (chave da conta de serviço) ou Firestore em memória
├── firestore-memoria.js # Firestore em memória (testes e uso sem chave)
├── store.js         # acesso às coleções do Firestore (ids numéricos, trava de concorrência)
├── db.js            # coleções da API, hash de senha, dados de exemplo
├── test.js          # testes automatizados do backend (121)
├── servicos.js      # chamada HTTP comum aos microsserviços
├── notificador.js   # ponte com o microsserviço: caixa de saída, reenvio e consulta
├── iniciar.js       # "npm run tudo": sobe os dois processos
├── notificacoes/    # MICROSSERVIÇO de notificações (porta 3001, coleção notificacoes)
│   ├── server.js
│   ├── db.js
│   ├── test.js
│   └── PASSO_A_PASSO.md
├── pagamentos/      # MICROSSERVIÇO de pagamentos SIMULADO (porta 3002, coleção cobrancas)
│   ├── server.js
│   ├── db.js
│   ├── test.js
│   └── PASSO_A_PASSO.md
├── historico/       # histórico de raciocínio (um arquivo por ação, nome = nome da ação)
└── public/
    ├── index.html
    ├── style.css
    └── app.js       # telas: login, cadastro, recuperação, início, busca, pedidos, serviços, conta, usuários
```

Coleções do Firestore: `users`, `sessions`, `password_resets`, `user_photos`, `services`, `orders`, `order_events`, `notification_outbox` (API) e `_contadores` (ids numéricos). Os microsserviços têm as suas: `notificacoes` e `cobrancas`.

## Rotas da API

| Método | Rota                          | Quem acessa            |
|--------|-------------------------------|------------------------|
| POST   | /api/auth/register            | público                |
| POST   | /api/auth/login               | público                |
| POST   | /api/auth/forgot              | público                |
| POST   | /api/auth/reset               | público                |
| GET    | /api/auth/me                  | logado                 |
| POST   | /api/auth/logout              | logado                 |
| PATCH  | /api/me                       | logado (própria conta) |
| POST   | /api/me/password              | logado                 |
| PUT    | /api/me/photo                 | logado                 |
| DELETE | /api/me/photo                 | logado                 |
| GET    | /api/photo/:id                | logado                 |
| GET    | /api/categories               | logado                 |
| GET    | /api/search?q=&category=&max_price=&sort=&limit=&offset= | logado |
| GET    | /api/providers/:id/agenda?date=AAAA-MM-DD | logado     |
| GET    | /api/services/mine            | prestador              |
| POST   | /api/services                 | prestador              |
| PATCH  | /api/services/:id             | prestador (dono)       |
| POST   | /api/orders                   | cliente                |
| GET    | /api/orders?status=           | logado (cada um vê os seus; admin vê todos) |
| GET    | /api/orders/:id               | participantes e admin  |
| POST   | /api/orders/:id/status        | conforme a tabela de status |
| GET    | /api/cliente/home             | cliente, admin         |
| GET    | /api/prestador/painel         | prestador, admin       |
| GET    | /api/users?search=&role=&status= | admin               |
| POST   | /api/users                    | admin                  |
| PATCH  | /api/users/:id                | admin                  |
| POST   | /api/users/:id/password       | admin                  |
| GET    | /api/notificacoes?limit=&offset=&nao_lidas=1 | logado (só as próprias) |
| GET    | /api/notificacoes/contagem    | logado                 |
| POST   | /api/notificacoes/:id/lida    | logado (só as próprias) |
| POST   | /api/notificacoes/lidas       | logado                 |
| POST   | /api/orders/:id/pagamento     | cliente do pedido      |
| POST   | /api/orders/:id/pagamento/confirmar | cliente do pedido (simular Pix) |
| GET    | /api/orders/:id/pagamento     | participantes e admin  |
| GET    | /api/pagamentos               | logado (cada um vê o seu; admin vê tudo) |

## Observações

- Datas e horários dos pedidos usam o fuso do computador onde o servidor roda.
- Na recuperação de senha o código aparece na tela e no console (modo demonstração); em produção iria por e-mail.
- **Fora do escopo**: chat, pagamento real (o de agora é simulado) e avaliações dos prestadores (a "Avaliação" do painel fica em "—").
