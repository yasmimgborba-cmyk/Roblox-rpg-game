# Caçadores de Monstros (Roblox)

Simulador RPG: clique nos monstros, ganhe moedas, compre armas melhores e renasça para ganhar bônus permanente. Feito para gerar Robux sozinho enquanto as pessoas jogam.

## Como o jogo gera dinheiro

| Fonte | O que é | Arquivo |
|---|---|---|
| **Gamepasses** | 2x Moedas, 2x Dano, Ataque Automático (compra única) | `src/shared/Config.lua` → `GamePasses` |
| **Pacotes de moedas** | Compras repetíveis. Rendem mais conforme o jogador renasce | `Config.DevProducts` |
| **Premium Payouts** | O Roblox te paga pelo tempo que jogadores Premium passam no jogo. É automático, não precisa de código | — |

Jogadores Premium ganham +10% de moedas. Isso faz eles jogarem mais tempo, e aí o Premium Payouts rende mais.

## Estrutura

```
src/shared/Config.lua                     → preços, armas, monstros, IDs de Robux
src/server/Main.server.lua                → inicia tudo
src/server/Services/DataService.lua       → salva o progresso
src/server/Services/MonetizationService.lua → gamepasses e compras
src/server/Services/CombatService.lua     → monstros e combate
src/server/Services/MapBuilder.lua        → chão, spawn e placas das zonas
src/client/UI.client.lua                  → interface do jogador
```

## Passo a passo

### 1. Colocar o código no Roblox Studio

**Opção A: Rojo (recomendado)**
1. Instale o plugin do Rojo no Studio e o Rojo no PC.
2. Nesta pasta, rode `rojo serve`.
3. No Studio, clique em *Connect* no plugin do Rojo.

**Opção B: manual (copiar e colar)**
1. `ReplicatedStorage` → crie uma pasta `Shared` → ModuleScript `Config` (cole `Config.lua`).
2. `ServerScriptService` → pasta `Server` → Script `Main` (cole `Main.server.lua`) → dentro de `Server` uma pasta `Services` com 4 ModuleScripts (`DataService`, `MonetizationService`, `CombatService`, `MapBuilder`).
3. `StarterPlayer > StarterPlayerScripts` → LocalScript `UI` (cole `UI.client.lua`).

### 2. Publicar e liberar o salvamento
1. *File > Publish to Roblox*.
2. *Game Settings > Security* → ative **Enable Studio Access to API Services** (senão o salvamento não funciona no Studio).

### 3. Criar os itens pagos
1. Acesse [create.roblox.com](https://create.roblox.com) → seu jogo → **Monetization**.
2. Em **Passes**, crie os 3 gamepasses e coloque à venda.
3. Em **Developer Products**, crie os 3 pacotes de moedas.
4. Copie cada ID e cole no `Config.lua` (onde está `Id = 0`). Preços sugeridos já estão lá.

### 4. Deixar o jogo público
*Game Settings > Permissions* → **Public**. Coloque ícone, miniaturas e uma descrição chamativa.

## Para ter renda de verdade

- O dinheiro só vem se tiver jogador. Os primeiros dias importam muito.
- Faça um **ícone e miniatura bonitos**. É o que mais influencia os cliques.
- Use **anúncios patrocinados** do Roblox com pouco Robux para testar.
- **Atualize sempre** (novo monstro, nova arma, evento). Isso traz jogadores de volta.
- Ajuste preços no `Config.lua` olhando os dados em *Analytics*.
- O Roblox fica com 30% de cada venda. Para virar dinheiro real, use o **DevEx** (tem idade mínima e saldo mínimo de Robux; confira as regras e a taxa atuais no site do Roblox).

## Personalizar

Tudo que é número fica no `Config.lua`: adicione armas, monstros (com cor, tamanho, vida, recompensa e distância do centro), mude o preço do renascimento ou o bônus de cada um.
