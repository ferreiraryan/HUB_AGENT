# Instruções para agentes

Este arquivo contém as boas práticas para qualquer agente que altere este
repositório. Antes de começar, leia também o [CONTEXT.md](./CONTEXT.md), que
descreve o estado atual, as decisões arquiteturais e as pendências conhecidas.

## Regras obrigatórias

1. Explore os arquivos relevantes antes de editar. Não assuma que o README ou
   um contexto antigo representa o código atual.
2. Preserve a separação entre os componentes:
   - `packages/agent_core` é Dart puro e não pode importar Flutter.
   - `apps/cms_app` é a aplicação Flutter desktop.
   - `dashboard_web` é o cliente web do tablet.
3. Não altere o contrato MQTT ou o JSON publicado sem atualizar conjuntamente
   o golden test em `packages/agent_core/test/fixtures/` e o dashboard.
4. Nunca coloque `bindings` ou comandos locais arbitrários no payload publicado.
   Bindings são configuração local, lida pelo agente a partir do disco.
5. Reutilize os modelos, serviços e fábricas existentes antes de criar uma
   implementação paralela. Siga o estilo e os nomes já usados no componente.
6. Faça mudanças pequenas e completas. Não misture refatorações, formatação
   ampla ou correções não relacionadas ao objetivo da tarefa.
7. Preserve alterações locais existentes. Consulte `git status` antes de
   editar e não descarte, reverta ou sobrescreva trabalho de outro agente.
8. Erros de integração, comandos externos e entradas inválidas devem ser
   explícitos: registre o erro ou notifique o usuário; não esconda falhas com
   defaults silenciosos ou `catch` abrangente.
9. Atualize a documentação diretamente relacionada quando o comportamento,
   comando de execução ou decisão arquitetural mudar.
10. Valide a mudança com o menor comando adequado. Para o core, execute
    `dart test`; para o CMS, use `flutter analyze` e/ou os testes relevantes;
    para o dashboard, valide a interface e o fluxo MQTT quando aplicável.
    Se uma ferramenta não estiver instalada, informe isso em vez de declarar
    que a validação passou.

## Pontos sensíveis

- O fluxo principal é UI -> repository -> disco -> stream -> MQTT -> tablet.
- O contrato publicado por `Layout.toPublishJson()` não deve incluir
  `bindings` nem comandos locais; `Layout.toDiskJson()` é a representação local que pode incluí-los.
- No Windows, preserve o uso de `hub_audio_helper.exe` (WASAPI nativo) para áudio e `nircmd.exe`
  para mídia e teclas conforme documentado no [CONTEXT.md](./CONTEXT.md); não reintroduza COM/FFI direto no processo Dart.
- Ao mexer em `layout.json`, use `LayoutRepository` ou o CMS. Não edite o
  arquivo manualmente ignorando o cache em memória.
- Considere Linux e Windows separadamente nas integrações de áudio, mídia,
  brilho, teclas e estatísticas.

## Antes de finalizar

- Revise o diff e confirme que somente arquivos relacionados foram alterados.
- Execute a validação disponível e reporte claramente comandos e resultados.
- Atualize o [CONTEXT.md](./CONTEXT.md) se o progresso, as limitações ou as
  decisões do projeto tiverem mudado.
