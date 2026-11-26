# ChargedFuss

**ChargedFuss** é um jogo 3D de defesa de torres desenvolvido em grupo para a disciplina de Computação Gráfica. Em **Iniciação**, a fase única do projeto, você monta suas defesas ao longo de uma pista suspensa em um cenário industrial e enfrenta dez rodadas de drones, com um chefe na última leva.

## Como jogar

1. Selecione **Fase 1 - Iniciação** no menu principal.
2. Arraste uma defesa da loja até uma das **oito bases** do mapa. A primeira construção inicia a partida.
3. Use a energia recebida por eliminar inimigos e concluir rodadas para construir novas torres ou melhorar as que você já instalou.
4. Clique em uma torre instalada para ver seu alcance e abrir o painel de melhorias.

| Defesa | Função |
| --- | --- |
| Torre Normal | Dispara projéteis de alto dano contra um alvo por vez. |
| Torre Rápida | Dispara com mais frequência, com menos dano por projétil. |
| Tesla | Emite pulsos que causam dano e desaceleram os inimigos próximos. |
| Lança-chamas | Acompanha o alvo com um jato de fogo em cone e pode atingir vários inimigos ao mesmo tempo. |

Cada inimigo que chega ao fim da pista reduz sua vida. Para vencer, derrote o chefe ou sobreviva à passagem dele.

## Executar pelo Godot

1. Clone ou baixe este repositório.
2. No **Godot 4.7**, importe o arquivo `project.godot` e aguarde a importação dos recursos.
3. Pressione **F5** para iniciar o jogo.

O projeto usa **GDScript**, modelos 3D feitos no **Blender** e importados em **glTF (`.glb`)**, além do renderizador **Compatibility** do Godot.

## Exportar uma versão jogável

Instale os modelos de exportação da mesma versão do Godot que estiver usando. Em **Projeto → Exportar…**, selecione **Windows Desktop** para gerar um `.exe` ou adicione o perfil **Linux** para gerar o executável dessa plataforma.

Use **Exportar todos os recursos do projeto** para incluir os modelos carregados em tempo de execução. Desmarque **Exportar com depuração** para gerar uma versão Release. Se a exportação gerar um arquivo `.pck` separado, mantenha-o junto ao executável.

## Código e documentação

| Arquivo | Responsabilidade |
| --- | --- |
| [`Game.tscn`](Game.tscn) e [`Cena.gd`](Cena.gd) | Menus, interface e controle da partida, da economia e das rodadas. |
| [`Torre.gd`](Torre.gd) | Ataques, seleção de alvos, alcance e melhorias das defesas. |
| [`Enemy.gd`](Enemy.gd) | Vida, deslocamento e efeitos aplicados aos inimigos. |
| [`fases/iniciacao/`](fases/iniciacao/) | Cenário, percurso, bases e regras da fase Iniciação. |

O [relatório técnico](RELATORIO_TECNICO.md) detalha a arquitetura, os valores da fase e o fluxo de execução, com exemplos e diagramas.

## Equipe

- Guilherme<br>
- Mikhael
