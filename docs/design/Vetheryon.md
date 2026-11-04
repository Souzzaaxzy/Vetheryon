# VETHERYON
## Documento Mestre de Planejamento

**Versão:** 0.1 — Planejamento conceitual
**Data:** 4 de novembro de 2026
**Status:** Em planejamento. As escolhas confirmadas pelo usuário estão registradas como decisões. Sugestões ainda não aprovadas estão identificadas como propostas ou pendências.

---

# 1. Visão geral

**Vetheryon** é um jogo 3D sandbox de fantasia medieval, inicialmente planejado para Android. A proposta é criar um mundo aberto vasto, explorável e persistente, no qual o jogador possa construir sua própria trajetória: aventureiro, guerreiro, mago, explorador, comerciante, artesão, proprietário de negócios ou uma combinação dessas possibilidades.

O jogo combina:
- Exploração de um mundo de fantasia medieval.
- Combate físico e mágico.
- Progressão de personagem e domínio de escolas mágicas.
- Criaturas, domesticação, treinamento e reprodução.
- Equipamentos profundos e fabricação personalizada.
- Economia dinâmica, profissões e negócios.
- Relacionamentos, reputação e consequências sociais.
- Missões ramificadas e acontecimentos espontâneos.
- Ecossistemas e recursos naturais reativos.
- Continentes, ilhas, oceanos, civilizações submarinas e mundo subterrâneo.

A ambição é oferecer liberdade e profundidade sistêmica sem exigir que todos os sistemas sejam simulados em detalhe ao mesmo tempo. O desenvolvimento deverá ser modular, incremental e guiado por testes de desempenho no dispositivo-alvo.

# 2. Plataforma, tecnologia e escopo técnico

## 2.1 Plataforma inicial
- Plataforma inicial: Android.
- Dispositivo de referência para desempenho: Samsung Galaxy A14, 4 GB de RAM.
- O projeto deverá priorizar estabilidade, carregamento eficiente e qualidade visual ajustável.

## 2.2 Engine e tecnologias propostas
A proposta técnica discutida é:
- Godot 4.7.2.
- GDScript.
- Renderizador Mobile.
- Orientação paisagem.
- Exportação para APK.

**Atenção:** essa configuração foi recomendada como base, mas ainda precisa ser confirmada formalmente para Vetheryon antes de ser tratada como decisão técnica definitiva.

## 2.3 Multiplayer futuro
- O lançamento inicial será single-player.
- A arquitetura deverá evitar acoplamentos desnecessários que dificultem uma possível expansão multiplayer.
- Multiplayer futuro não está prometido nem deve ser considerado simples: exigirá planejamento, testes e infraestrutura próprios.

## 2.4 Princípios de desempenho
- Simulação detalhada nas proximidades do jogador.
- Simulação simplificada ou por eventos para regiões distantes.
- LOD para objetos, criaturas e vegetação.
- Streaming e carregamento por regiões.
- Pooling de objetos e entidades.
- MultiMesh quando apropriado.
- Texturas comprimidas e limites de memória.
- Controle adaptativo de partículas, NPCs, invocações e efeitos mágicos.
- Distâncias de visão e qualidade gráfica configuráveis.
- Sistemas preparados para reduzir atividade quando uma região não estiver ativa.

# 3. Identidade e direção visual

## 3.1 Conceito visual
- Estilo: **realismo estilizado**.
- Atmosfera: fantasia medieval equilibrada, com elementos sombrios e épicos.
- O mundo deverá alternar entre regiões acolhedoras, misteriosas, perigosas e grandiosas.
- A identidade visual oficial, logo, símbolo, tela inicial e menu ainda não foram definidos.

## 3.2 Direção de arte
A direção visual deverá manter coerência entre:
- Personagens e espécies.
- Arquitetura dos povos e reinos.
- Biomas e ecossistemas.
- Criaturas e chefes.
- Armas, armaduras e relíquias.
- Efeitos mágicos e fenômenos ambientais.
- Interface e elementos de navegação.

# 4. Mundo e geografia

## 4.1 Estrutura do mundo
- Um continente principal.
- Várias ilhas, arquipélagos e territórios secretos.
- Oceanos extensos e regiões marítimas.
- Um segundo mundo subterrâneo gigantesco.
- Civilizações e reinos escondidos na superfície, no subterrâneo e sob os oceanos.

## 4.2 Exploração livre
O jogador poderá:
- Caminhar.
- Utilizar montarias terrestres.
- Navegar por mares e oceanos.
- Voar por magia ou montarias voadoras.
- Utilizar teletransporte mágico.

## 4.3 Mundo subterrâneo
O subterrâneo será um mundo próprio, com:
- Ecossistemas independentes.
- Reinos esquecidos.
- Florestas subterrâneas bioluminescentes.
- Mares e lagoas profundos.
- Abismos.
- Cidades ocultas.
- Ruínas primordiais.
- Criaturas e ameaças específicas.

Acesso possível por cavernas, ruínas, passagens secretas, portais e abismos. A superfície e o subterrâneo poderão influenciar um ao outro.

## 4.4 Oceanos e mundo subaquático
Estão previstos:
- Civilizações oceânicas completas.
- Reinos submarinos e regiões abissais.
- Povos com culturas, idiomas e governos próprios.
- Cidades submersas, ruínas, criaturas inteligentes, monstros abissais, tesouros e artefatos.
- Mergulho, pressão, correntes e combate subaquático.
- Espécies aquáticas que respiram naturalmente.
- Para outras espécies, recursos de respiração aquática por poções, encantamentos, artefatos, equipamentos ou transformação mágica.
- Perigos e pressão crescentes nas profundezas.

# 5. Personagem do jogador

## 5.1 Personalização
O personagem será totalmente personalizável:
- Rosto.
- Cabelo.
- Corpo.
- Tons de pele.
- Roupas.
- Armaduras.
- Acessórios.
- Equipamentos visíveis.

## 5.2 Câmera
- Alternância entre primeira e terceira pessoa.

## 5.3 Progressão
Progressão híbrida:
- Nível geral do personagem.
- Atributos como força, vitalidade, agilidade e inteligência.
- Equipamentos.
- Habilidades.
- Domínio mágico independente por escola.

O jogador não será obrigado a escolher uma classe fixa e poderá desenvolver diferentes estilos.

## 5.4 Envelhecimento
**Decisão confirmada: apenas o jogador envelhece.**
- O personagem terá idade e passagem de tempo.
- NPCs não envelhecem automaticamente.
- Famílias, casamentos e personagens importantes mantêm suas idades e identidades.
- Mudanças físicas do jogador conforme a idade poderão ser exploradas.
- Magia, poções, bênçãos ou características raciais poderão justificar longevidade extraordinária, caso esse detalhe seja desenvolvido.

# 6. Espécies, raças e povos

## 6.1 Variedade
O jogo terá grande variedade de raças, meio-sangues e espécies mágicas jogáveis.

Exemplos levantados durante o planejamento, ainda não canonizados individualmente:
- Humanos.
- Elfos.
- Anões.
- Orcs.
- Meio-elfos.
- Meio-orcs.
- Draconatos e descendentes de dragões.
- Vampiros.
- Licantropos.
- Demônios.
- Fadas.
- Elementais.
- Seres arcanos e ancestrais.

A lista definitiva de espécies ainda será elaborada.

## 6.2 Profundidade cultural e social
Cada povo poderá ter:
- Habilidades raciais.
- Cultura, costumes e tradições.
- Crenças, história e origem.
- Política, reinos, alianças e conflitos.
- Afinidades mágicas.
- Relações, rivalidades e preconceitos.
- Territórios, cidades e missões específicas.

Não deverá existir uma espécie obrigatoriamente superior às demais. Diferenças devem criar estilos e possibilidades, não uma escolha universalmente correta.

# 7. Combate e progressão de poder

## 7.1 Combate híbrido
O combate combinará:
- Armas.
- Magia.
- Habilidades.
- Esquivas.
- Bloqueios.
- Invocações.
- Combinações entre técnicas físicas e mágicas.

## 7.2 Classes
- Não haverá classes obrigatórias.
- O jogador poderá aprender todas as escolas mágicas.
- A progressão será baseada em atributos, prática, habilidades, equipamentos e domínio independente.

## 7.3 Morte e penalidades
**Decisão confirmada: penalidade intermediária.**
- Retorno ao último ponto de descanso ou local de ressurgimento.
- Perda de parte dos recursos comuns carregados.
- Armas, armaduras e itens importantes protegidos.
- Missões e descobertas preservadas.

A porcentagem exata de recursos perdidos ainda não foi decidida. A faixa de 10% a 20% foi apenas sugerida e não está aprovada.

# 8. Arcane System V1.0

O sistema de magia foi planejado em um documento de design próprio, com oito escolas, progressão independente, combinações, personalização de feitiços e arquitetura modular.

## 8.1 Oito escolas mágicas

### Ignis — Fogo
- Fireball.
- Flame Burst.
- Inferno.
- Firestorm.
- Meteor.
- Dragon Flame.
- Magma Control.
- Phoenix Rebirth.

### Glacies — Gelo
- Ice Shard.
- Ice Prison.
- Frost Armor.
- Blizzard.
- Frozen Ground.
- Ice Storm.
- Absolute Zero.

### Fulmen — Raio
- Lightning Bolt.
- Chain Lightning.
- Thunder Dash.
- Thunderstorm.
- Lightning Cage.
- Electric Aura.

### Umbra — Trevas
- Shadow Step.
- Soul Drain.
- Dark Orb.
- Shadow Clone.
- Void Rift.
- Curse.
- Darkness Domain.

### Natura — Natureza
- Root Grasp.
- Nature's Blessing.
- Thorn Explosion.
- Poison Cloud.
- Forest Guardian.
- Nature Domain.

### Ventus — Vento
- Wind Burst.
- Wind Blade.
- Tornado.
- Flight.
- Air Shield.
- Cyclone.
- Sky Domain.

### Lux — Luz
- Healing Wave.
- Divine Shield.
- Holy Spear.
- Purification.
- Divine Light.
- Resurrection.

### Sanguis — Sangue
- Blood Spear.
- Life Steal.
- Blood Shield.
- Blood Chains.
- Crimson Explosion.
- Blood Domain.

## 8.2 Progressão por escola
Cada escola terá domínio independente:
1. Iniciante.
2. Aprendiz.
3. Adepto.
4. Mestre.
5. Lendário.

Lendário não precisa ser o limite absoluto: evoluções excepcionais poderão existir.

Exemplo: personagem Lendário em Ignis, Aprendiz em Glacies e Iniciante em Sanguis.

## 8.3 Combinações mágicas
Combinações propostas:
- Fogo + Vento: tornado flamejante.
- Gelo + Raio: tempestade congelante.
- Natureza + Sangue: raízes vampíricas.
- Luz + Fogo: chamas sagradas.
- Trevas + Raio: relâmpago sombrio.
- Gelo + Vento: nevasca.
- Natureza + Luz: campo regenerativo.
- Sangue + Trevas: maldição vampírica.

## 8.4 Forja Arcana
Personalização de feitiços por:
- Elemento.
- Forma.
- Intensidade.
- Alcance.
- Velocidade.
- Duração.
- Área.
- Comportamento.
- Efeitos secundários.
- Modificadores.

## 8.5 Recursos e riscos mágicos
- Mana.
- Vitalidade.
- Energia física.
- Sobrecarga arcana.

A sobrecarga poderá causar instabilidade, dano, interrupção de conjuração e efeitos inesperados.

A fantasia de poder praticamente ilimitado não significa execução técnica sem limites: custos, limites de desempenho e controles serão necessários.

## 8.6 Outros recursos mágicos
- Voo mágico.
- Montarias voadoras.
- Invocação de criaturas e entidades.
- Interação mágica com o ambiente.
- Efeitos ambientais.

## 8.7 Interface mágica planejada
- Vida, mana, energia e sobrecarga.
- Quatro slots de habilidade.
- Menu radial.
- Biblioteca de feitiços.
- Árvore de evolução.
- Forja Arcana.
- Registro de descobertas.

## 8.8 Arquitetura técnica proposta
Estrutura modular sugerida:
- `systems/magic/core/`
  - `magic_manager.gd`
  - `mana_system.gd`
  - `overload_system.gd`
  - `spell_executor.gd`
- `schools/`
- `spells/`
- `combinations/`
- `progression/`
- `crafting/`
- `discovery/`
- `summons/`
- `flight/`
- `environment/`

Feitiços deverão ser orientados a dados, usando um recurso personalizado como `SpellData`, em vez de scripts exclusivos para cada feitiço. O `MagicManager` deverá poder atender jogador, NPCs, chefes e criaturas.

## 8.9 Metas conceituais iniciais
Metas levantadas, ainda não implementadas:
- 8 escolas.
- 40 feitiços básicos.
- 24 feitiços especiais.
- 20 fusões.
- 5 estágios de domínio.
- 20 modificadores.
- 10 efeitos ambientais.

# 9. Criaturas, fauna e ecossistemas

## 9.1 Ecossistema avançado
**Decisão confirmada: cadeias alimentares, migrações, reprodução e comportamento territorial.**

O mundo terá:
- Predadores caçando presas.
- Herbívoros procurando vegetação.
- Competição por alimento.
- Migração sazonal.
- Busca por abrigo durante tempestades.
- Espécies raras em períodos específicos.
- Reprodução, filhotes, crescimento e períodos reprodutivos.
- Predadores defendendo territórios e grupos.
- Fuga, defesa e ataques quando ameaçados.
- Ecossistemas em florestas, desertos, montanhas, oceanos, subterrâneo e regiões mágicas.

A simulação será escalonada: comportamento detalhado perto do jogador e simulação simplificada fora da região ativa.

## 9.2 Interação completa com criaturas
**Decisão confirmada: interação completa.**
- Caçar e alimentar.
- Domesticar.
- Criar e reproduzir.
- Treinar criaturas.
- Desenvolver vínculos.
- Desbloquear e utilizar habilidades especiais.
- Criar linhagens.

Criaturas poderão atuar como companheiras, montarias, auxiliares ou parceiras de combate.

Nem toda criatura precisa ser domesticável. Algumas serão ameaças selvagens e manterão sua natureza perigosa.

# 10. Chefes e ameaças mundiais

Chefes épicos poderão:
- Alterar o mundo.
- Atacar cidades.
- Dominar territórios.
- Causar eventos e consequências persistentes.

Categorias sugeridas:
- Dragões ancestrais.
- Titãs.
- Entidades arcanas.
- Senhores demoníacos.
- Monstros abissais.
- Criaturas lendárias.

## 10.1 Consequências mistas
- Chefes únicos poderão morrer permanentemente, libertar territórios e deixar marcas históricas.
- Ameaças recorrentes poderão reaparecer ou ser substituídas, atacando regiões e mantendo o mundo dinâmico.

Exemplo: após a morte permanente de um dragão, seu território poderá ser disputado por facções, reinos e outras criaturas.

# 11. Equipamentos, fabricação e durabilidade

## 11.1 Sistema extremo de equipamentos
**Decisão confirmada.**
- Fabricação personalizada.
- Equipamentos evolutivos.
- Relíquias únicas.
- Conjuntos lendários.
- Equipamentos com história própria.

## 11.2 Fabricação personalizada
- Escolha de materiais, componentes e propriedades.
- Armas e armaduras com características próprias.
- Receitas descobertas em ruínas, livros e com mestres artesãos.
- Qualidade influenciada pela habilidade do artesão.

## 11.3 Equipamentos evolutivos
- Armas que evoluem conforme sua utilização.
- Equipamentos que desbloqueiam habilidades.
- Transformações por eventos e condições especiais.
- Evolução ligada à história do item.

## 11.4 Relíquias e conjuntos
- Artefatos de civilizações antigas.
- Armas de deuses e entidades ancestrais.
- Itens escondidos em regiões secretas.
- Bônus por peças equipadas.
- Habilidades espe<response clipped><NOTE>Due to the max output limit, only part of the full response has been shown to you.</NOTE>erá ser escalonada por proximidade e relevância, evitando manter todos os personagens ativos em detalhe simultaneamente.

# 16. Facções e organizações

Sistema profundo confirmado:
- Hierarquias.
- Reputação.
- Rivalidades.
- Guerras.
- Missões exclusivas.
- Benefícios.
- Ascensão de membros.
- Possibilidade de se tornar líder.

Organizações sugeridas:
- Guilda dos Aventureiros.
- Círculo Arcano.
- Ordem dos Cavaleiros.
- Guilda Mercantil.
- Irmandade das Sombras.
- Exploradores Reais.
- Ordem Sagrada.

Possibilidade de abandonar organizações, mudar de lado ou fundar uma própria foi sugerida, mas ainda não confirmada como requisito.

# 17. Reputação, fama e história

## 17.1 Sistema completo
**Decisão confirmada.**
- Fama mundial.
- Títulos.
- Lendas.
- Infâmia.
- Reconhecimento por feitos.
- Consequências permanentes das ações.

## 17.2 Reputação regional
- Reputação independente por cidade, reino e território.
- Reconhecimento por facções e organizações.
- Reações diferentes dos NPCs.
- Possibilidade de ser amado em uma região e odiado em outra.

## 17.3 Fama mundial
- Grandes feitos poderão atravessar fronteiras.
- Histórias serão espalhadas por viajantes, comerciantes e bardos.
- Acontecimentos poderão entrar nos registros históricos.
- A fama poderá crescer mesmo quando o jogador não estiver presente.

## 17.4 Títulos e lendas
Exemplos ilustrativos:
- Matador de Dragões.
- Salvador dos Reinos.
- Arquimago Ancestral.
- Rei das Sombras.
- Herói dos Sete Mares.
- Destruidor de Impérios.

## 17.5 Infâmia
- Recompensas por captura.
- Caçadores de recompensas.
- Hostilidade de organizações.
- Medo ou admiração dos habitantes.
- Mudanças políticas provocadas pelos feitos do jogador.

# 18. Missões e narrativas

## 18.1 Sistema de mundo vivo
**Decisão confirmada.**
- Escolhas e ramificações.
- Múltiplos finais.
- Missões geradas por acontecimentos mundiais.
- Histórias procedurais.
- Conflitos dinâmicos.
- Aventuras espontâneas.

## 18.2 Narrativas ramificadas
- Escolhas que alteram histórias.
- Personagens que podem sobreviver ou morrer conforme as decisões.
- Consequências que poderão aparecer muito tempo depois.

## 18.3 Missões dinâmicas
Possibilidades:
- Ataques a cidades.
- Guerras entre reinos.
- Caravanas desaparecidas.
- Criaturas invadindo territórios.
- Disputas entre organizações.
- Descobertas de ruínas e passagens secretas.

## 18.4 Histórias procedurais e espontâneas
- Missões criadas a partir de acontecimentos do mundo.
- Personagens com problemas e objetivos próprios.
- Recompensas e dificuldades variáveis.
- Aventuras que não precisam se repetir da mesma maneira.
- Encontros que podem ser ignorados, investigados ou transformados em histórias maiores.

## 18.5 Consequências persistentes
As missões poderão modificar:
- Cidades e territórios.
- Relações entre facções.
- Comércio e economia.
- Reputação do jogador.
- Destino de personagens.
- História regional.

# 19. Exploração, arqueologia e descobertas

## 19.1 Exploração extrema
**Decisão confirmada.**
- Arqueologia.
- Cartografia.
- Descobertas científicas.
- Locais secretos.
- Tesouros únicos.
- Civilizações perdidas.
- Mistérios que exigem investigação.

## 19.2 Arqueologia
- Escavações e exploração de ruínas.
- Artefatos de civilizações antigas.
- Inscrições, idiomas e símbolos esquecidos.
- Reconstrução de acontecimentos históricos.

## 19.3 Cartografia
- Mapas criados pelo jogador.
- Regiões desconhecidas e mapas incompletos.
- Registro de cavernas, rotas marítimas e passagens secretas.
- Cartografia terrestre, subterrânea e oceânica.
- Possibilidade de vender mapas e descobertas.

## 19.4 Descobertas científicas
- Estudo de criaturas e ecossistemas.
- Pesquisa de materiais desconhecidos.
- Investigação de fenômenos mágicos.
- Catalogação de espécies e recursos.
- Conhecimentos e receitas desbloqueados por pesquisa.

## 19.5 Mistérios
Alguns segredos poderão exigir:
- Reunir pistas.
- Interpretar inscrições.
- Comparar documentos.
- Reconstruir acontecimentos.
- Investigar locais e personagens.

# 20. Clima, estações e atmosfera

## 20.1 Clima avançado
**Decisão confirmada.**
- Ciclo dia/noite.
- Quatro estações: primavera, verão, outono e inverno.
- Chuva, neve, neblina, tempestades e vento.
- Mudanças na vegetação, criaturas e regiões.
- Eclipses arcanos.
- Auroras místicas.
- Tempestades de mana.
- Chuva de estrelas.

Os fenômenos mágicos serão raros e controlados para preservar o desempenho Android.

## 20.2 Atmosfera regional
A sensação de cada região poderá mudar conforme:
- Hora do dia.
- Clima.
- Estação.
- Acontecimentos mundiais.
- Presença de ameaças ou fenômenos mágicos.

# 21. Sobrevivência

**Decisão confirmada: sobrevivência leve.**
- Fome.
- Sede.
- Descanso.
- Penalidades moderadas.
- Sem morte automática por necessidades.
- Alimentação, bebidas, poções e refeições.
- Hospedarias e acampamentos.

Efeitos planejados:
- Fome poderá afetar regeneração de energia.
- Sede poderá afetar resistência e recuperação.
- Descanso recuperará energia e poderá oferecer benefícios temporários.

# 22. Recursos naturais e coleta

## 22.1 Ecossistema completo
**Decisão confirmada.**
Os recursos serão influenciados por:
- Clima.
- Estações.
- Ecossistemas.
- Exploração excessiva.
- Eventos mágicos.
- Condições ambientais.

## 22.2 Tipos de recursos
- Minérios, pedras preciosas, madeira e minerais.
- Plantas medicinais, ingredientes alquímicos e cogumelos.
- Materiais mágicos e componentes raros.
- Recursos terrestres, subterrâneos e oceânicos.

## 22.3 Dinâmica ambiental
- Plantas que florescem em estações específicas.
- Minérios revelados por fenômenos naturais.
- Tempestades que podem expor depósitos.
- Temperaturas extremas que afetam disponibilidade.
- Recursos ligados a habitats e espécies.
- Materiais provenientes de criaturas.
- Plantas dependentes de polinizadores.
- Recursos raros durante eclipses, tempestades de mana e outros fenômenos.

## 22.4 Exploração excessiva
- Recursos podem se esgotar localmente.
- Ecossistemas podem sofrer desequilíbrios.
- Regiões poderão precisar de tempo para se recuperar.
- Exploração sustentável poderá preservar produtividade.

# 23. Agricultura e criação

**Status: decisão pendente.** A última pergunta feita foi escolher a profundidade deste sistema:
- Básica: plantar, colher e criar animais.
- Avançada: estações, fertilidade do solo, reprodução, alimentação e produção de recursos.
- Completa: fazendas próprias, funcionários, genética animal, cruzamentos, espécies mágicas, plantações raras, irrigação e comércio agrícola.

Nenhuma opção foi confirmada até a data deste documento.

# 24. Decisões ainda pendentes

Além de agricultura e criação, ainda precisam ser detalhados ou decididos:

## 24.1 Mundo e sociedade
- Reinos, fronteiras e mapa político definitivo.
- Governos, sucessões e diplomacia.
- Religiões, divindades, cultos e crenças.
- Idiomas e sistemas de escrita.
- Arquitetura e identidade cultural dos povos.
- Sistema de leis, crimes, prisões e julgamentos.
- Festivais, feriados e atividades cotidianas.

## 24.2 Combate
- Catálogo definitivo de armas.
- Estilos e técnicas de combate físico.
- Tipos e comportamento de inimigos.
- Dificuldade e escalonamento.
- Chefes e encontros.
- Bloqueio, esquiva, parry e progressão de técnicas.
- Regras detalhadas de PvE e eventual multiplayer futuro.

## 24.3 Sistemas de vida
- Agricultura e criação.
- Culinária detalhada.
- Pesca e caça em profundidade.
- Doenças, ferimentos e recuperação.
- Sono e acampamento.
- Atividades recreativas e passatempos.

## 24.4 Sistemas de fabricação
- Alquimia em profundidade.
- Encantamento de equipamentos.
- Joalheria e runas.
- Forja e receitas.
- Coleta e processamento de materiais.
- Construção de barcos e equipamentos de montaria.

## 24.5 Experiência do jogador
- Interface completa.
- Controles touchscreen.
- Configuração de câmera.
- Acessibilidade.
- Salvamento e slots.
- Configurações gráficas e de desempenho.
- Tutoriais e curva de aprendizado.

## 24.6 Identidade audiovisual
- Logo e símbolo.
- Tela inicial e menus.
- Trilha sonora.
- Ambientes sonoros.
- Vozes e idiomas.
- Direção de animação.
- Efeitos visuais.

## 24.7 Escopo técnico
- Confirmação definitiva da engine e versão.
- Estrutura de pastas e arquitetura global.
- Formato de dados e salvamento.
- Sistema de streaming do mundo.
- Estratégia de geração e armazenamento do mapa.
- Testes de desempenho e limites por dispositivo.
- Plano de atualizações e eventual multiplayer.

# 25. Diretrizes de design já estabelecidas

1. **Liberdade de escolha:** não obrigar o jogador a seguir uma única classe ou carreira.
2. **Mundo reativo:** ações e acontecimentos devem produzir consequências coerentes.
3. **Profundidade com propósito:** sistemas complexos devem gerar decisões interessantes, não tarefas repetitivas sem valor.
4. **Simulação escalonada:** detalhe perto do jogador, abstração longe dele.
5. **Modularidade:** cada sistema deve poder evoluir sem exigir reescrever o jogo inteiro.
6. **Desempenho Android:** qualidade ajustável e limites explícitos de processamento e memória.
7. **Conteúdo descoberto:** segredos importantes não precisam ser marcados no mapa.
8. **Persistência seletiva:** acontecimentos relevantes devem ser registrados; detalhes sem importância podem ser simplificados.
9. **Coerência interna:** decisões novas devem respeitar as escolhas já confirmadas.
10. **Desenvolvimento incremental:** implementar, testar, registrar e só então expandir.

# 26. Plano de desenvolvimento recomendado

Não começar tentando implementar todos os sistemas ao mesmo tempo.

## Fase 0 — Pré-produção
- Consolidar o documento mestre.
- Confirmar engine e configurações técnicas.
- Definir arquitetura e padrões de código.
- Criar repositório e estrutura inicial.
- Estabelecer critérios de desempenho.

## Fase 1 — Fatia vertical jogável
Criar uma pequena experiência funcional:
- Cena de mundo inicial.
- Terreno, vegetação, montanhas, rios e iluminação.
- Personagem controlável.
- Câmera alternável.
- Animações básicas.
- Controles touchscreen.
- APK testado no Galaxy A14.

## Fase 2 — Fundamentos de jogo
- Movimento e física.
- Interação com objetos.
- Inventário inicial.
- Coleta básica.
- Combate básico.
- Salvamento e carregamento.

## Fase 3 — Sistemas centrais
- Progressão do personagem.
- Equipamentos e durabilidade.
- Arcane System em etapas.
- Criaturas e fauna.
- NPCs e diálogos.

## Fase 4 — Mundo vivo
- Clima e estações.
- Ecossistemas.
- Economia.
- Facções.
- Missões dinâmicas.
- Reputação e consequências.

## Fase 5 — Vida e simulação social
- Profissões.
- Imóveis e negócios.
- Relacionamentos.
- Famílias e heranças, respeitando a regra de envelhecimento.
- Agricultura e criação, depois de decididas.

## Fase 6 — Expansão do mundo
- Continente e ilhas.
- Subterrâneo.
- Civilizações oceânicas.
- Regiões secretas.
- Arqueologia e mistérios.
- Chefes e eventos mundiais.

## Fase 7 — Polimento e lançamento
- Interface final.
- Áudio e efeitos.
- Otimização.
- Testes em aparelhos.
- Correções.
- APK de lançamento.

# 27. Método de trabalho

O desenvolvimento deverá seguir um fluxo incremental por missões:
- Cada missão terá objetivo claro.
- Escopo e arquivos envolvidos serão definidos.
- Critérios de aceitação serão explícitos.
- Implementação deverá ser testada.
- Mudanças serão registradas em commits.
- Cada entrega terá relatório.
- APKs serão gerados em marcos apropriados e testados no aparelho.

O workflow com GitHub e OpenHands poderá ser utilizado, seguindo a experiência de desenvolvimento já adotada em outros projetos, mas Vetheryon deverá ter repositório e histórico próprios.

# 28. Registro de decisões confirmadas

| Área | Decisão |
|---|---|
| Nome | Vetheryon |
| Gênero | Sandbox medieval de fantasia 3D |
| Plataforma inicial | Android |
| Estilo visual | Realismo estilizado |
| Atmosfera | Fantasia medieval equilibrada, sombria e épica |
| Mundo | Um continente principal, ilhas, arquipélagos e territórios secretos |
| Modo inicial | Single-player, preparado para possível expansão multiplayer |
| Personagem | Totalmente personalizável |
| Câmera | Primeira e terceira pessoa |
| Exploração e transporte | Caminhada, montarias terrestres, navegação, voo e teletransporte |
| Construção | Sem construção livre de imóveis; compra/aluguel e personalização de interiores |
| Negócios | Administração patrimonial e comercial |
| Sobrevivência | Leve |
| Combate | Híbrido |
| Classes | Sem classes obrigatórias; acesso a todas as escolas mágicas |
| Progressão | Híbrida, com domínio mágico independente |
| Morte | Penalidade intermediária; percentual de perda pendente |
| NPCs | Rotinas tradicionais e simples, com simulação escalonada |
| Missões | Mundo aberto com história, missões secundárias e eventos |
| Clima | Avançado, quatro estações e fenômenos mágicos raros |
| Espécies | Grande variedade e culturas profundas; lista definitiva pendente |
| Facções | Sistema profundo |
| Chefes | Épicos e dinâmicos, com consequências mistas |
| Subterrâneo | Segundo mundo gigantesco |
| Oceanos | Civilizações submarinas completas |
| Fauna | Ecossistemas avançados |
| Criaturas | Domesticação, treinamento, vínculos, habilidades e linhagens |
| Equipamentos | Sistema extremo, fabricação personalizada, evolutivos, relíquias, conjuntos e história própria |
| Durabilidade | Avançada, com desgaste, reparos e manutenção |
| Inventário | Extremo, com armazenamento mágico, bolsas dimensionais e carga de montarias |
| Economia | Dinâmica, com oferta/demanda, inflação regional, escassez, rotas, impostos e preços variáveis |
| Profissões | Completas, com mestres, aprendizado, reputação, oficinas e carreira independente |
| Relacionamentos | Completos, com personalidades, famílias, filhos, heranças e consequências |
| Envelhecimento | Apenas o jogador envelhece |
| Reputação | Completa, regional e mundial, com títulos, lendas e infâmia |
| Missões | Mundo vivo, ramificações, finais, histórias procedurais e eventos espontâneos |
| Exploração | Extrema, com arqueologia, cartografia, ciência, civilizações perdidas e mistérios |
| Recursos naturais | Ecossistema completo, influenciado por clima, estações e exploração |
| Agricultura e criação | Pendente de escolha |

---

**Fim do documento.**

Este arquivo registra o planejamento conhecido até 4 de novembro de 2026. Ele é um documento de design conceitual, não uma afirmação de que os sistemas já foram implementados. Decisões pendentes deverão ser atualizadas quando forem aprovadas.
