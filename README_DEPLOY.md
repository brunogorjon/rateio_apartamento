# Rateio do Apartamento — publicação compartilhada

Este pacote transforma a calculadora local em uma aplicação compartilhada:

- `index.html`: aplicação;
- `config.js`: URL/chave pública do Supabase e ID do grupo;
- `supabase_setup.sql`: banco, RLS, auditoria e Realtime;
- `.nojekyll`: evita processamento desnecessário pelo Jekyll no GitHub Pages.

## 1. Criar o projeto no Supabase

1. Crie um projeto em https://supabase.com/.
2. No projeto, abra o **SQL Editor**.
3. Abra `supabase_setup.sql` neste pacote.
4. Troque `SEU_EMAIL@EXEMPLO.COM` e os demais exemplos pelos e-mails que poderão editar o rateio.
5. Execute o SQL inteiro.

Quem não estiver em `member_emails` poderá até autenticar no Supabase, mas as políticas RLS não permitirão ler nem alterar o grupo.

## 2. Configurar a autenticação

A aplicação usa **magic link por e-mail**.

No Supabase, em Authentication / URL Configuration:

- durante testes locais, você pode adicionar `http://localhost:8000/**`;
- depois de publicar no GitHub Pages, adicione a URL final, por exemplo:
  `https://SEU-USUARIO.github.io/rateio-apartamento/**`

O usuário digita o e-mail, recebe o link de acesso e volta para o site já autenticado.

## 3. Preencher `config.js`

No painel do Supabase, copie:

- Project URL;
- Publishable key (projetos antigos podem mostrar uma `anon key`).

Preencha:

```js
window.RATEIO_CONFIG = {
  supabaseUrl: 'https://SEU-PROJETO.supabase.co',
  supabasePublishableKey: 'SUA_CHAVE_PUBLICA',
  groupId: 'apartamento-praia-2026'
};
```

Nunca coloque uma **secret key** ou **service_role key** no navegador.

## 4. Testar antes de publicar

Como a aplicação carrega scripts e autenticação web, teste por HTTP em vez de abrir o arquivo diretamente.

Na pasta deste projeto, execute por exemplo:

```bash
python -m http.server 8000
```

Depois abra:

`http://localhost:8000/`

Faça login com um dos e-mails autorizados.

### Migrar os dados da versão antiga

A forma mais segura é:

1. Na calculadora antiga, clique em **Exportar backup**.
2. Na versão compartilhada, faça login.
3. Clique em **Importar backup**.
4. Confirme a importação.

A partir desse momento o Supabase passa a ser a fonte compartilhada dos dados.

## 5. Publicar no GitHub Pages

1. Crie um repositório no GitHub, por exemplo `rateio-apartamento`.
2. Envie os quatro arquivos deste pacote para a raiz do repositório.
3. No GitHub: **Settings → Pages**.
4. Em **Build and deployment**, selecione publicação a partir de uma branch.
5. Selecione `main` e `/ (root)`.
6. Salve.
7. O endereço ficará parecido com:
   `https://SEU-USUARIO.github.io/rateio-apartamento/`
8. Cadastre essa URL também nos Redirect URLs do Supabase Auth.

## 6. Como funciona a colaboração

- todos usam o mesmo registro no Supabase;
- pagamentos e participantes são salvos na nuvem;
- alterações chegam aos outros navegadores via Realtime;
- o registro possui número de revisão para evitar sobrescrita silenciosa em alterações simultâneas;
- o banco mantém snapshots de auditoria em `rateio_audit`;
- o `localStorage` continua apenas como cache/backup local, não como fonte oficial no modo compartilhado.

## 7. Alterar quem pode acessar

No SQL Editor do Supabase:

```sql
update public.rateio_groups
set member_emails = array[
  'voce@email.com',
  'pessoa2@email.com',
  'pessoa3@email.com'
]
where id = 'apartamento-praia-2026';
```

Use e-mails reais e mantenha pelo menos o seu.

## 8. Segurança

A aplicação usa somente a chave pública do Supabase. A proteção dos dados é feita por:

- Supabase Auth;
- Row Level Security (RLS);
- lista de e-mails autorizados;
- privilégios de coluna: o navegador só pode atualizar o campo `data`;
- nenhuma `secret key` fica no front-end.

