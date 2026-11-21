# Demonstração no navegador (link para testar pelo celular)

Gera uma página que roda o Biko inteiro **dentro do navegador**: a API principal, o microsserviço de notificações e o de pagamentos (o mesmo código do projeto, sem mudar nada), cada um com seu banco SQLite (via sql.js).

```bash
node demo-navegador/build.js   # cria demo-navegador/saida/ (index.html, app.js, backend.js)
```

Para abrir no computador, sirva a pasta `saida/` (ex.: `npx serve demo-navegador/saida`). O sql.js vem do CDN jsDelivr.

- Botão **🧪 Demo** no topo: entrar rápido como cliente/prestador/admin, desligar um microsserviço (para mostrar que o resto continua funcionando) e recomeçar do zero.
- Os dados ficam só naquele navegador.
- É só para apresentação: a senha usa um hash simples no lugar do scrypt.
