# Tower Defense Game

Projeto desenvolvido em grupo para a disciplina de Computação Gráfica.

O projeto consiste no desenvolvimento de um jogo do gênero Tower Defense, utilizando conceitos de computação gráfica.

## Padrão de tamanho dos mapas

Todos os mapas usam a métrica de **tamanho efetivo do mapa**, definida em `MetricaMapa.gd`. Em uma tela 16:9, a área de jogo mede aproximadamente **40,9 × 29,5 unidades** (cerca de **1.207 unidades²**), reservando 22% da largura à esquerda para os controles. Em outras proporções de tela, a largura útil se ajusta ao aspecto do viewport e a altura permanece em 29,5 unidades.

Os modelos temporários de torres e inimigos usam escala 2×; a faixa do caminho tem 1,785 unidade de largura. Mapas futuros devem respeitar os mesmos limites efetivos e esses tamanhos de referência.

## Equipe
- Guilherme<br>
- Mikhael
