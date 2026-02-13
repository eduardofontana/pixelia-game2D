# Checkpoint Log - 2026-02-12

Este arquivo registra o estado atual do projeto antes das proximas alteracoes.

## Estado geral
- Projeto Godot 2D com menu inicial, cena principal, HUD customizado e sistema de combate.
- Player com animacoes, stamina, ataque, morte cinematografica e respawn.
- Inimigos ativos: Skeleton, Bat e Slime, com IA de patrulha/perseguicao/ataque.
- Sistema de moedas coletaveis e contador no HUD.

## Ajustes recentes confirmados
- Contagem de morte ajustada para 10 segundos.
- Overlay de morte com opcoes de acao.
- Fim da contagem NAO respawna automaticamente.
- Ao terminar a contagem:
  - Texto muda para `Relax ...`
  - Emoji muda para `🎣`
  - Fica somente o botao `Sair`
- Botao `Continuar` permanece disponivel apenas durante a contagem.
- Ajuste visual dos botoes (altura e contorno vertical) aplicado.

## Audio recente
- Som `Gore_Wet_7.wav` adicionado ao Slime ao receber dano do player.

## Observacao
- Este checkpoint foi criado por solicitacao do usuario para servir como base antes de novas mudancas.
