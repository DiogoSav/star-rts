# Star-RTS

**▶ Jogue no navegador: https://diogosav.github.io/star-rts/**
(PC com teclado e mouse; o primeiro clique dá foco ao jogo)

RTS espacial em 3D (Godot 4.7, Forward+) feito a partir das mecânicas do Mini RTS 3D.
Três raças disputam um planeta alienígena rico em cristais:

| | Legião Solar (humanos) | Núcleo Sintético (robôs) | Enxame Kheth (insetos) |
|---|---|---|---|
| Estilo | equilibrada | cara, lenta, resistente | barata, rápida, frágil |
| Fuzileiro | Fuzileiro Orbital | Sentinela | Zangão |
| Curto alcance | Tropa de Choque | Ceifador | Rasgador |
| Antiaérea (pulso) | Artilheiro de Pulso | Supressor | Cuspidor |
| Antiblindagem | Lança-Mísseis | Desintegrador | Perfurador |
| Atirador | Atirador de Elite | Observador | Espreitador |
| Coletor | Cargueiro Minerador | Extrator | Larva Coletora |
| Batedor (antiaéreo) | Batedor Lince | Aranha | Corredor |
| Tanque | Gládio (hover) | Bastião (disco) | Escaravelho |
| Pesado | Titã de Cerco | Colosso (mecha) | Behemoth |
| **Caça** (ar e solo) | Caça Falcão | Interceptor Delta | Vespa |
| **Nave pesada** (só solo) | Fragata Ônix | Arca Prisma | Leviatã |

## Como abrir

Importe o `project.godot` no Godot 4.7 e aperte F5. No menu: **JOGAR**, escolha o inimigo
(ou Aleatório) e clique em **COMANDAR** na sua raça.

Controles: arrastar = selecionar · botão direito = mover/atacar · Ctrl + direito = andar
atacando · WASD/bordas = câmera · roda = zoom · Esc/P = pausa · F11 = tela cheia.

**Fila de produção:** cada clique num soldado, veículo ou nave entra na fila daquela
categoria (até 5, pagos na hora); o botão mostra quantos faltam (×3). Botão direito no item
cancela o último da fila e devolve os créditos. Prédios continuam um por vez.

**Conserto:** selecione um prédio seu danificado e clique em **Consertar** no painel (ou
aperte **K**). Recupera 5% da vida por segundo e custa, por ponto de vida, metade do custo
do prédio dividida pela vida máxima. É pedido prédio a prédio, nunca automático (nem pela
IA), e para se os créditos acabarem — aí é preciso pedir de novo.

## Multiplayer 1×1 (versão Web)

No menu, **MULTIPLAYER**: digite seu nome; um jogador clica em **CRIAR SALA** e passa o
código de 5 letras; o outro digita o código e clica em **ENTRAR**. Não precisa de conta nem
de servidor de jogo: a partida roda no navegador de quem criou a sala.

**Sala de espera:** mostra os dois jogadores (nome, raça e se está pronto), um chat e a
escolha de raça (a raça do outro fica bloqueada). Quando **os dois apertam PRONTO** começa
uma contagem de 3 s (desmarcar cancela). Na partida, cada um espera o outro terminar de
carregar ("Aguardando … terminar de carregar") e o jogo começa ao mesmo tempo para os dois.
Se o convidado sai da sala, ela continua aberta com o mesmo código.

Como funciona (`scripts/net.gd`):
- **Conexão direta (WebRTC, P2P).** O "aperto de mão" inicial passa por um broker MQTT
  público (`broker.emqx.io`, em `scripts/mqtt_signal.gd`); depois que os dois se conectam
  o broker é fechado. Para atravessar roteadores usa STUN do Google. Em redes muito
  restritas (alguns 4G e redes corporativas) a conexão direta pode falhar.
- **Anfitrião manda.** Quem cria a sala (time 0) roda a simulação inteira; o convidado
  (time 1) envia as ordens (mover, atacar, produzir, construir, consertar) e recebe 15 vezes
  por segundo um retrato do jogo, com o movimento suavizado. Cada um tem a sua névoa.
- Se alguém sai, o outro vence. Durante a partida a pausa não congela o jogo.

Por enquanto o multiplayer só aparece na versão Web. No PC exigiria a extensão
[webrtc-native](https://github.com/godotengine/webrtc-native) em `addons/`; com ela, o
argumento `-- --mp-test` mostra o botão (usado para testes).

## Versão Web (navegador)

O projeto exporta para HTML5/WebAssembly (preset "Web" em `export_presets.cfg`). Na Web o
renderizador é o **Compatibility** (WebGL 2), configurado só para a Web em `project.godot`
(`rendering_method.web`); no PC continua o Forward+. Sem SSAO na Web; o resto é igual.

```
Godot_console --headless --path . --export-release "Web" web/index.html
node tools/serve_web.js 8060      (depois abra http://localhost:8060)
```

A exportação é sem threads, então funciona em qualquer hospedagem estática sem cabeçalhos
especiais. Abrir o `index.html` direto do disco não funciona: precisa de um servidor HTTP.
Na Web a câmera anda só pelo WASD/setas (sem rolagem pelas bordas).

**Publicação:** o site é a branch `gh-pages` deste repositório (GitHub Pages). Para
republicar depois de exportar de novo, copie o conteúdo de `web/` para uma cópia da branch
`gh-pages`, faça commit e `git push origin gh-pages`; o Pages atualiza em 1–2 minutos.

## Mecânicas novas em relação ao Mini RTS 3D

- **Naves**: produzidas no Hangar (requer Fábrica). Voam em linha reta por cima de rochas e
  prédios, decolam do hangar, inclinam nas curvas e, abatidas, caem girando.
- **Antiaéreo**: só armas com `"air": true` atingem naves — infantaria de pulso, batedores,
  caças e torres de defesa. Naves pesadas não atiram em outras naves.
- **Projéteis visíveis**: canhões, mísseis e armas antiblindagem disparam projéteis com
  rastro; o dano chega no impacto. Armas rápidas usam raios.
- **Cristais**: o recurso cresce em campos de cristais instanciados que encolhem ao serem
  extraídos e voltam a crescer devagar.
- Prédios são "impressos" por um feixe holográfico ao serem construídos.

## Modelos 3D (Blender)

Todos os modelos (`models/*.glb`) são gerados por scripts Python do **Blender 5.2** em
`art_src/blender/` (primitivas chanfradas e suavizadas + materiais PBR por papel):

```
blender -b --factory-startup --python art_src/blender/make_models.py -- models [filtro]
blender -b --factory-startup --python art_src/blender/preview.py -- models folha.png [filtro]
```

`human.py`, `robot.py`, `insect.py` e `props.py` têm cada modelo; `palettes.py` tem as cores.
Rodar o gerador sobrescreve os `.glb` (e edições feitas à mão). Depois de gerar, abra o
projeto no editor (ou rode `godot --headless --import`) para reimportar.

Convenções: X = frente, Z = cima no Blender; 1 unidade = 1 célula. Grupos móveis são
Empties chamados `turret`, `gun`, `torso`, `leg_*`, `wing_*` e `spin`; localizadores são
`loc_muzzle_*`, `loc_engine_*`, `loc_smoke_*`. O nome do material define o papel no shader
do jogo (`scripts/models.gd`): `hull/dark/metal` ganham linhas de painel, `chitin/flesh/bone`
textura orgânica, `team` a cor do time, `glow/engine/glass/crystal` brilham.

## Balanceamento

`UNITS`, `BUILDINGS` e `ARMOR_MULT` em `scripts/game_state.gd`; IA em `scripts/ai.gd`.
